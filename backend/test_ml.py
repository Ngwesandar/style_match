"""
Unit and Integration Test Suite for Style Match Machine Learning Classification.
Validates model training, serialization, inference, edge cases, and FastAPI endpoints.
"""

import os
import unittest
from fastapi.testclient import TestClient
from app.ml.classifier import OccasionDecisionTreeModel
from app.ml.service import MLOccasionService
from main import app


class TestMachineLearningOccasionClassifier(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        cls.model = MLOccasionService.get_model()

    def test_model_loaded(self):
        """Test that the Decision Tree model is loaded and initialized."""
        self.assertIsNotNone(self.model)
        self.assertIsNotNone(self.model.pipeline)

    def test_predict_casual_item(self):
        """Test Casual garment classification."""
        res = self.model.predict_single(
            category="Tops",
            subcategory="Graphic Tee",
            season="Summer",
            color="White"
        )
        self.assertEqual(res["predicted_occasion"], "Casual")
        self.assertGreaterEqual(res["confidence"], 0.70)
        self.assertIn("Casual", res["probabilities"])
        self.assertEqual(res["algorithm"], "Decision Tree (scikit-learn)")

    def test_predict_formal_item(self):
        """Test Formal garment classification."""
        res = self.model.predict_single(
            category="Tops",
            subcategory="Silk Blouse",
            season="Spring",
            color="Emerald"
        )
        self.assertEqual(res["predicted_occasion"], "Formal")
        self.assertGreaterEqual(res["confidence"], 0.70)
        self.assertIn("Formal", res["probabilities"])

    def test_predict_party_item(self):
        """Test Party garment classification."""
        res = self.model.predict_single(
            category="Dress",
            subcategory="Cocktail Mini Dress",
            season="Summer",
            color="Red"
        )
        self.assertEqual(res["predicted_occasion"], "Party")
        self.assertGreaterEqual(res["confidence"], 0.70)
        self.assertIn("Party", res["probabilities"])

    def test_edge_case_missing_subcategory(self):
        """Test that empty or generic subcategories gracefully fall back."""
        res = self.model.predict_single(
            category="Bottoms",
            subcategory="",
            season="Winter",
            color="Black"
        )
        self.assertIn(res["predicted_occasion"], ["Casual", "Formal", "Party"])
        self.assertGreater(res["confidence"], 0.0)

    def test_api_classify_endpoint(self):
        """Test FastAPI POST /ml/classify endpoint."""
        response = self.client.post("/ml/classify", json={
            "category": "Outerwear",
            "subcategory": "Formal Suit Blazer",
            "season": "Winter",
            "color": "Black"
        })
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data["success"])
        self.assertEqual(data["predicted_occasion"], "Formal")
        self.assertEqual(data["algorithm"], "Decision Tree (scikit-learn)")
        self.assertIn("probabilities", data)

    def test_api_classify_alias_endpoint(self):
        """Test top-level alias POST /classify-occasion endpoint."""
        response = self.client.post("/classify-occasion", json={
            "category": "Shoes",
            "subcategory": "Stiletto Heels",
            "season": "Spring",
            "color": "Gold"
        })
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data["success"])
        self.assertEqual(data["predicted_occasion"], "Party")

    def test_api_model_info_endpoint(self):
        """Test GET /ml/model-info endpoint returns genuine metrics."""
        response = self.client.get("/ml/model-info")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data["success"])
        metadata = data["model_metadata"]
        self.assertEqual(metadata["algorithm"], "Decision Tree Classifier")
        self.assertEqual(metadata["library"], "scikit-learn")
        self.assertIn("train_accuracy", metadata)
        self.assertIn("test_accuracy", metadata)
        self.assertIn("classification_report", metadata)
        self.assertIn("confusion_matrix", metadata)


if __name__ == "__main__":
    unittest.main()
