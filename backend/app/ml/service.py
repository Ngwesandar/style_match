"""
ML Occasion Classification Service for Style Match.
Singleton service that manages loading the trained Decision Tree model
and performing thread-safe occasion predictions for clothing items.
"""

import os
import json
import logging
from typing import Dict, Any, Optional
from app.ml.classifier import OccasionDecisionTreeModel

logger = logging.getLogger("style_match.ml_service")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_FILE = os.path.join(BASE_DIR, "saved_models", "decision_tree_occasion.joblib")
METRICS_FILE = os.path.join(BASE_DIR, "saved_models", "model_metrics.json")


class MLOccasionService:
    _instance: Optional["MLOccasionService"] = None
    _model: Optional[OccasionDecisionTreeModel] = None
    _metrics: Optional[Dict[str, Any]] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(MLOccasionService, cls).__new__(cls)
            cls._instance._init_service()
        return cls._instance

    def _init_service(self):
        """Loads or trains the Decision Tree model pipeline and cached metrics."""
        try:
            if not os.path.exists(MODEL_FILE):
                logger.info("Saved ML model not found. Training model now...")
                from app.ml.train import train_and_evaluate
                self._metrics = train_and_evaluate()

            self._model = OccasionDecisionTreeModel.load(MODEL_FILE)
            logger.info("Decision Tree Occasion Model loaded successfully.")

            if os.path.exists(METRICS_FILE):
                with open(METRICS_FILE, "r") as f:
                    self._metrics = json.load(f)
        except Exception as e:
            logger.error(f"Failed to initialize ML Occasion Service: {e}", exc_info=True)
            self._model = None

    @classmethod
    def get_model(cls) -> OccasionDecisionTreeModel:
        service = cls()
        if service._model is None:
            service._init_service()
        return service._model

    @classmethod
    def get_metrics(cls) -> Dict[str, Any]:
        service = cls()
        if service._metrics is None and os.path.exists(METRICS_FILE):
            try:
                with open(METRICS_FILE, "r") as f:
                    service._metrics = json.load(f)
            except Exception:
                pass
        return service._metrics or {
            "algorithm": "Decision Tree Classifier",
            "library": "scikit-learn",
            "status": "active"
        }

    @classmethod
    def classify(
        cls,
        category: str,
        subcategory: Optional[str] = "",
        season: Optional[str] = "All Season",
        color: Optional[str] = "Mixed"
    ) -> Dict[str, Any]:
        """
        Classifies clothing item occasion (Casual, Formal, Party) using the Decision Tree model.
        Returns predicted occasion, confidence probability, class probabilities, and explanation.
        """
        model = cls.get_model()
        if model is None:
            # Safe rule-based fallback if ML model binary is unavailable
            return cls._fallback_classification(category, subcategory, season, color)

        try:
            result = model.predict_single(
                category=category,
                subcategory=subcategory,
                season=season,
                color=color
            )
            return {
                "success": True,
                **result
            }
        except Exception as e:
            logger.error(f"Inference error in Decision Tree classifier: {e}", exc_info=True)
            fallback = cls._fallback_classification(category, subcategory, season, color)
            fallback["warning"] = f"Inference fallback used: {str(e)}"
            return fallback

    @classmethod
    def _fallback_classification(cls, category: str, subcategory: str, season: str, color: str) -> Dict[str, Any]:
        sub = (subcategory or "").lower()
        cat = (category or "").lower()

        if any(w in sub for w in ["formal", "tuxedo", "suit", "blazer", "dress shirt", "pencil skirt", "tie", "oxford", "briefcase", "gown", "sheath"]):
            occ = "Formal"
            conf = 0.85
        elif any(w in sub for w in ["sequin", "metallic", "glitter", "cocktail", "party", "stiletto", "corset", "satin", "clutch", "leather jacket"]):
            occ = "Party"
            conf = 0.88
        else:
            occ = "Casual"
            conf = 0.90

        return {
            "success": True,
            "predicted_occasion": occ,
            "confidence": conf,
            "confidence_percentage": f"{int(conf * 100)}%",
            "probabilities": {
                "Casual": 0.90 if occ == "Casual" else 0.05,
                "Formal": 0.85 if occ == "Formal" else 0.08,
                "Party": 0.88 if occ == "Party" else 0.07,
            },
            "algorithm": "Decision Tree (Rule Fallback)",
            "explanation": f"Classified as {occ} based on garment category ({category}) and subcategory characteristics.",
            "features_used": {
                "category": category,
                "subcategory": subcategory,
                "season": season,
                "color": color
            }
        }
