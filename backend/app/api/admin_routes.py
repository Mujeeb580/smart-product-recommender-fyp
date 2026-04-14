from typing import Dict, List, Literal, Optional

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from app.recommendation.firestore import fetch_products
from app.core.firebase import firestore_db
from app.scraping.priceoye_scraper import scrape_laptops, scrape_phones


router = APIRouter(prefix="/admin", tags=["Admin"])


class ScrapeRequest(BaseModel):
    mode: Literal[
        "phones",
        "laptops",
        "all",
        "new_phones",
        "new_laptops",
    ]


def _count_for(collection_name: str) -> int:
    return len(fetch_products(collection_name))


@router.get("/overview")
async def admin_overview():
    try:
        counts = {
            "products": _count_for("products"),
            "phones": _count_for("phones"),
            "laptops": _count_for("laptops"),
            "chat_history": _count_for("chat_history"),
        }
        counts["total"] = counts["products"] + counts["phones"] + counts["laptops"]
        return counts
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error loading admin overview: {exc}")


@router.get("/products")
async def admin_products(
    collection: str = Query("products", description="products/phones/laptops"),
    limit: int = Query(200, ge=1, le=5000),
    q: Optional[str] = Query(None),
):
    try:
        rows: List[Dict] = fetch_products(collection)
        rows = rows[:limit]
        if q:
            needle = q.lower()
            rows = [
                item
                for item in rows
                if needle in str(item.get("name", "")).lower()
                or needle in str(item.get("brand", "")).lower()
                or needle in str(item.get("category", "")).lower()
            ]
        return {"products": rows, "count": len(rows), "collection": collection, "query": q}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error loading admin products: {exc}")


@router.get("/collections")
async def admin_collections():
    try:
        data = []
        for name in ["products", "phones", "laptops", "chat_history"]:
            data.append({"name": name, "count": _count_for(name)})
        return {"collections": data}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error loading collections: {exc}")


@router.get("/scrape/verify-firestore")
async def verify_firestore_connection():
    try:
        docs = list(firestore_db.collection("phones").limit(1).stream())
        return {"ok": True, "sample_docs": len(docs)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Firestore connection failed: {exc}")


@router.post("/scrape/run")
async def run_scraper(payload: ScrapeRequest):
    try:
        mode = payload.mode
        results: List[Dict] = []

        # Verify Firestore before scraping to fail fast with clear message.
        list(firestore_db.collection("phones").limit(1).stream())

        if mode == "phones":
            results.append(scrape_phones(stop_on_existing=False))
        elif mode == "laptops":
            results.append(scrape_laptops(stop_on_existing=False))
        elif mode == "all":
            results.append(scrape_phones(stop_on_existing=False))
            results.append(scrape_laptops(stop_on_existing=False))
        elif mode == "new_phones":
            results.append(scrape_phones(stop_on_existing=True))
        elif mode == "new_laptops":
            results.append(scrape_laptops(stop_on_existing=True))

        total_saved = sum(int(item.get("saved", 0)) for item in results)
        total_updated = sum(int(item.get("updated", 0)) for item in results)

        return {
            "ok": True,
            "mode": mode,
            "saved": total_saved,
            "updated": total_updated,
            "results": results,
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Scraping failed: {exc}")
