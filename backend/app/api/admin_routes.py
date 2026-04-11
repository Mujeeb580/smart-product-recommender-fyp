from typing import Dict, List, Optional

from fastapi import APIRouter, HTTPException, Query

from app.recommendation.firestore import fetch_collection


router = APIRouter(prefix="/admin", tags=["Admin"])


def _count_for(collection_name: str) -> int:
    return len(fetch_collection(collection_name, limit=5000))


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
    limit: int = Query(200, ge=1, le=2000),
    q: Optional[str] = Query(None),
):
    try:
        rows: List[Dict] = fetch_collection(collection, limit=limit)
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
