# backend/app/recommendation/engine.py

from sklearn.metrics.pairwise import cosine_similarity
from .model import get_model


def product_to_text(product: dict) -> str:
    """
    Convert product dictionary into a semantic-rich text string.
    """
    return (
        f"name: {product.get('name', '')} | "
        f"brand: {product.get('brand', '')} | "
        f"ram: {product.get('ram', '')} | "
        f"storage: {product.get('storage', '')} | "
        f"category: {product.get('category', '')} | "
        f"price: {product.get('price', '')}"
    )


def recommend_products(query: str, products: list, top_n: int = 5):
    """
    Returns top N products based on semantic similarity.
    """
    if not products:
        return []

    model = get_model()

    product_texts = [product_to_text(p) for p in products]

    query_embedding = model.encode([query])
    product_embeddings = model.encode(product_texts)

    similarities = cosine_similarity(query_embedding, product_embeddings)[0]

    ranked = sorted(
        zip(products, similarities),
        key=lambda x: x[1],
        reverse=True
    )

    top_results = []
    for product, score in ranked[:top_n]:
        product_copy = product.copy()
        product_copy["similarity_score"] = round(float(score), 4)
        top_results.append(product_copy)

    return top_results
