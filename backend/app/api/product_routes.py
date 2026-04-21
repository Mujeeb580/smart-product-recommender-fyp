from fastapi import APIRouter, HTTPException, Query
from typing import Optional, List
from app.recommendation.firestore import fetch_products
from app.recommendation.engine import recommend_products

router = APIRouter(prefix="/products", tags=["Products"])


def _normalize_product(product: dict, default_category: str = "") -> dict:
    item = product.copy()
    item["image_url"] = (
        item.get("image_url")
        or item.get("image")
        or item.get("imageLink")
        or item.get("image_link")
        or ""
    )
    if default_category and not item.get("category"):
        item["category"] = default_category
    return item


def _merge_dedup_products(products: List[dict]) -> List[dict]:
    merged = []
    seen = set()
    for product in products:
        key = product.get("product_id") or product.get("id") or product.get("url") or product.get("name")
        if not key or key in seen:
            continue
        seen.add(key)
        merged.append(product)
    return merged


def _get_all_products(collection: Optional[str] = None) -> List[dict]:
    if collection:
        c = collection.lower().strip()
        if c in ("phone", "phones"):
            return [_normalize_product(p, "Phones") for p in fetch_products("phones")]
        if c in ("laptop", "laptops"):
            return [_normalize_product(p, "Laptops") for p in fetch_products("laptops")]
        return [_normalize_product(p) for p in fetch_products(c)]

    phones = [_normalize_product(p, "Phones") for p in fetch_products("phones")]
    laptops = [_normalize_product(p, "Laptops") for p in fetch_products("laptops")]
    legacy = [_normalize_product(p) for p in fetch_products("products")]
    return _merge_dedup_products(phones + laptops + legacy)


@router.get("/recommend")
async def get_recommendations(
    query: Optional[str] = Query(None, description="Search query for recommendations"),
    top_n: int = Query(10, description="Number of products to return"),
    collection: Optional[str] = Query(None, description="Optional collection: phones or laptops"),
):
    """
    Get product recommendations based on query or return all products sorted by score.
    """
    try:
        products = _get_all_products(collection=collection)
        
        if not products:
            return {"products": [], "message": "No products available"}
        
        # If query provided, use recommendation engine
        if query:
            recommended = recommend_products(query, products, top_n=top_n)
        else:
            # Return all products sorted by any existing score
            recommended = sorted(
                products,
                key=lambda x: x.get("similarity_score", 0),
                reverse=True
            )[:top_n]
        
        return {
            "products": recommended,
            "count": len(recommended),
            "query": query
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching recommendations: {str(e)}")


@router.get("/search")
async def search_products(
    q: str = Query(..., description="Search query"),
    collection: Optional[str] = Query(None, description="Optional collection: phones or laptops"),
):
    """
    Search products by name, brand, or category.
    """
    try:
        products = _get_all_products(collection=collection)
        
        if not products:
            return {"products": [], "message": "No products available"}
        
        # Use recommendation engine for semantic search
        results = recommend_products(q, products, top_n=20)
        
        return {
            "products": results,
            "count": len(results),
            "query": q
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error searching products: {str(e)}")


@router.get("/filter")
async def filter_products(
    category: Optional[str] = Query(None, description="Filter by category"),
    min_price: Optional[float] = Query(None, description="Minimum price"),
    max_price: Optional[float] = Query(None, description="Maximum price"),
    brand: Optional[str] = Query(None, description="Filter by brand"),
    collection: Optional[str] = Query(None, description="Optional collection: phones or laptops"),
    limit: int = Query(100, description="Max items to return"),
):
    """
    Filter products by various criteria.
    """
    try:
        products = _get_all_products(collection=collection)
        
        if not products:
            return {"products": [], "message": "No products available"}
        
        filtered_products = products
        
        # Apply filters
        if category:
            filtered_products = [
                p for p in filtered_products
                if category.lower() in p.get("category", "").lower()
            ]
        
        if brand:
            filtered_products = [
                p for p in filtered_products
                if p.get("brand", "").lower() == brand.lower()
            ]
        
        if min_price is not None:
            filtered_products = [
                p for p in filtered_products
                if _to_price(p.get("price")) >= min_price
            ]
        
        if max_price is not None:
            filtered_products = [
                p for p in filtered_products
                if _to_price(p.get("price")) <= max_price
            ]
        
        filtered_products = filtered_products[:max(1, limit)]

        return {
            "products": filtered_products,
            "count": len(filtered_products),
            "filters": {
                "category": category,
                "brand": brand,
                "min_price": min_price,
                "max_price": max_price,
                "collection": collection,
                "limit": limit,
            }
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error filtering products: {str(e)}")


@router.get("/trending")
async def get_trending_products(
    limit: int = Query(5, description="Number of trending products")
):
    """
    Get trending/popular products.
    """
    try:
        products = _get_all_products()
        
        if not products:
            return {"products": [], "message": "No products available"}
        
        # Sort by price descending (simulating popularity) or any other metric
        trending = sorted(
            products,
            key=lambda x: x.get("price", 0),
            reverse=True
        )[:limit]
        
        return {
            "products": trending,
            "count": len(trending)
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching trending products: {str(e)}")


@router.get("/{product_id}")
async def get_product_by_id(product_id: str):
    """
    Get a specific product by ID.
    """
    try:
        products = _get_all_products()
        
        for product in products:
            if product.get("id") == product_id:
                return {"product": product}
        
        raise HTTPException(status_code=404, detail="Product not found")
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching product: {str(e)}")


def _to_price(value) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    raw = str(value or "").replace("Rs", "").replace("PKR", "").replace(",", "").strip()
    try:
        return float(raw)
    except Exception:
        return float("inf")
