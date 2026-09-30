"""
Decision Tree Classifier Module for Clothing Occasion Prediction.
Uses scikit-learn's DecisionTreeClassifier with OneHotEncoder pipeline.
"""

import os
import re
import joblib
import pandas as pd
import numpy as np
from typing import Dict, Any, Optional, List
from sklearn.tree import DecisionTreeClassifier
from sklearn.preprocessing import OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline


class OccasionDecisionTreeModel:
    """
    Decision Tree Classifier for predicting clothing occasion (Casual, Formal, Party).
    Encapsulates feature preprocessing, tree training, prediction probabilities, and persistence.
    """

    FEATURE_COLUMNS = ["category", "subcategory", "season", "color"]
    TARGET_COLUMN = "occasion"
    TARGET_CLASSES = ["Casual", "Formal", "Party"]

    def __init__(self, max_depth: Optional[int] = None, min_samples_split: int = 2, min_samples_leaf: int = 1, criterion: str = "gini"):
        self.max_depth = max_depth
        self.min_samples_split = min_samples_split
        self.min_samples_leaf = min_samples_leaf
        self.criterion = criterion
        self.pipeline: Optional[Pipeline] = None
        self._build_pipeline()

    def _build_pipeline(self):
        """
        Constructs the scikit-learn Pipeline with ColumnTransformer and DecisionTreeClassifier.
        """
        preprocessor = ColumnTransformer(
            transformers=[
                ("cat", OneHotEncoder(handle_unknown="ignore", sparse_output=False), self.FEATURE_COLUMNS)
            ],
            remainder="drop"
        )

        dt_classifier = DecisionTreeClassifier(
            criterion=self.criterion,
            max_depth=self.max_depth,
            min_samples_split=self.min_samples_split,
            min_samples_leaf=self.min_samples_leaf,
            random_state=42
        )

        self.pipeline = Pipeline(steps=[
            ("preprocessor", preprocessor),
            ("classifier", dt_classifier)
        ])

    def fit(self, X: pd.DataFrame, y: pd.Series):
        """Trains the pipeline on features X and target y."""
        self.pipeline.fit(X[self.FEATURE_COLUMNS], y)
        return self

    def predict(self, X: pd.DataFrame) -> np.ndarray:
        return self.pipeline.predict(X[self.FEATURE_COLUMNS])

    def predict_proba(self, X: pd.DataFrame) -> np.ndarray:
        return self.pipeline.predict_proba(X[self.FEATURE_COLUMNS])

    def predict_single(
        self,
        category: str,
        subcategory: Optional[str] = "",
        season: Optional[str] = "All Season",
        color: Optional[str] = "Mixed"
    ) -> Dict[str, Any]:
        """
        Classifies a single garment and computes class probabilities.
        """
        cleaned_cat = self._normalize_category(category, subcategory)
        cleaned_subcat = self._normalize_subcategory(subcategory, cleaned_cat)
        cleaned_season = self._normalize_season(season)
        cleaned_color = (color or "Mixed").strip().title()

        df_input = pd.DataFrame([{
            "category": cleaned_cat,
            "subcategory": cleaned_subcat,
            "season": cleaned_season,
            "color": cleaned_color
        }])

        prediction = self.pipeline.predict(df_input)[0]
        probabilities = self.pipeline.predict_proba(df_input)[0]
        classes = self.pipeline.classes_

        prob_dict = {
            cls_name: round(float(prob), 4)
            for cls_name, prob in zip(classes, probabilities)
        }
        confidence = float(np.max(probabilities))

        explanation = self._generate_explanation(
            str(prediction),
            confidence,
            cleaned_cat,
            cleaned_subcat,
            cleaned_season,
            cleaned_color
        )

        return {
            "predicted_occasion": str(prediction),
            "confidence": round(confidence, 4),
            "confidence_percentage": f"{int(round(confidence * 100))}%",
            "probabilities": prob_dict,
            "algorithm": "Decision Tree (scikit-learn)",
            "explanation": explanation,
            "features_used": {
                "category": cleaned_cat,
                "subcategory": cleaned_subcat,
                "season": cleaned_season,
                "color": cleaned_color
            }
        }

    @staticmethod
    def _normalize_category(category: Optional[str], subcategory: Optional[str]) -> str:
        cat = (category or "").strip()
        subcat = (subcategory or "").lower()

        cat_map = {
            "t-shirt": "Tops", "tshirt": "Tops", "shirt": "Tops", "top": "Tops", "tops": "Tops",
            "jean": "Bottoms", "jeans": "Bottoms", "pants": "Bottoms", "trousers": "Bottoms", "bottom": "Bottoms", "bottoms": "Bottoms",
            "dress": "Dress", "dresses": "Dress", "gown": "Dress",
            "shoe": "Shoes", "shoes": "Shoes", "sneakers": "Shoes", "heels": "Shoes", "boots": "Shoes", "sandals": "Shoes",
            "jacket": "Outerwear", "coat": "Outerwear", "outerwear": "Outerwear", "blazer": "Outerwear",
            "bag": "Accessories", "accessory": "Accessories", "accessories": "Accessories"
        }
        if cat.lower() in cat_map:
            return cat_map[cat.lower()]

        if not cat or cat.lower() in ["clothing", "item", "other", "garment"]:
            for key, val in cat_map.items():
                if key in subcat:
                    return val
            return "Tops"
        return cat.title()

    @staticmethod
    def _normalize_subcategory(subcategory: Optional[str], category: str) -> str:
        sub = (subcategory or "").strip()
        sub_lower = sub.lower()

        # Keyword mapping to canonical subcategories
        if any(w in sub_lower for w in ["graphic", "tee", "t-shirt", "tshirt", "crew neck"]):
            return "Graphic Tee" if "graphic" in sub_lower else ("Crew Neck T-Shirt" if "crew" in sub_lower else "T-shirt")
        if any(w in sub_lower for w in ["polo"]):
            return "Polo Shirt"
        if any(w in sub_lower for w in ["tank"]):
            return "Tank Top"
        if any(w in sub_lower for w in ["hoodie"]):
            return "Oversized Hoodie"
        if any(w in sub_lower for w in ["sweatshirt"]):
            return "Crewneck Sweatshirt"
        if any(w in sub_lower for w in ["sequin"]):
            return "Sequin Top" if category == "Tops" else "Sequin Mini Skirt"
        if any(w in sub_lower for w in ["blouse", "silk"]):
            return "Silk Blouse"
        if any(w in sub_lower for w in ["button-down", "button down", "dress shirt", "collared shirt", "oxford", "poplin"]):
            return "Dress Shirt"
        if any(w in sub_lower for w in ["corset", "bustier"]):
            return "Corset Bustier Top"
        if any(w in sub_lower for w in ["halter"]):
            return "Satin Halter Top"
        if any(w in sub_lower for w in ["off-the-shoulder", "off the shoulder"]):
            return "Off-the-Shoulder Top"
        
        # Bottoms
        if any(w in sub_lower for w in ["jean", "denim"]):
            return "Straight Leg Jeans" if "straight" in sub_lower else "Jeans"
        if any(w in sub_lower for w in ["sweatpant", "jogger"]):
            return "Sweatpants" if "sweat" in sub_lower else "Joggers"
        if any(w in sub_lower for w in ["trouser", "slack", "dress pant"]):
            return "Wide-Leg Trousers" if "wide" in sub_lower else "Tailored Trousers"
        if any(w in sub_lower for w in ["short"]):
            return "Athletic Shorts" if "athletic" in sub_lower or "dolphin" in sub_lower else "Denim Shorts"
        if any(w in sub_lower for w in ["leather pant", "flare pant"]):
            return "High-Waisted Flare Pants" if "flare" in sub_lower else "Leather Pants"
        if any(w in sub_lower for w in ["pencil skirt"]):
            return "Pencil Skirt"

        # Dresses
        if any(w in sub_lower for w in ["gown", "ball gown"]):
            return "Formal Evening Gown"
        if any(w in sub_lower for w in ["cocktail"]):
            return "Cocktail Mini Dress"
        if any(w in sub_lower for w in ["cami", "ruffled"]):
            return "Ruffled Cami Mini Dress"
        if any(w in sub_lower for w in ["slip dress"]):
            return "Backless Slip Dress"
        if any(w in sub_lower for w in ["sundress", "summer dress"]):
            return "Summer Dress"
        if any(w in sub_lower for w in ["sheath", "business dress"]):
            return "Tailored Sheath Dress"
        
        # Outerwear
        if any(w in sub_lower for w in ["blazer", "suit jacket"]):
            return "Formal Suit Blazer"
        if any(w in sub_lower for w in ["leather jacket", "biker"]):
            return "Leather Jacket"
        if any(w in sub_lower for w in ["denim jacket"]):
            return "Denim Jacket"
        if any(w in sub_lower for w in ["trench", "overcoat"]):
            return "Wool Trench Coat"
        if any(w in sub_lower for w in ["puffer"]):
            return "Puffer Jacket"
        if any(w in sub_lower for w in ["bomber"]):
            return "Bomber Jacket"

        # Shoes
        if any(w in sub_lower for w in ["sneaker"]):
            return "Platform Sneakers" if "platform" in sub_lower or "chunky" in sub_lower else "Sneakers"
        if any(w in sub_lower for w in ["stiletto", "heel", "pump"]):
            return "Stiletto Heels" if "stiletto" in sub_lower or "heel" in sub_lower else "Classic Court Pumps"
        if any(w in sub_lower for w in ["oxford", "derby", "loafer"]):
            return "Oxford Dress Shoes"
        if any(w in sub_lower for w in ["sandal", "slide"]):
            return "Strappy Party Sandals" if "strappy" in sub_lower or "party" in sub_lower else "Flat Slide Sandals"
        if any(w in sub_lower for w in ["boot"]):
            return "Glitter Ankle Boots" if "glitter" in sub_lower else "Combat Boots"

        # Accessories
        if any(w in sub_lower for w in ["tie", "bowtie"]):
            return "Silk Necktie"
        if any(w in sub_lower for w in ["clutch"]):
            return "Glitter Clutch Bag"
        if any(w in sub_lower for w in ["briefcase"]):
            return "Leather Briefcase"
        if any(w in sub_lower for w in ["backpack"]):
            return "Backpack"
        if any(w in sub_lower for w in ["cap", "hat"]):
            return "Baseball Cap"

        return sub.title() if sub else "Garment"

    @staticmethod
    def _normalize_season(season: Optional[str]) -> str:
        s = (season or "All Season").strip().title()
        if s in ["Summer", "Winter", "Spring", "Autumn", "Fall"]:
            return "Autumn" if s == "Fall" else s
        return "All Season"

    @staticmethod
    def _generate_explanation(occasion: str, confidence: float, category: str, subcategory: str, season: str, color: str) -> str:
        conf_str = f"{int(round(confidence * 100))}%"
        if occasion == "Casual":
            return f"The Decision Tree classified this {color} {subcategory} as Casual ({conf_str} confidence) due to its relaxed silhouette and everyday {category.lower()} styling for {season}."
        elif occasion == "Formal":
            return f"The Decision Tree classified this {color} {subcategory} as Formal ({conf_str} confidence) matching structured, professional, and corporate attire guidelines."
        else:
            return f"The Decision Tree identified this {color} {subcategory} as Party wear ({conf_str} confidence) based on evening/event aesthetics, cut, and statement color palette."

    def save(self, filepath: str):
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        joblib.dump(self.pipeline, filepath)
        print(f"Model successfully saved to {filepath}")

    @classmethod
    def load(cls, filepath: str) -> "OccasionDecisionTreeModel":
        if not os.path.exists(filepath):
            raise FileNotFoundError(f"Trained model not found at {filepath}")
        pipeline = joblib.load(filepath)
        instance = cls()
        instance.pipeline = pipeline
        return instance
