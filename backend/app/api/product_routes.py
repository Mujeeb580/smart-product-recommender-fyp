from fastapi import APIRouter, HTTPException, Query
from typing import Optional, List
from app.recommendation.firestore import fetch_products
from app.recommendation.engine import recommend_products

router = APIRouter(prefix="/products", tags=["Products"])


@router.get("/recommend")
async def get_recommendations(
    query: Optional[str] = Query(None, description="Search query for recommendations"),
    top_n: int = Query(10, description="Number of products to return")
):
    """
    Get product recommendations based on query or return all products sorted by score.
    """
    try:
        # Fetch products from Firestore
        products = fetch_products(collection_name="products")
        
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
):
    """
    Search products by name, brand, or category.
    """
    try:
        products = fetch_products(collection_name="products")
        
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
):
    """
    Filter products by various criteria.
    """
    try:
        products = fetch_products(collection_name="products")
        
        if not products:
            return {"products": [], "message": "No products available"}
        
        filtered_products = products
        
        # Apply filters
        if category:
            filtered_products = [
                p for p in filtered_products
                if p.get("category", "").lower() == category.lower()
            ]
        
        if brand:
            filtered_products = [
                p for p in filtered_products
                if p.get("brand", "").lower() == brand.lower()
            ]
        
        if min_price is not None:
            filtered_products = [
                p for p in filtered_products
                if p.get("price", 0) >= min_price
            ]
        
        if max_price is not None:
            filtered_products = [
                p for p in filtered_products
                if p.get("price", float('inf')) <= max_price
            ]
        
        return {
            "products": filtered_products,
            "count": len(filtered_products),
            "filters": {
                "category": category,
                "brand": brand,
                "min_price": min_price,
                "max_price": max_price
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
        products = fetch_products(collection_name="products")
        
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
        products = fetch_products(collection_name="products")
        
        for product in products:
            if product.get("id") == product_id:
                return {"product": product}
        
        raise HTTPException(status_code=404, detail="Product not found")
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching product: {str(e)}")
