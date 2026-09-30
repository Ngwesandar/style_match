"""
Model Training and Evaluation Script for Occasion Decision Tree Classifier.
Trains the model, evaluates with accuracy, classification report, and confusion matrix,
and persists the trained model to disk for fast inference.
"""

import os
import json
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix

from app.ml.dataset import load_or_create_dataset
from app.ml.classifier import OccasionDecisionTreeModel

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_SAVE_PATH = os.path.join(BASE_DIR, "saved_models", "decision_tree_occasion.joblib")
METRICS_SAVE_PATH = os.path.join(BASE_DIR, "saved_models", "model_metrics.json")


def train_and_evaluate(test_size: float = 0.2, random_state: int = 42) -> dict:
    """
    Executes the end-to-end training pipeline:
    1. Loads or generates dataset
    2. Performs stratified train/test split (80/20)
    3. Trains Decision Tree Classifier Pipeline
    4. Evaluates performance metrics (Accuracy, Precision, Recall, F1, Confusion Matrix)
    5. Saves model artifact (.joblib) and metrics JSON
    """
    print("=" * 60)
    print("STYLE MATCH - MACHINE LEARNING OCCASION CLASSIFIER TRAINING")
    print("=" * 60)

    # 1. Load Dataset
    df = load_or_create_dataset(force_recreate=True)
    print(f"Total Dataset Size: {len(df)} samples")
    print(f"Features: {OccasionDecisionTreeModel.FEATURE_COLUMNS}")
    print(f"Target: '{OccasionDecisionTreeModel.TARGET_COLUMN}' (Classes: {OccasionDecisionTreeModel.TARGET_CLASSES})")
    
    X = df[OccasionDecisionTreeModel.FEATURE_COLUMNS]
    y = df[OccasionDecisionTreeModel.TARGET_COLUMN]

    # 2. Train-Test Split (Stratified to preserve class distribution)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y,
        test_size=test_size,
        random_state=random_state,
        stratify=y
    )
    print(f"\nTraining set size: {len(X_train)} samples ({int((1-test_size)*100)}%)")
    print(f"Testing set size:  {len(X_test)} samples ({int(test_size*100)}%)")

    # 3. Train Decision Tree Model
    print("\nTraining Decision Tree Classifier...")
    model = OccasionDecisionTreeModel(
        max_depth=None,
        min_samples_split=2,
        min_samples_leaf=1,
        criterion="gini"
    )
    model.fit(X_train, y_train)
    print("Model training complete.")

    # 4. Model Evaluation
    y_pred = model.predict(X_test)
    y_pred_train = model.predict(X_train)

    train_acc = accuracy_score(y_train, y_pred_train)
    test_acc = accuracy_score(y_test, y_pred)

    class_names = sorted(list(np.unique(y)))
    report_dict = classification_report(y_test, y_pred, target_names=class_names, output_dict=True)
    report_text = classification_report(y_test, y_pred, target_names=class_names)
    cm = confusion_matrix(y_test, y_pred, labels=class_names)

    print("\n" + "-" * 50)
    print("EVALUATION RESULTS")
    print("-" * 50)
    print(f"Training Accuracy: {train_acc * 100:.2f}%")
    print(f"Testing Accuracy:  {test_acc * 100:.2f}%")
    print("\nDetailed Classification Report:")
    print(report_text)
    print("Confusion Matrix (Rows = Actual, Columns = Predicted):")
    print(f"Classes: {class_names}")
    print(cm)

    # 5. Save Model Artifact and Metrics
    model.save(MODEL_SAVE_PATH)

    metrics = {
        "algorithm": "Decision Tree Classifier",
        "library": "scikit-learn",
        "criterion": "gini",
        "max_depth": "None (unconstrained pure leaves)",
        "min_samples_split": 2,
        "min_samples_leaf": 1,
        "features": OccasionDecisionTreeModel.FEATURE_COLUMNS,
        "target_classes": class_names,
        "dataset_size": len(df),
        "train_samples": len(X_train),
        "test_samples": len(X_test),
        "train_accuracy": round(float(train_acc), 4),
        "test_accuracy": round(float(test_acc), 4),
        "classification_report": report_dict,
        "confusion_matrix": cm.tolist()
    }

    os.makedirs(os.path.dirname(METRICS_SAVE_PATH), exist_ok=True)
    with open(METRICS_SAVE_PATH, "w") as f:
        json.dump(metrics, f, indent=2)
    print(f"Evaluation metrics saved to {METRICS_SAVE_PATH}")

    # 6. Sample Live Inference Verification
    print("\n" + "-" * 50)
    print("SAMPLE INFERENCE VERIFICATIONS:")
    print("-" * 50)
    sample_tests = [
        {"category": "Tops", "subcategory": "Graphic Tee", "season": "Summer", "color": "White"},
        {"category": "Tops", "subcategory": "Dress Shirt", "season": "Spring", "color": "Light Blue"},
        {"category": "Tops", "subcategory": "Silk Blouse", "season": "Autumn", "color": "Emerald"},
        {"category": "Dress", "subcategory": "Cocktail Mini Dress", "season": "Summer", "color": "Red"},
        {"category": "Outerwear", "subcategory": "Formal Suit Blazer", "season": "Winter", "color": "Black"},
        {"category": "Bottoms", "subcategory": "Straight Leg Jeans", "season": "All Season", "color": "Blue"},
        {"category": "Shoes", "subcategory": "Sneakers", "season": "Summer", "color": "White"},
        {"category": "Shoes", "subcategory": "Stiletto Heels", "season": "Spring", "color": "Gold"},
        {"category": "Accessories", "subcategory": "Silk Necktie", "season": "All Season", "color": "Navy"},
        {"category": "Accessories", "subcategory": "Glitter Clutch Bag", "season": "All Season", "color": "Gold"},
    ]
    for sample in sample_tests:
        res = model.predict_single(
            category=sample["category"],
            subcategory=sample["subcategory"],
            season=sample["season"],
            color=sample["color"]
        )
        print(f"Input: {sample['subcategory']} ({sample['category']}, {sample['color']}, {sample['season']}) -> Predicted: {res['predicted_occasion']} (Confidence: {res['confidence_percentage']})")

    print("\nTraining and validation successfully finished!")
    return metrics


if __name__ == "__main__":
    train_and_evaluate()
