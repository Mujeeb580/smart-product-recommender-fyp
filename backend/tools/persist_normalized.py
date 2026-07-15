"""Migration script: compute normalized spec fields and device score and persist to Firestore.
Run from project root with PYTHONPATH pointing to backend, e.g.:

PowerShell:
$env:PYTHONPATH="g:\FYP\smart-product-recommender-fyp\backend" ; .\.venv\Scripts\python.exe backend\tools\persist_normalized.py
"""

from app.recommendation import firestore as fs
from app.recommendation import processor_engine
from app.recommendation import engine as rec_engine

from firebase_admin import firestore

BATCH_SIZE = 50
COLLECTIONS = ["phones", "laptops", "products"]


def normalize_and_persist(collection_name: str):
    db = fs.get_firestore_client()
    col = db.collection(collection_name)
    docs = list(col.stream())
    total = len(docs)
    print(f"Found {total} documents in '{collection_name}'")
    count = 0
    for doc in docs:
        try:
            data = doc.to_dict() or {}
            doc_id = doc.id
            # compute score using the shared scorer
            score_info = processor_engine.score_product(data)
            # normalized fields
            update = {
                "normalized_processor": score_info.get("normalized_processor"),
                "score_specs": score_info.get("specs"),
                "device_score": float(score_info.get("score", 0.0)),
                "device_tier": score_info.get("tier"),
                "score_type": score_info.get("score_type"),
            }
            # also add numeric price if parseable
            price = data.get("price")
            try:
                if isinstance(price, (int, float)):
                    update["price_numeric"] = float(price)
                else:
                    raw = str(price or "").replace("Rs", "").replace("PKR", "").replace(",", "").strip()
                    update["price_numeric"] = float(raw) if raw else None
            except Exception:
                update["price_numeric"] = None

            col.document(doc_id).set(update, merge=True)
            count += 1
            if count % BATCH_SIZE == 0:
                print(f"  Updated {count}/{total}")
        except Exception as e:
            print(f"Failed to update {doc.id}: {e}")
    print(f"Completed updates for '{collection_name}': {count} documents updated")


if __name__ == '__main__':
    for c in COLLECTIONS:
        normalize_and_persist(c)
    print("Migration complete")
