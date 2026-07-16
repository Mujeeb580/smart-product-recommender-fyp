import firebase_admin
from firebase_admin import credentials, firestore
from typing import List, Dict, Optional
import os

# Global Firestore client
_db = None

def get_firestore_client():
    """
    Initialize and return Firestore client.
    Uses singleton pattern to avoid multiple initializations.
    """
    global _db
    if _db is None:
        # Initialize Firebase (assumes credentials already exist)
        if not firebase_admin._apps:
            default_path = os.path.abspath(
                os.path.join(os.path.dirname(__file__), "../../firebase-key.json")
            )
            env_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
            cred_path = os.path.abspath(env_path) if env_path else default_path
            if not os.path.exists(cred_path):
                raise FileNotFoundError(f"firebase-key.json not found at {cred_path}")
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
        _db = firestore.client()
    return _db


def _normalize_product(doc_id: str, product: Dict, default_category: str = "") -> Dict:
    normalized = product.copy()
    normalized["id"] = doc_id
    normalized["image_url"] = (
        normalized.get("image_url")
        or normalized.get("image")
        or normalized.get("imageLink")
        or normalized.get("image_link")
        or ""
    )
    if default_category and not normalized.get("category"):
        normalized["category"] = default_category
    return normalized

def _dedupe_products(products: List[Dict]) -> List[Dict]:
    merged: List[Dict] = []
    seen = set()

    for product in products:
        key = product.get("product_id") or product.get("id") or product.get("url") or product.get("name")
        if not key or key in seen:
            continue
        seen.add(key)
        merged.append(product)

    return merged


def _category_filter(products: List[Dict], collection_name: str) -> List[Dict]:
    if not collection_name:
        return products

    normalized = collection_name.lower().strip()
    if normalized in {"laptop", "laptops"}:
        keywords = ("laptop", "notebook", "macbook")
    elif normalized in {"phone", "phones", "mobile", "mobiles"}:
        keywords = ("phone", "mobile", "smartphone", "iphone")
    else:
        return products

    filtered = []
    for product in products:
        text = " ".join(
            str(product.get(field, "")) for field in ("category", "collection", "name", "brand")
        ).lower()
        if any(keyword in text for keyword in keywords):
            filtered.append(product)

    return filtered


def fetch_products(collection_name: Optional[str] = None, limit: int = 300) -> List[Dict]:
    """
    Fetch products from one collection or merge the main product collections.

    If a phone/laptop-specific collection is empty, fall back to the shared
    products collection so UI category screens and chat queries still work.
    """
    db = get_firestore_client()

    if collection_name:
        normalized_name = collection_name.lower().strip()
        candidate_names = [normalized_name]

        # Phone/laptop collections often need fallback to the shared products
        # collection because scraped items may only exist there.
        if normalized_name in {"phones", "phone", "laptops", "laptop"}:
            candidate_names.append("products")

        products: List[Dict] = []
        print(f"Fetching products from '{collection_name}' collection...")
        for name in candidate_names:
            query = db.collection(name)
            if limit > 0:
                query = query.limit(limit)

            for doc in query.stream():
                products.append(_normalize_product(doc.id, doc.to_dict(), name))

        products = _dedupe_products(_category_filter(products, collection_name))
        if normalized_name in {"phones", "phone", "laptops", "laptop"}:
            category = "Phones" if normalized_name in {"phones", "phone"} else "Laptops"
            for product in products:
                if str(product.get("category") or "").strip().lower() in ("", "product", "products"):
                    product["category"] = category
        print(f"Fetched {len(products)} products.")
        return products

    merged: List[Dict] = []
    seen_ids = set()

    for name in ["products", "phones", "laptops"]:
        query = db.collection(name)
        if limit > 0:
            query = query.limit(limit)

        for doc in query.stream():
            item = _normalize_product(doc.id, doc.to_dict(), name)
            item_id = item.get("id") or item.get("product_id")
            if item_id in seen_ids:
                continue
            seen_ids.add(item_id)
            merged.append(item)

    print(f"Fetched {len(merged)} products.")
    return merged
