from typing import Optional

from fastapi import APIRouter, HTTPException, Query

from app.recommendation.engine import recommend_products
from app.recommendation.firestore import fetch_products


router = APIRouter(prefix="/products", tags=["Products"])


@router.get("/recommend")
async def get_recommendations(
    query: Optional[str] = Query(None, description="Search query for recommendations"),
    top_n: int = Query(10, ge=1, le=100),
    collection: Optional[str] = Query(None, description="products/phones/laptops"),
):
    try:
        products = fetch_products(collection_name=collection, limit=500)
        if not products:
            return {"products": [], "count": 0, "query": query}

        if query:
            recommended = recommend_products(query, products, top_n=top_n)
        else:
            recommended = sorted(
                products,
                key=lambda x: float(x.get("price", 0) or 0),
                reverse=True,
            )[:top_n]

        return {"products": recommended, "count": len(recommended), "query": query}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error fetching recommendations: {exc}")


@router.get("/search")
async def search_products(
    q: str = Query(..., min_length=1, description="Search query"),
    collection: Optional[str] = Query(None),
):
    try:
        products = fetch_products(collection_name=collection, limit=500)
        results = recommend_products(q, products, top_n=50)
        return {"products": results, "count": len(results), "query": q}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error searching products: {exc}")


@router.get("/filter")
async def filter_products(
    category: Optional[str] = Query(None),
    min_price: Optional[float] = Query(None, ge=0),
    max_price: Optional[float] = Query(None, ge=0),
    brand: Optional[str] = Query(None),
    collection: Optional[str] = Query(None),
    limit: int = Query(100, ge=1, le=1000),
):
    try:
        products = fetch_products(collection_name=collection, limit=limit)
        filtered = products

        if category:
            filtered = [p for p in filtered if str(p.get("category", "")).lower() == category.lower()]
        if brand:
            filtered = [p for p in filtered if str(p.get("brand", "")).lower() == brand.lower()]
        if min_price is not None:
            filtered = [p for p in filtered if float(p.get("price", 0) or 0) >= min_price]
        if max_price is not None:
            filtered = [p for p in filtered if float(p.get("price", 0) or 0) <= max_price]

        return {
            "products": filtered,
            "count": len(filtered),
            "filters": {
                "category": category,
                "brand": brand,
                "min_price": min_price,
                "max_price": max_price,
                "collection": collection,
                "limit": limit,
            },
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error filtering products: {exc}")


@router.get("/trending")
async def get_trending_products(limit: int = Query(5, ge=1, le=50), collection: Optional[str] = Query(None)):
    try:
        products = fetch_products(collection_name=collection, limit=500)
        trending = sorted(products, key=lambda x: float(x.get("price", 0) or 0), reverse=True)[:limit]
        return {"products": trending, "count": len(trending)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error fetching trending products: {exc}")


@router.get("/{product_id}")
async def get_product_by_id(product_id: str, collection: Optional[str] = Query(None)):
    try:
        products = fetch_products(collection_name=collection, limit=1000)
        for product in products:
            if product.get("id") == product_id or product.get("product_id") == product_id:
                return {"product": product}
        raise HTTPException(status_code=404, detail="Product not found")
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error fetching product: {exc}")
