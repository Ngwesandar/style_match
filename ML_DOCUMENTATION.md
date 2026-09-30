# Style Match - Machine Learning Classification Documentation

## 1. Executive Summary

This document explains the Machine Learning (ML) classification engine integrated into the **Style Match** application for the final-year B.Tech project presentation.

The system uses a **Decision Tree Classifier** from Python's **`scikit-learn`** library to classify fashion garments into three occasion categories:
- **Casual**
- **Formal**
- **Party**

---

## 2. Machine Learning Algorithm: Decision Tree Classifier

### What is a Decision Tree?
A **Decision Tree** is a supervised machine learning algorithm used for classification and regression tasks. It models decisions in an intuitive, hierarchical tree structure consisting of:
1. **Root Node**: The top-level feature test that best separates the dataset (highest Information Gain / lowest Gini Impurity).
2. **Internal Decision Nodes**: Attribute condition checks (e.g., `subcategory == 'Silk Blouse'`, `category == 'Dress'`, `color == 'Gold'`).
3. **Leaf Nodes**: Terminal nodes representing the predicted class label (`Casual`, `Formal`, or `Party`) and associated class probability distributions.

### Splitting Criterion: Gini Impurity
During training, the tree selects splits that minimize **Gini Impurity**:
$$I_G(p) = 1 - \sum_{i=1}^{C} p_i^2$$
Where $p_i$ is the probability of class $i$ at that node. A pure leaf node has an impurity of 0.0.

---

## 3. Features Used in the Model

The classifier extracts and evaluates four key attributes available in the Style Match wardrobe database:

| Feature Name | Type | Description / Examples |
| :--- | :--- | :--- |
| **`category`** | Categorical (String) | `Tops`, `Bottoms`, `Dress`, `Outerwear`, `Shoes`, `Accessories` |
| **`subcategory`** | Categorical (String) | `T-shirt`, `Jeans`, `Silk Blouse`, `Formal Suit Blazer`, `Cocktail Mini Dress`, `Stiletto Heels`, `Oxford Dress Shoes`, `Hoodie`, `Sneakers` |
| **`season`** | Categorical (String) | `Summer`, `Winter`, `Spring`, `Autumn`, `All Season` |
| **`color`** | Categorical (String) | `Black`, `White`, `Navy`, `Blue`, `Red`, `Gold`, `Silver`, `Emerald`, `Beige`, etc. |

### Feature Preprocessing
Categorical features are encoded using scikit-learn's `OneHotEncoder(handle_unknown='ignore')` inside a `ColumnTransformer` pipeline. This enables handling unseen words, abbreviations, and mixed casing gracefully.

---

## 4. Dataset Source, Preparation & Size

- **Source**: Constructed from structured fashion ontology taxonomies, augmented with existing labeled items from the SQLite database (`users.db`).
- **Total Dataset Size**: **1,394 samples**
- **Classes**:
  - `Casual`: 642 samples (~46%)
  - `Party`: 392 samples (~28%)
  - `Formal`: 360 samples (~26%)
- **Data Partitioning**: Stratified **80% Training (1,115 samples)** and **20% Testing (279 samples)** using `train_test_split(stratify=y, random_state=42)`.

---

## 5. Model Evaluation and Performance Results

| Metric | Training Set (80%) | Testing Set (20% Unseen) |
| :--- | :--- | :--- |
| **Overall Accuracy** | **100.00%** | **94.27%** |
| **Macro Avg Precision** | 1.00 | 0.94 |
| **Macro Avg Recall** | 1.00 | 0.94 |
| **Macro Avg F1-Score** | 1.00 | 0.94 |

### Classification Report (Test Set):
```text
              precision    recall  f1-score   support

      Casual       0.95      0.96      0.95       129
      Formal       0.91      0.99      0.95        72
       Party       0.97      0.87      0.92        78

    accuracy                           0.94       279
   macro avg       0.94      0.94      0.94       279
weighted avg       0.94      0.94      0.94       279
```

### Confusion Matrix:
```text
               Pred Casual  Pred Formal  Pred Party
Actual Casual          124            4           1
Actual Formal            0           71           1
Actual Party             7            3          68
```

---

## 6. Project Architecture & Workflow

```
[Flutter App] 
      │ (User opens Wardrobe Item Details)
      ▼
[API Request: POST /ml/classify]
      │ (category, subcategory, season, color)
      ▼
[FastAPI Backend: app/routes/ml.py]
      │
      ▼
[ML Service: app/ml/service.py]
      │ (Loads pre-trained model decision_tree_occasion.joblib)
      ▼
[Scikit-Learn DecisionTree Pipeline]
      │ (Feature Encoding ➔ Tree Traversal ➔ predict_proba)
      ▼
[Response Payload]
  - predicted_occasion: "Formal"
  - confidence: 1.0 (100%)
  - probabilities: {"Casual": 0.0, "Formal": 1.0, "Party": 0.0}
  - algorithm: "Decision Tree (scikit-learn)"
      │
      ▼
[Flutter UI: MLClassificationCard]
  - Visual Badge + Confidence Bar + Probability Distribution + Explainability
```

---

## 7. How to Run the ML Code and Train the Model

### Step 1: Activate Virtual Environment
```bash
cd backend
source venv/bin/activate
```

### Step 2: Run Training & Evaluation
```bash
python -m app.ml.train
```
*(Trains the Decision Tree, logs accuracy & confusion matrix, and saves `decision_tree_occasion.joblib` and `model_metrics.json`)*

### Step 3: Run Model Inspection & Decision Tree Visualization
```bash
python -m app.ml.evaluate
```
*(Prints feature importances, confusion matrix, and textual representation of the decision tree)*

### Step 4: Run Automated Tests
```bash
python test_ml.py
```

### Step 5: Start the FastAPI Backend
```bash
uvicorn main:app --reload --port 8000
```

---

## 8. How to Demonstrate to Your Professor

1. **Explain the Theory**:
   - Point to `backend/app/ml/classifier.py` and explain how `DecisionTreeClassifier` with `OneHotEncoder` creates an interpretable decision tree that calculates entropy/Gini impurity.
2. **Show Training Code & Metrics**:
   - Run `python -m app.ml.train` in terminal.
   - Show the professor the 80/20 train/test split, 94.27% test accuracy, precision/recall table, and the confusion matrix.
3. **Show Decision Tree Structure**:
   - Run `python -m app.ml.evaluate` to show the top 10 feature importances and decision tree branch rules.
4. **Demonstrate API & Test Suite**:
   - Run `python test_ml.py` to show that all 8 automated unit tests pass in real time.
   - Open browser to `http://127.0.0.1:8000/docs` and test `POST /ml/classify` and `GET /ml/model-info` interactively in Swagger UI.
5. **Demonstrate Flutter Integration**:
   - Open the Style Match Flutter app, navigate to Wardrobe, and tap on any clothing item.
   - Show the **"Machine Learning Classification"** card displaying the Decision Tree prediction, confidence bar, and class probability distribution.
