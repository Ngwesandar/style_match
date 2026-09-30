"""
Dataset Preparation for Clothing Occasion Classification.
Generates and manages the clothing occasion dataset for training the Decision Tree Classifier.
Combines comprehensive fashion taxonomy with existing SQLite database items.
"""

import os
import sqlite3
import pandas as pd
import numpy as np

DATA_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(DATA_DIR, "data", "clothing_dataset.csv")
DB_PATH = os.path.join(os.path.dirname(DATA_DIR), "..", "users.db")

# Comprehensive fashion taxonomy covering everyday, work, formal, and party wear
CLOTHING_TAXONOMY = [
    # --- TOPS (Casual) ---
    {"category": "Tops", "subcategory": "T-shirt", "occasion": "Casual", "seasons": ["Summer", "Spring", "All Season"], "colors": ["White", "Black", "Grey", "Blue", "Red", "Green", "Yellow", "Pink", "Brown", "Navy"]},
    {"category": "Tops", "subcategory": "Crew Neck T-Shirt", "occasion": "Casual", "seasons": ["Summer", "Spring", "All Season"], "colors": ["White", "Black", "Grey", "Navy", "Beige"]},
    {"category": "Tops", "subcategory": "Graphic Tee", "occasion": "Casual", "seasons": ["Summer", "Spring", "All Season"], "colors": ["Black", "White", "Grey", "Navy", "Yellow", "Olive"]},
    {"category": "Tops", "subcategory": "Polo Shirt", "occasion": "Casual", "seasons": ["Summer", "Spring", "All Season"], "colors": ["Navy", "White", "Black", "Burgundy", "Green", "Blue"]},
    {"category": "Tops", "subcategory": "Tank Top", "occasion": "Casual", "seasons": ["Summer", "Spring"], "colors": ["White", "Black", "Grey", "Pink", "Blue", "Beige"]},
    {"category": "Tops", "subcategory": "Flannel Shirt", "occasion": "Casual", "seasons": ["Winter", "Autumn", "Spring"], "colors": ["Red", "Green", "Blue", "Grey", "Brown"]},
    {"category": "Tops", "subcategory": "Oversized Hoodie", "occasion": "Casual", "seasons": ["Winter", "Autumn", "Spring", "All Season"], "colors": ["Black", "Grey", "Beige", "Navy", "Green", "Pink"]},
    {"category": "Tops", "subcategory": "Crewneck Sweatshirt", "occasion": "Casual", "seasons": ["Winter", "Autumn", "Spring"], "colors": ["Grey", "Navy", "Black", "Maroon", "White"]},
    {"category": "Tops", "subcategory": "Denim Shirt", "occasion": "Casual", "seasons": ["Autumn", "Spring", "All Season"], "colors": ["Blue", "Light Blue", "Black", "Grey"]},
    {"category": "Tops", "subcategory": "Henley Shirt", "occasion": "Casual", "seasons": ["Autumn", "Spring", "Winter"], "colors": ["Grey", "Black", "White", "Navy", "Olive"]},
    {"category": "Tops", "subcategory": "Casual Crop Top", "occasion": "Casual", "seasons": ["Summer", "Spring"], "colors": ["White", "Black", "Pink", "Yellow", "Lilac"]},
    {"category": "Tops", "subcategory": "Striped Casual Shirt", "occasion": "Casual", "seasons": ["All Season", "Summer", "Spring"], "colors": ["Blue", "Navy", "White", "Red"]},

    # --- TOPS (Formal) ---
    {"category": "Tops", "subcategory": "Dress Shirt", "occasion": "Formal", "seasons": ["All Season", "Winter", "Spring"], "colors": ["White", "Light Blue", "Black", "Pink", "Grey", "Navy"]},
    {"category": "Tops", "subcategory": "Button-Down Shirt", "occasion": "Formal", "seasons": ["All Season", "Spring", "Autumn"], "colors": ["White", "Light Blue", "Grey", "Navy", "Stripe"]},
    {"category": "Tops", "subcategory": "Silk Blouse", "occasion": "Formal", "seasons": ["All Season", "Spring", "Autumn"], "colors": ["White", "Champagne", "Black", "Navy", "Burgundy", "Emerald"]},
    {"category": "Tops", "subcategory": "Formal Tuxedo Shirt", "occasion": "Formal", "seasons": ["All Season", "Winter"], "colors": ["White", "Black", "Ivory"]},
    {"category": "Tops", "subcategory": "Tailored Collared Blouse", "occasion": "Formal", "seasons": ["All Season", "Spring", "Autumn"], "colors": ["White", "Navy", "Black", "Beige", "Soft Blue"]},
    {"category": "Tops", "subcategory": "Tie-Neck Chiffon Blouse", "occasion": "Formal", "seasons": ["All Season", "Spring"], "colors": ["White", "Dusty Rose", "Navy", "Black", "Wine"]},
    {"category": "Tops", "subcategory": "Formal Poplin Shirt", "occasion": "Formal", "seasons": ["All Season", "Winter", "Spring"], "colors": ["White", "Sky Blue", "French Blue", "Lavender"]},

    # --- TOPS (Party) ---
    {"category": "Tops", "subcategory": "Sequin Top", "occasion": "Party", "seasons": ["All Season", "Winter", "Autumn"], "colors": ["Silver", "Gold", "Black", "Rose Gold", "Emerald", "Bronze"]},
    {"category": "Tops", "subcategory": "Metallic Crop Top", "occasion": "Party", "seasons": ["Summer", "All Season"], "colors": ["Silver", "Gold", "Iridescent", "Black", "Purple"]},
    {"category": "Tops", "subcategory": "Satin Halter Top", "occasion": "Party", "seasons": ["Summer", "All Season", "Spring"], "colors": ["Red", "Black", "Emerald", "Champagne", "Royal Blue", "Magenta"]},
    {"category": "Tops", "subcategory": "Velvet Bodysuit", "occasion": "Party", "seasons": ["Winter", "Autumn"], "colors": ["Burgundy", "Black", "Midnight Blue", "Forest Green", "Plum"]},
    {"category": "Tops", "subcategory": "Corset Bustier Top", "occasion": "Party", "seasons": ["Summer", "All Season", "Spring"], "colors": ["Black", "Red", "White", "Blush Pink", "Purple"]},
    {"category": "Tops", "subcategory": "Off-the-Shoulder Top", "occasion": "Party", "seasons": ["Summer", "Spring", "All Season"], "colors": ["Black", "Red", "Gold", "Royal Blue", "Burgundy"]},
    {"category": "Tops", "subcategory": "Glitter Mesh Top", "occasion": "Party", "seasons": ["All Season", "Summer"], "colors": ["Black", "Silver", "Multicolor", "Gold"]},

    # --- BOTTOMS (Casual) ---
    {"category": "Bottoms", "subcategory": "Jeans", "occasion": "Casual", "seasons": ["All Season", "Winter", "Spring", "Autumn"], "colors": ["Blue", "Light Blue", "Black", "Grey", "White"]},
    {"category": "Bottoms", "subcategory": "Straight Leg Jeans", "occasion": "Casual", "seasons": ["All Season", "Autumn", "Spring"], "colors": ["Blue", "Black", "Light Blue", "Dark Wash"]},
    {"category": "Bottoms", "subcategory": "Cargo Pants", "occasion": "Casual", "seasons": ["All Season", "Autumn", "Spring"], "colors": ["Olive", "Khaki", "Black", "Beige", "Grey"]},
    {"category": "Bottoms", "subcategory": "Sweatpants", "occasion": "Casual", "seasons": ["Winter", "Autumn", "Spring"], "colors": ["Grey", "Black", "Navy", "Beige", "Charcoal"]},
    {"category": "Bottoms", "subcategory": "Denim Shorts", "occasion": "Casual", "seasons": ["Summer", "Spring"], "colors": ["Blue", "Light Blue", "Black", "White"]},
    {"category": "Bottoms", "subcategory": "Joggers", "occasion": "Casual", "seasons": ["All Season", "Autumn", "Winter"], "colors": ["Black", "Grey", "Olive", "Navy"]},
    {"category": "Bottoms", "subcategory": "Casual Chinos", "occasion": "Casual", "seasons": ["Summer", "Spring", "Autumn", "All Season"], "colors": ["Beige", "Navy", "Khaki", "Olive", "Grey"]},
    {"category": "Bottoms", "subcategory": "Athletic Shorts", "occasion": "Casual", "seasons": ["Summer", "Spring"], "colors": ["Black", "Grey", "Navy", "Red", "Blue"]},

    # --- BOTTOMS (Formal) ---
    {"category": "Bottoms", "subcategory": "Tailored Trousers", "occasion": "Formal", "seasons": ["All Season", "Winter", "Autumn"], "colors": ["Black", "Navy", "Charcoal", "Grey", "Pinstripe"]},
    {"category": "Bottoms", "subcategory": "Wide-Leg Trousers", "occasion": "Formal", "seasons": ["All Season", "Spring", "Autumn"], "colors": ["Black", "Ivory", "Navy", "Camel", "Grey"]},
    {"category": "Bottoms", "subcategory": "Suit Slacks", "occasion": "Formal", "seasons": ["All Season", "Winter", "Spring"], "colors": ["Black", "Dark Grey", "Navy", "Brown"]},
    {"category": "Bottoms", "subcategory": "Pencil Skirt", "occasion": "Formal", "seasons": ["All Season", "Spring", "Autumn"], "colors": ["Black", "Navy", "Grey", "Beige", "Burgundy"]},
    {"category": "Bottoms", "subcategory": "Pleated Dress Pants", "occasion": "Formal", "seasons": ["All Season", "Spring", "Autumn"], "colors": ["Charcoal", "Black", "Navy", "Tan"]},

    # --- BOTTOMS (Party) ---
    {"category": "Bottoms", "subcategory": "Leather Pants", "occasion": "Party", "seasons": ["Winter", "Autumn", "All Season"], "colors": ["Black", "Burgundy", "Brown", "Silver"]},
    {"category": "Bottoms", "subcategory": "High-Waisted Flare Pants", "occasion": "Party", "seasons": ["All Season", "Autumn", "Spring"], "colors": ["Black", "Red", "Emerald", "Gold"]},
    {"category": "Bottoms", "subcategory": "Sequin Mini Skirt", "occasion": "Party", "seasons": ["All Season", "Winter", "Summer"], "colors": ["Silver", "Gold", "Black", "Emerald", "Rose Gold"]},
    {"category": "Bottoms", "subcategory": "Metallic Skirt", "occasion": "Party", "seasons": ["Summer", "All Season"], "colors": ["Silver", "Gold", "Bronze", "Purple"]},
    {"category": "Bottoms", "subcategory": "Faux Leather Mini Skirt", "occasion": "Party", "seasons": ["Autumn", "Winter", "Spring"], "colors": ["Black", "Red", "Brown", "Wine"]},
    {"category": "Bottoms", "subcategory": "Satin Midi Skirt with Slit", "occasion": "Party", "seasons": ["Summer", "Spring", "Autumn"], "colors": ["Champagne", "Emerald", "Black", "Ruby Red", "Navy"]},
    {"category": "Bottoms", "subcategory": "Sparkly Flared Trousers", "occasion": "Party", "seasons": ["Winter", "All Season"], "colors": ["Black", "Silver", "Gold", "Glitter Navy"]},

    # --- DRESS (Casual) ---
    {"category": "Dress", "subcategory": "Sundress", "occasion": "Casual", "seasons": ["Summer", "Spring"], "colors": ["Yellow", "Floral", "White", "Blue", "Pink", "Green"]},
    {"category": "Dress", "subcategory": "Summer Dress", "occasion": "Casual", "seasons": ["Summer", "Spring"], "colors": ["Yellow", "Floral", "White", "Blue", "Red", "Pink"]},
    {"category": "Dress", "subcategory": "T-Shirt Dress", "occasion": "Casual", "seasons": ["Summer", "Spring"], "colors": ["Black", "Grey", "Stripe", "Olive", "White"]},
    {"category": "Dress", "subcategory": "Shirt Dress", "occasion": "Casual", "seasons": ["Summer", "Spring", "Autumn"], "colors": ["White", "Blue Stripe", "Khaki", "Denim", "Beige"]},
    {"category": "Dress", "subcategory": "Casual Maxi Dress", "occasion": "Casual", "seasons": ["Summer", "Spring"], "colors": ["Boho Print", "Teal", "Coral", "Navy", "Mustard"]},
    {"category": "Dress", "subcategory": "Sweater Dress", "occasion": "Casual", "seasons": ["Winter", "Autumn"], "colors": ["Beige", "Grey", "Burgundy", "Black", "Cream"]},

    # --- DRESS (Formal) ---
    {"category": "Dress", "subcategory": "Formal Evening Gown", "occasion": "Formal", "seasons": ["All Season", "Winter", "Autumn"], "colors": ["Black", "Navy", "Emerald", "Burgundy", "Royal Blue", "Champagne"]},
    {"category": "Dress", "subcategory": "Tailored Sheath Dress", "occasion": "Formal", "seasons": ["All Season", "Spring", "Autumn"], "colors": ["Black", "Navy", "Grey", "Burgundy", "Cobalt"]},
    {"category": "Dress", "subcategory": "A-Line Business Dress", "occasion": "Formal", "seasons": ["All Season", "Spring", "Autumn"], "colors": ["Navy", "Black", "Plum", "Teal", "Charcoal"]},
    {"category": "Dress", "subcategory": "Floor Length Ball Gown", "occasion": "Formal", "seasons": ["All Season", "Winter"], "colors": ["Midnight Blue", "Crimson", "Black", "Gold", "Silver"]},

    # --- DRESS (Party) ---
    {"category": "Dress", "subcategory": "Cocktail Mini Dress", "occasion": "Party", "seasons": ["All Season", "Summer", "Spring"], "colors": ["Red", "Black", "Emerald", "Gold", "Hot Pink", "Royal Blue"]},
    {"category": "Dress", "subcategory": "Ruffled Cami Mini Dress", "occasion": "Party", "seasons": ["Summer", "Spring", "All Season"], "colors": ["Burgundy", "Red", "Pink", "Black"]},
    {"category": "Dress", "subcategory": "Sequin Bodycon Dress", "occasion": "Party", "seasons": ["All Season", "Winter"], "colors": ["Silver", "Gold", "Rose Gold", "Black", "Iridescent"]},
    {"category": "Dress", "subcategory": "Little Black Dress", "occasion": "Party", "seasons": ["All Season", "Autumn", "Spring"], "colors": ["Black"]},
    {"category": "Dress", "subcategory": "Backless Slip Dress", "occasion": "Party", "seasons": ["Summer", "Spring", "All Season"], "colors": ["Satin Red", "Champagne", "Black", "Olive", "Copper"]},
    {"category": "Dress", "subcategory": "Velvet Wrap Party Dress", "occasion": "Party", "seasons": ["Winter", "Autumn"], "colors": ["Burgundy", "Emerald", "Navy", "Plum", "Black"]},

    # --- OUTERWEAR (Casual) ---
    {"category": "Outerwear", "subcategory": "Denim Jacket", "occasion": "Casual", "seasons": ["Spring", "Autumn", "All Season"], "colors": ["Blue", "Light Blue", "Black", "White"]},
    {"category": "Outerwear", "subcategory": "Bomber Jacket", "occasion": "Casual", "seasons": ["Spring", "Autumn", "Winter"], "colors": ["Olive", "Black", "Navy", "Burgundy", "Khaki"]},
    {"category": "Outerwear", "subcategory": "Puffer Jacket", "occasion": "Casual", "seasons": ["Winter"], "colors": ["Black", "Navy", "Silver", "Red", "Yellow", "Olive"]},
    {"category": "Outerwear", "subcategory": "Fleece Zip Jacket", "occasion": "Casual", "seasons": ["Winter", "Autumn"], "colors": ["Beige", "Black", "Grey", "Green"]},
    {"category": "Outerwear", "subcategory": "Utility Field Jacket", "occasion": "Casual", "seasons": ["Autumn", "Spring"], "colors": ["Olive", "Khaki", "Camo", "Brown"]},
    {"category": "Outerwear", "subcategory": "Cardigan", "occasion": "Casual", "seasons": ["Autumn", "Winter", "Spring"], "colors": ["Beige", "Grey", "Cream", "Brown", "Mustard"]},

    # --- OUTERWEAR (Formal) ---
    {"category": "Outerwear", "subcategory": "Formal Suit Blazer", "occasion": "Formal", "seasons": ["All Season", "Autumn", "Spring", "Winter"], "colors": ["Black", "Navy", "Charcoal", "Grey", "Pinstripe"]},
    {"category": "Outerwear", "subcategory": "Wool Trench Coat", "occasion": "Formal", "seasons": ["Winter", "Autumn"], "colors": ["Camel", "Black", "Navy", "Grey", "Beige"]},
    {"category": "Outerwear", "subcategory": "Tailored Double-Breasted Blazer", "occasion": "Formal", "seasons": ["All Season", "Winter", "Autumn"], "colors": ["Navy", "Black", "Dark Green", "Houndstooth"]},
    {"category": "Outerwear", "subcategory": "Overcoat", "occasion": "Formal", "seasons": ["Winter"], "colors": ["Black", "Charcoal", "Camel", "Navy"]},
    {"category": "Outerwear", "subcategory": "Tuxedo Jacket", "occasion": "Formal", "seasons": ["All Season", "Winter"], "colors": ["Black", "Midnight Blue", "White"]},

    # --- OUTERWEAR (Party) ---
    {"category": "Outerwear", "subcategory": "Leather Biker Jacket", "occasion": "Party", "seasons": ["Autumn", "Spring", "All Season"], "colors": ["Black", "Burgundy", "Metallic Silver", "Cognac"]},
    {"category": "Outerwear", "subcategory": "Leather Jacket", "occasion": "Party", "seasons": ["Autumn", "Winter", "All Season"], "colors": ["Black", "Brown", "Burgundy"]},
    {"category": "Outerwear", "subcategory": "Faux Fur Coat", "occasion": "Party", "seasons": ["Winter"], "colors": ["Leopard", "White", "Black", "Pink", "Emerald"]},
    {"category": "Outerwear", "subcategory": "Sequin Party Blazer", "occasion": "Party", "seasons": ["Winter", "All Season"], "colors": ["Gold", "Silver", "Black Glitter", "Rose Gold"]},
    {"category": "Outerwear", "subcategory": "Velvet Blazer", "occasion": "Party", "seasons": ["Winter", "Autumn"], "colors": ["Burgundy", "Midnight Blue", "Emerald", "Black"]},

    # --- SHOES (Casual) ---
    {"category": "Shoes", "subcategory": "Sneakers", "occasion": "Casual", "seasons": ["All Season", "Summer", "Spring"], "colors": ["White", "Black", "Grey", "Blue", "Red", "Green"]},
    {"category": "Shoes", "subcategory": "Platform Sneakers", "occasion": "Casual", "seasons": ["All Season", "Spring", "Autumn"], "colors": ["White", "Black", "Beige"]},
    {"category": "Shoes", "subcategory": "Chunky Platform Sneakers", "occasion": "Casual", "seasons": ["All Season", "Autumn", "Spring"], "colors": ["Black", "White", "Grey"]},
    {"category": "Shoes", "subcategory": "Flat Slide Sandals", "occasion": "Casual", "seasons": ["Summer", "Spring"], "colors": ["Brown", "Tan", "Black", "White", "Gold"]},
    {"category": "Shoes", "subcategory": "Canvas Shoes", "occasion": "Casual", "seasons": ["Summer", "Spring"], "colors": ["White", "Black", "Navy", "Checkered"]},
    {"category": "Shoes", "subcategory": "Running Shoes", "occasion": "Casual", "seasons": ["All Season", "Summer"], "colors": ["Black", "Grey", "Blue", "Neon"]},

    # --- SHOES (Formal) ---
    {"category": "Shoes", "subcategory": "Oxford Dress Shoes", "occasion": "Formal", "seasons": ["All Season", "Winter", "Autumn"], "colors": ["Black", "Dark Brown", "Oxblood", "Tan"]},
    {"category": "Shoes", "subcategory": "Leather Derby Shoes", "occasion": "Formal", "seasons": ["All Season", "Autumn", "Spring"], "colors": ["Black", "Brown", "Burgundy"]},
    {"category": "Shoes", "subcategory": "Classic Court Pumps", "occasion": "Formal", "seasons": ["All Season", "Spring", "Autumn"], "colors": ["Black", "Nude", "Navy", "Burgundy"]},
    {"category": "Shoes", "subcategory": "Formal Leather Loafers", "occasion": "Formal", "seasons": ["All Season", "Spring", "Autumn"], "colors": ["Black", "Brown", "Cordovan"]},
    {"category": "Shoes", "subcategory": "Patent Leather Dress Shoes", "occasion": "Formal", "seasons": ["All Season", "Winter"], "colors": ["Black"]},

    # --- SHOES (Party) ---
    {"category": "Shoes", "subcategory": "Stiletto Heels", "occasion": "Party", "seasons": ["All Season", "Summer", "Spring"], "colors": ["Black", "Red", "Gold", "Silver", "Nude", "Hot Pink"]},
    {"category": "Shoes", "subcategory": "Stiletto Sandals", "occasion": "Party", "seasons": ["Summer", "Spring", "All Season"], "colors": ["Black", "Gold", "Silver", "Red"]},
    {"category": "Shoes", "subcategory": "Strappy Party Sandals", "occasion": "Party", "seasons": ["Summer", "Spring", "All Season"], "colors": ["Gold", "Silver", "Metallic", "Black", "Rose Gold"]},
    {"category": "Shoes", "subcategory": "Glitter Ankle Boots", "occasion": "Party", "seasons": ["Winter", "Autumn"], "colors": ["Silver", "Black Sparkle", "Gold", "Burgundy"]},
    {"category": "Shoes", "subcategory": "Chunky Platform Heels", "occasion": "Party", "seasons": ["All Season", "Autumn", "Spring"], "colors": ["Black", "Patent Pink", "Silver", "Red"]},

    # --- ACCESSORIES (Casual) ---
    {"category": "Accessories", "subcategory": "Baseball Cap", "occasion": "Casual", "seasons": ["All Season", "Summer", "Spring"], "colors": ["Black", "Navy", "White", "Green", "Red"]},
    {"category": "Accessories", "subcategory": "Beanie Hat", "occasion": "Casual", "seasons": ["Winter", "Autumn"], "colors": ["Grey", "Black", "Mustard", "Burgundy", "Navy"]},
    {"category": "Accessories", "subcategory": "Backpack", "occasion": "Casual", "seasons": ["All Season"], "colors": ["Black", "Grey", "Navy", "Olive", "Brown"]},
    {"category": "Accessories", "subcategory": "Tote Bag", "occasion": "Casual", "seasons": ["All Season", "Summer", "Spring"], "colors": ["Canvas Beige", "Black", "Olive", "Navy"]},
    {"category": "Accessories", "subcategory": "Sunglasses", "occasion": "Casual", "seasons": ["Summer", "Spring", "All Season"], "colors": ["Black", "Tortoise", "Brown", "Gold"]},

    # --- ACCESSORIES (Formal) ---
    {"category": "Accessories", "subcategory": "Silk Necktie", "occasion": "Formal", "seasons": ["All Season"], "colors": ["Navy", "Burgundy", "Black", "Silver", "Emerald"]},
    {"category": "Accessories", "subcategory": "Silk Bowtie", "occasion": "Formal", "seasons": ["All Season"], "colors": ["Black", "Midnight Blue", "Burgundy", "White"]},
    {"category": "Accessories", "subcategory": "Leather Briefcase", "occasion": "Formal", "seasons": ["All Season"], "colors": ["Black", "Dark Brown", "Tan"]},
    {"category": "Accessories", "subcategory": "Formal Dress Watch", "occasion": "Formal", "seasons": ["All Season"], "colors": ["Silver/Black", "Gold/Brown", "Rose Gold", "Steel"]},
    {"category": "Accessories", "subcategory": "Pearl Necklace", "occasion": "Formal", "seasons": ["All Season"], "colors": ["White", "Cream", "Silver"]},
    {"category": "Accessories", "subcategory": "Handbag", "occasion": "Formal", "seasons": ["All Season"], "colors": ["Black", "Brown", "Navy", "Beige"]},

    # --- ACCESSORIES (Party) ---
    {"category": "Accessories", "subcategory": "Glitter Clutch Bag", "occasion": "Party", "seasons": ["All Season"], "colors": ["Gold", "Silver", "Black Sparkle", "Rose Gold", "Emerald"]},
    {"category": "Accessories", "subcategory": "Statement Chandelier Earrings", "occasion": "Party", "seasons": ["All Season"], "colors": ["Gold", "Silver", "Crystal", "Ruby Red", "Emerald"]},
    {"category": "Accessories", "subcategory": "Rhinestone Choker", "occasion": "Party", "seasons": ["All Season"], "colors": ["Silver", "Gold", "Iridescent"]},
    {"category": "Accessories", "subcategory": "Metallic Chain Belt", "occasion": "Party", "seasons": ["All Season", "Summer"], "colors": ["Gold", "Silver"]},
    {"category": "Accessories", "subcategory": "Mini Crossbody Party Bag", "occasion": "Party", "seasons": ["All Season"], "colors": ["Metallic Gold", "Black Patent", "Silver", "Red"]}
]


def generate_dataset(random_state: int = 42) -> pd.DataFrame:
    """
    Generates a structured, balanced clothing occasion classification dataset.
    Combines every taxonomy combination with real database records.
    """
    np.random.seed(random_state)
    records = []

    for item in CLOTHING_TAXONOMY:
        category = item["category"]
        subcategory = item["subcategory"]
        occasion = item["occasion"]
        seasons = item["seasons"]
        colors = item["colors"]

        for s in seasons:
            for c in colors:
                records.append({
                    "category": category,
                    "subcategory": subcategory,
                    "season": s,
                    "color": c,
                    "occasion": occasion
                })

    # Integrate real labeled data from SQLite database
    if os.path.exists(DB_PATH):
        try:
            con = sqlite3.connect(DB_PATH)
            cur = con.cursor()
            cur.execute("SELECT category, subcategory, season, color, occasion FROM clothing_items WHERE occasion IS NOT NULL AND occasion != ''")
            db_rows = cur.fetchall()
            con.close()
            for r in db_rows:
                cat, subcat, season, color, occ = r
                if occ in ["Casual", "Formal", "Party"]:
                    for _ in range(5):
                        records.append({
                            "category": cat or "Tops",
                            "subcategory": subcat or "Garment",
                            "season": season or "All Season",
                            "color": color or "Mixed",
                            "occasion": occ
                        })
                elif occ in ["Work", "Date Night", "Gym"]:
                    mapped_occ = "Formal" if occ == "Work" else ("Party" if occ == "Date Night" else "Casual")
                    for _ in range(5):
                        records.append({
                            "category": cat or "Tops",
                            "subcategory": subcat or "Garment",
                            "season": season or "All Season",
                            "color": color or "Mixed",
                            "occasion": mapped_occ
                        })
            print(f"Incorporated {len(db_rows)} real wardrobe items from SQLite users.db.")
        except Exception as e:
            print(f"Notice: Could not load DB items: {e}")

    df = pd.DataFrame(records)
    df = df.sample(frac=1.0, random_state=random_state).reset_index(drop=True)
    return df


def load_or_create_dataset(force_recreate: bool = False) -> pd.DataFrame:
    os.makedirs(os.path.dirname(CSV_PATH), exist_ok=True)
    if os.path.exists(CSV_PATH) and not force_recreate:
        return pd.read_csv(CSV_PATH)
    df = generate_dataset()
    df.to_csv(CSV_PATH, index=False)
    print(f"Saved dataset with {len(df)} records to {CSV_PATH}")
    return df


if __name__ == "__main__":
    df = load_or_create_dataset(force_recreate=True)
    print("Dataset Summary:")
    print(f"Total Records: {len(df)}")
    print("\nClass Distribution (Occasion):")
    print(df["occasion"].value_counts())
    print("\nSample Data:")
    print(df.head(10))
