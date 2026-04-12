import re
from typing import Dict, List, Optional


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


def _to_price(value) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        cleaned = value.lower().replace("rs", "").replace("pkr", "").replace(",", "").strip()
        cleaned = cleaned.replace(" ", "")
        if not cleaned:
            return None

        multiplier = 1.0
        if cleaned.endswith("k"):
            multiplier = 1000.0
            cleaned = cleaned[:-1]

        try:
            return float(cleaned) * multiplier
        except ValueError:
            return None
    return None


def _extract_price_limit(query: str) -> Optional[float]:
    normalized = query.lower().replace("pkrs", "rs").replace("pkr", "rs")
    normalized = normalized.replace("under", "under ").replace("below", "below ")
    normalized = normalized.replace("less than", "less than ").replace("up to", "up to ")
    normalized = normalized.replace("upto", "up to ")

    patterns = [
        r"(?:under|below|less than|up to|upto|maximum|max|within)\s*(?:rs\.?|rs)?\s*([0-9][0-9,]*\.?[0-9]*)\s*([k]?)",
        r"(?:under|below|less than|up to|upto|maximum|max|within)\s*(?:rs\.?|rs)?\s*([0-9]+)\s*k\b",
    ]

    for pattern in patterns:
        match = re.search(pattern, normalized)
        if not match:
            continue

        number_text = match.group(1).replace(",", "")
        suffix = match.group(2) if len(match.groups()) > 1 else ""
        try:
            value = float(number_text)
            if suffix and suffix.lower() == "k":
                value *= 1000.0
            return value
        except ValueError:
            continue

    shorthand = re.search(r"\b([0-9]+(?:\.[0-9]+)?)\s*k\b", normalized)
    if shorthand:
        try:
            return float(shorthand.group(1)) * 1000.0
        except ValueError:
            return None

    return None


def recommend_products(query: str, products: List[Dict], top_n: int = 10) -> List[Dict]:
    if not products:
        return []

    lower_query = query.lower()
    max_price = _extract_price_limit(query)
    wants_flagship = any(word in lower_query for word in ["flagship", "premium", "pro max", "ultra"])
    filtered_products = products
    if max_price is not None:
        filtered_products = []
        for product in products:
            price = _to_price(product.get("price"))
            if price is None:
                continue
            if price <= max_price:
                filtered_products.append(product)

        if not filtered_products:
            filtered_products = products

    query_tokens = set(_tokenize(query))
    if not query_tokens:
        ranked = []
        for p in filtered_products:
            copy = dict(p)
            copy["similarity_score"] = float(copy.get("similarity_score", 0.0))
            ranked.append(copy)
        return ranked[:top_n]

    ranked = []
    for product in filtered_products:
        text = _product_text(product)
        product_tokens = set(_tokenize(text))
        overlap = query_tokens.intersection(product_tokens)

        # Jaccard style score with slight floor for stable ordering.
        denominator = len(query_tokens.union(product_tokens)) or 1
        score = len(overlap) / denominator

        # Prioritize products that include all terms strongly.
        if overlap == query_tokens:
            score += 0.25

        # If user gave a max budget, prefer options closer to that cap.
        # Example: "under 50k" should favor ~45-50k over ~20k when relevance is similar.
        if max_price is not None:
            price = _to_price(product.get("price"))
            if price is not None and 0 < max_price:
                ratio = price / max_price
                # Keep full score near the cap, gently penalize very cheap options.
                # Floor avoids over-penalizing genuinely good lower-priced matches.
                budget_weight = max(0.6, min(1.0, ratio))
                score *= budget_weight

        # For flagship intent without explicit budget, favor premium tier prices.
        if wants_flagship and max_price is None:
            price = _to_price(product.get("price"))
            if price is not None:
                if price >= 180000:
                    score += 0.18
                elif price >= 120000:
                    score += 0.1
                elif price < 70000:
                    score -= 0.06

        item = dict(product)
        item["similarity_score"] = round(float(score), 4)
        ranked.append(item)

    ranked.sort(key=lambda x: x.get("similarity_score", 0.0), reverse=True)
    return ranked[:top_n]
