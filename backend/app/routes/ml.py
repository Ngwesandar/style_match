"""
Machine Learning API Router for Style Match.
Exposes endpoints for Decision Tree clothing occasion classification and model metadata.
"""

from fastapi import APIRouter, Depends, HTTPException, Path
from sqlalchemy.orm import Session
from typing import Optional

from ..database import get_db
from ..models import ClothingItem
from ..schemas import ClassifyOccasionRequest
from ..ml.service import MLOccasionService

router = APIRouter(prefix="/ml", tags=["Machine Learning Classification"])


@router.post("/classify")
def classify_clothing_occasion(data: ClassifyOccasionRequest, db: Session = Depends(get_db)):
    """
    Classifies the occasion for a clothing item using the trained Decision Tree Classifier.
    Predicts whether the item is suitable for 'Casual', 'Formal', or 'Party'.
    Returns the predicted label, prediction confidence (probability), and full class probability distribution.
    """
    try:
        # If item_id is provided and fields are empty, fetch from database
        category = data.category
        subcategory = data.subcategory or ""
        season = data.season or "All Season"
        color = data.color or "Mixed"

        if data.item_id and (not category or category == "Unknown"):
            item = db.query(ClothingItem).filter(ClothingItem.id == data.item_id).first()
            if item:
                category = item.category or category
                subcategory = item.subcategory or subcategory
                season = item.season or season
                color = item.color or color

        result = MLOccasionService.classify(
            category=category,
            subcategory=subcategory,
            season=season,
            color=color
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ML classification failed: {str(e)}")


@router.post("/classify-item/{item_id}")
def classify_existing_item(item_id: int = Path(...), update_db: bool = False, db: Session = Depends(get_db)):
    """
    Loads an existing clothing item from SQLite database, runs ML classification,
    and optionally updates the item's occasion in the database.
    """
    item = db.query(ClothingItem).filter(ClothingItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Clothing item not found in wardrobe")

    result = MLOccasionService.classify(
        category=item.category or "Tops",
        subcategory=item.subcategory or "",
        season=item.season or "All Season",
        color=item.color or "Mixed"
    )

    if update_db and result.get("success"):
        item.occasion = result["predicted_occasion"]
        db.commit()
        db.refresh(item)
        result["db_updated"] = True

    result["item_id"] = item_id
    return result


@router.get("/model-info")
def get_model_info():
    """
    Returns training and architecture metadata of the Decision Tree Classifier,
    including accuracy, precision, recall, confusion matrix, and feature definitions.
    """
    metrics = MLOccasionService.get_metrics()
    return {
        "success": True,
        "model_metadata": metrics
    }
