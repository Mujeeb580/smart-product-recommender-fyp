from typing import Dict, List, Optional
from firebase_admin import firestore
from app.core.firebase import firestore_db


def _normalize_product(doc_id: str, payload: Dict, collection_name: str) -> Dict:
    item = dict(payload or {})
    item.setdefault("id", doc_id)
    item.setdefault("collection", collection_name)
    item.setdefault("product_id", doc_id)
    item.setdefault("name", "Unknown Product")
    item.setdefault("brand", "Unknown")
    item.setdefault("category", collection_name)
    item.setdefault("similarity_score", 0.0)

    raw_price = item.get("price", 0)
    try:
        if isinstance(raw_price, str):
            cleaned = raw_price.replace("Rs", "").replace(",", "").strip()
            item["price"] = float(cleaned) if cleaned else 0.0
        else:
            item["price"] = float(raw_price)
    except Exception:
        item["price"] = 0.0

    if not item.get("image"):
        item["image"] = ""

    if not item.get("specs"):
        specs = []
        for key in ["ram", "storage", "processor", "gpu", "battery", "camera"]:
            value = item.get(key)
            if value:
                specs.append(f"{key}: {value}")
        item["specs"] = " | ".join(specs)

    return item


def fetch_collection(collection_name: str, limit: int = 200) -> List[Dict]:
    query = firestore_db.collection(collection_name)
    if limit > 0:
        query = query.limit(limit)

    docs = query.stream()
    products: List[Dict] = []
    for doc in docs:
        products.append(_normalize_product(doc.id, doc.to_dict(), collection_name))
    return products


def fetch_products(collection_name: Optional[str] = None, limit: int = 300) -> List[Dict]:
    """Fetch products from one collection or merge main product collections."""
    if collection_name:
        return fetch_collection(collection_name, limit=limit)

    merged: List[Dict] = []
    seen_ids = set()

    for name in ["products", "phones", "laptops"]:
        for item in fetch_collection(name, limit=limit):
            item_id = item.get("id") or item.get("product_id")
            if item_id in seen_ids:
                continue
            seen_ids.add(item_id)
            merged.append(item)

    return merged


def save_chat_message(payload: Dict) -> str:
    doc_ref = firestore_db.collection("chat_history").document()
    doc_ref.set(payload)
    return doc_ref.id


def get_chat_history(limit: int = 50) -> List[Dict]:
    query = (
        firestore_db.collection("chat_history")
        .order_by("timestamp", direction=firestore.Query.DESCENDING)
        .limit(limit)
    )

    rows: List[Dict] = []
    for doc in query.stream():
        data = doc.to_dict() or {}
        data["id"] = doc.id
        rows.append(data)

    rows.reverse()
    return rows


def update_product_fields(collection_name: str, doc_id: str, fields: Dict) -> None:
    if not collection_name or not doc_id or not fields:
        return

    cleaned = {k: v for k, v in fields.items() if v not in (None, "", "unknown")}
    if not cleaned:
        return

    firestore_db.collection(collection_name).document(doc_id).set(cleaned, merge=True)
