from fastapi import APIRouter, HTTPException, Query
from typing import Optional, List
from app.recommendation.firestore import fetch_products
from app.recommendation.engine import recommend_products
from app.recommendation.processor_engine import calculate_phone_score

router = APIRouter(prefix="/products", tags=["Products"])


def _add_processor_score(product: dict) -> dict:
    """Add processor performance score to phone products."""
    item = product.copy()
    
    # Only calculate processor scores for phones
    category = item.get("category", "").lower()
    if "phone" in category or "mobile" in category:
        try:
            score_result = calculate_phone_score(item)
            item["processor_score"] = score_result.get("score", 0)
            item["processor_tier"] = score_result.get("tier", "Unknown")
            item["normalized_processor"] = score_result.get("normalized_processor", item.get("processor", "Unknown"))
            item["performance_breakdown"] = score_result.get("breakdown", {})
        except Exception as e:
            # Fallback if scoring fails
            item["processor_score"] = 0.5
            item["processor_tier"] = "Unknown"
            item["normalized_processor"] = item.get("processor", "Unknown")
            item["performance_breakdown"] = {}
    
    return item


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
    
    # Add processor scores for phones
    item = _add_processor_score(item)
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


@router.get("/phones/performance")
async def get_phones_by_performance(
    limit: int = Query(20, description="Max items to return"),
    min_score: Optional[float] = Query(None, description="Minimum processor score (0-1)"),
    tier: Optional[str] = Query(None, description="Filter by processor tier: Flagship, Upper Mid, Mid, Low"),
):
    """
    Get phones sorted by processor performance score.
    
    Params:
    - limit: Number of phones to return (default: 20)
    - min_score: Filter phones with score >= min_score (0.0-1.0)
    - tier: Filter by tier (Flagship, Upper Mid, Mid, Low)
    """
    try:
        phones = [_add_processor_score(p) for p in fetch_products("phones")]
        
        if not phones:
            return {"products": [], "message": "No phones available", "count": 0}
        
        # Filter by minimum score
        if min_score is not None:
            phones = [p for p in phones if p.get("processor_score", 0) >= min_score]
        
        # Filter by tier
        if tier:
            tier_lower = tier.lower()
            phones = [p for p in phones if p.get("processor_tier", "").lower() == tier_lower]
        
        # Sort by processor score descending
        phones = sorted(phones, key=lambda x: x.get("processor_score", 0), reverse=True)[:limit]
        
        return {
            "products": phones,
            "count": len(phones),
            "filters": {
                "min_score": min_score,
                "tier": tier,
                "limit": limit,
            }
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching phones by performance: {str(e)}")


@router.get("/phones/by-tier")
async def get_phones_by_tier(
    tier: str = Query(..., description="Processor tier: Flagship, Upper Mid, Mid, Low"),
    limit: int = Query(20, description="Max items to return"),
):
    """
    Get phones filtered by processor tier.
    
    Tiers: Flagship, Upper Mid, Mid, Low
    """
    try:
        phones = [_add_processor_score(p) for p in fetch_products("phones")]
        
        if not phones:
            return {"products": [], "message": "No phones available", "count": 0}
        
        tier_lower = tier.lower()
        filtered = [p for p in phones if p.get("processor_tier", "").lower() == tier_lower]
        
        if not filtered:
            return {"products": [], "message": f"No phones found in {tier} tier", "count": 0}
        
        # Sort by score within tier
        filtered = sorted(filtered, key=lambda x: x.get("processor_score", 0), reverse=True)[:limit]
        
        return {
            "products": filtered,
            "tier": tier,
            "count": len(filtered)
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching phones by tier: {str(e)}")


@router.post("/phones/score-details")
async def get_phone_score_details(
    product_id: Optional[str] = Query(None, description="Product ID to get details for"),
):
    """
    Get detailed score breakdown for a specific phone product.
    """
    try:
        phones = fetch_products("phones")
        
        for phone in phones:
            if phone.get("product_id") == product_id or phone.get("id") == product_id:
                scored = _add_processor_score(phone)
                return {
                    "product": {
                        "id": scored.get("id"),
                        "name": scored.get("name"),
                        "processor": scored.get("processor"),
                        "gpu": scored.get("gpu"),
                        "ram": scored.get("ram"),
                        "battery": scored.get("battery"),
                        "price": scored.get("price"),
                    },
                    "score": {
                        "overall": scored.get("processor_score"),
                        "tier": scored.get("processor_tier"),
                        "normalized_processor": scored.get("normalized_processor"),
                        "breakdown": scored.get("performance_breakdown"),
                    }
                }
        
        raise HTTPException(status_code=404, detail="Product not found")
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching phone details: {str(e)}")


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
