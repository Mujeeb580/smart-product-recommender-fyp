from typing import Dict, List


def _tokenize(text: str) -> List[str]:
    return [token for token in text.lower().split() if token]


def _product_text(product: Dict) -> str:
    fields = [
        product.get("name", ""),
        product.get("brand", ""),
        product.get("category", ""),
        product.get("ram", ""),
        product.get("storage", ""),
        product.get("processor", ""),
        product.get("gpu", ""),
        product.get("camera", ""),
        product.get("battery", ""),
        product.get("specs", ""),
    ]
    return " ".join(str(value) for value in fields if value)


def recommend_products(query: str, products: List[Dict], top_n: int = 10) -> List[Dict]:
    if not products:
        return []

    query_tokens = set(_tokenize(query))
    if not query_tokens:
        ranked = []
        for p in products:
            copy = dict(p)
            copy["similarity_score"] = float(copy.get("similarity_score", 0.0))
            ranked.append(copy)
        return ranked[:top_n]

    ranked = []
    for product in products:
        text = _product_text(product)
        product_tokens = set(_tokenize(text))
        overlap = query_tokens.intersection(product_tokens)

        # Jaccard style score with slight floor for stable ordering.
        denominator = len(query_tokens.union(product_tokens)) or 1
        score = len(overlap) / denominator

        # Prioritize products that include all terms strongly.
        if overlap == query_tokens:
            score += 0.25

        item = dict(product)
        item["similarity_score"] = round(float(score), 4)
        ranked.append(item)

    ranked.sort(key=lambda x: x.get("similarity_score", 0.0), reverse=True)
    return ranked[:top_n]
