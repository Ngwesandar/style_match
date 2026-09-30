"""
Model Evaluation and Tree Inspection Utility.
Provides detailed classification metrics, confusion matrix display,
decision tree branch visualizer, and feature importance analysis.
"""

import os
import json
import numpy as np
import pandas as pd
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from sklearn.tree import export_text

from app.ml.dataset import load_or_create_dataset
from app.ml.classifier import OccasionDecisionTreeModel

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_SAVE_PATH = os.path.join(BASE_DIR, "saved_models", "decision_tree_occasion.joblib")
METRICS_SAVE_PATH = os.path.join(BASE_DIR, "saved_models", "model_metrics.json")


def inspect_model():
    """Prints in-depth evaluation and decision tree structure."""
    if not os.path.exists(MODEL_SAVE_PATH):
        print("Model file not found. Running training first...")
        from app.ml.train import train_and_evaluate
        train_and_evaluate()

    model = OccasionDecisionTreeModel.load(MODEL_SAVE_PATH)
    df = load_or_create_dataset()

    X = df[OccasionDecisionTreeModel.FEATURE_COLUMNS]
    y = df[OccasionDecisionTreeModel.TARGET_COLUMN]

    y_pred = model.predict(X)
    acc = accuracy_score(y, y_pred)
    class_names = sorted(list(np.unique(y)))

    print("\n" + "=" * 60)
    print("STYLE MATCH - DECISION TREE OCCASION CLASSIFIER EVALUATION")
    print("=" * 60)
    print(f"Algorithm: DecisionTreeClassifier (scikit-learn)")
    print(f"Overall Accuracy across full dataset ({len(df)} samples): {acc * 100:.2f}%\n")

    print("Classification Report:")
    print(classification_report(y, y_pred, target_names=class_names))

    cm = confusion_matrix(y, y_pred, labels=class_names)
    print("Confusion Matrix:")
    df_cm = pd.DataFrame(cm, index=[f"Actual {c}" for c in class_names], columns=[f"Pred {c}" for c in class_names])
    print(df_cm)

    # Feature Importance analysis
    tree_clf = model.pipeline.named_steps["classifier"]
    onehot_encoder = model.pipeline.named_steps["preprocessor"].named_transformers_["cat"]
    feature_names = onehot_encoder.get_feature_names_out(OccasionDecisionTreeModel.FEATURE_COLUMNS)
    importances = tree_clf.feature_importances_

    top_indices = np.argsort(importances)[::-1][:10]
    print("\nTop 10 Most Important Decision Features:")
    for rank, idx in enumerate(top_indices, 1):
        if importances[idx] > 0:
            print(f"  {rank}. {feature_names[idx]}: {importances[idx] * 100:.2f}%")

    print("\n" + "-" * 60)
    print("Decision Tree Text Representation (first 15 lines):")
    tree_rules = export_text(tree_clf, feature_names=list(feature_names), max_depth=3)
    print("\n".join(tree_rules.splitlines()[:20]))
    print("-" * 60)


if __name__ == "__main__":
    inspect_model()
