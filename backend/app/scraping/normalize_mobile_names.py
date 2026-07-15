"""Backfill normalized names and ranking fields for scraped Firestore products."""

from __future__ import annotations

import argparse
from datetime import datetime

from app.core.firebase import firestore_db
from app.recommendation.processor_engine import score_product
from app.scraping.processor_normalizer import (
    normalize_product_name,
    normalize_scraped_product_fields,
)


def normalize_collection(collection_name: str = "phones", limit: int = 0) -> dict:
    query = firestore_db.collection(collection_name)
    if limit > 0:
        query = query.limit(limit)

    scanned = 0
    updated = 0

    for doc in query.stream():
        scanned += 1
        data = doc.to_dict() or {}
        payload = data.copy()

        raw_name = payload.get("raw_name") or payload.get("name", "")
        payload["raw_name"] = raw_name

        normalized_name = normalize_product_name(raw_name, payload.get("category", collection_name))
        if normalized_name:
            payload["normalized_name"] = normalized_name
            payload["name"] = normalized_name

        normalized = normalize_scraped_product_fields(payload)
        payload["normalized_name"] = normalized["name"] or payload.get("normalized_name", "")
        payload["name"] = payload["normalized_name"] or payload.get("name", "")
        payload["brand"] = normalized["brand"]
        payload["ram"] = normalized["ram"]
        payload["storage"] = normalized["storage"]
        payload["processor"] = normalized["processor"]
        payload["gpu"] = normalized["gpu"]
        payload["battery"] = normalized["battery"]
        payload["gpu_memory"] = normalized["gpu_memory"]
        payload["image_url"] = normalized["image_url"] or payload.get("image_url", "")
        payload["price_numeric"] = normalized["price_numeric"]
        payload["scraped_at"] = payload.get("scraped_at") or datetime.now().isoformat()

        score_info = score_product(payload)
        payload["device_score"] = float(score_info.get("score", 0.0))
        payload["device_tier"] = score_info.get("tier", "Unknown")
        payload["normalized_processor"] = score_info.get("normalized_processor", "Unknown")
        payload["performance_breakdown"] = score_info.get("breakdown", {})
        payload["score_specs"] = score_info.get("specs", {})
        payload["score_type"] = score_info.get("score_type", "unknown")

        doc.reference.set(payload, merge=True)
        updated += 1

    return {
        "collection": collection_name,
        "scanned": scanned,
        "updated": updated,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Normalize scraped product names and ranking fields.")
    parser.add_argument("--collection", default="phones", help="Firestore collection to normalize")
    parser.add_argument("--limit", type=int, default=0, help="Optional cap on documents to process")
    args = parser.parse_args()

    result = normalize_collection(args.collection, args.limit)
    print(
        f"Normalized {result['updated']} documents from '{result['collection']}' "
        f"(scanned {result['scanned']})."
    )


if __name__ == "__main__":
    main()