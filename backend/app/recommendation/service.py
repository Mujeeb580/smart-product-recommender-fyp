# backend/app/recommendation/service.py

from .engine import recommend_products


def get_recommendations(query: str, products: list, top_n: int = 5):
    """
    Service-level function (API-ready).
    """
    return recommend_products(
        query=query,
        products=products,
        top_n=top_n
    )
