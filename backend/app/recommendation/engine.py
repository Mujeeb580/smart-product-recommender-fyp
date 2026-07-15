import numpy as np
import re
import hashlib
from threading import RLock

from .model import get_model
from .text_builder import product_to_text


PHONE_HINTS = ("phone", "phones", "mobile", "mobiles", "smartphone")
LAPTOP_HINTS = ("laptop", "laptops", "notebook", "ultrabook", "macbook")

GAMING_HINTS = (
    "gaming",
    "game",
    "gamer",
    "pubg",
    "bgmi",
    "fortnite",
    "cod",
    "call of duty",
    "genshin",
)

BATTERY_HINTS = (
    "battery",
    "battery life",
    "backup",
    "long battery",
    "all day",
    "long lasting",
    "mah",
)

SOCIAL_HINTS = (
    "social media",
    "instagram",
    "facebook",
    "tiktok",
    "snapchat",
    "reels",
    "youtube",
    "shorts",
)

STUDY_HINTS = (
    "study",
    "student",
    "school",
    "college",
    "university",
    "classes",
    "class",
    "online class",
    "notes",
    "lecture",
)

GENERAL_HINTS = (
    "general use",
    "everyday",
    "daily use",
    "normal use",
    "basic use",
    "regular use",
    "for daily",
)

BUDGET_HINTS = (
    "cheap",
    "cheapest",
    "budget",
    "affordable",
    "low budget",
    "budget friendly",
    "value for money",
)

DEFAULT_BUDGET_PHONE_MAX = 30000

FLAGSHIP_PHONE_HINTS = (
    "snapdragon 8",
    "dimensity 9300",
    "dimensity 9200",
    "a18",
    "a17",
    "a16",
    "exynos 2400",
)

HIGH_END_LAPTOP_CPU_HINTS = (
    "core i9",
    "core ultra 9",
    "ryzen 9",
    "hx",
    "m3 max",
    "m4 max",
)

HIGH_END_LAPTOP_GPU_HINTS = (
    "rtx 4090",
    "rtx 4080",
    "rtx 4070",
    "rtx 5070",
    "rtx 5060",
    "rtx 4060",
)


_EMBEDDING_CACHE = {}
_EMBEDDING_CACHE_LOCK = RLock()


def _clean_text(value) -> str:
    text = str(value or "")
    replacements = {
        "\u00c2\u00ae": "",
        "\u00c2": "",
        "\u00ae": "",
        "\u2122": "",
        "\u00e2\u20ac\u00a2": "",
        "\\/": "/",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return " ".join(text.split()).strip()


def _extract_number(text: str) -> int:
    match = re.search(r"(\d+)", str(text or ""))
    return int(match.group(1)) if match else 0


def _price_to_float(price) -> float:
    if isinstance(price, (int, float)):
        return float(price)
    raw = str(price or "")
    raw = raw.replace("Rs", "").replace("PKR", "").replace(",", "").strip()
    try:
        return float(raw)
    except Exception:
        return 0.0


def _category_of(product: dict) -> str:
    category = _clean_text(product.get("category", "")).lower()
    if "phone" in category or "mobile" in category:
        return "phones"
    if "laptop" in category or "notebook" in category:
        return "laptops"
    return "unknown"


def _query_has_any(query: str, words) -> bool:
    q = query.lower()
    return any(re.search(rf"\b{re.escape(w)}\b", q) for w in words)


def _extract_budget(query: str):
    q = query.lower()
    match = re.search(r"(?:under|below|less than|upto|up to|within)\s*(?:rs\.?\s*)?(\d+(?:\.\d+)?)\s*(k|m|lakh|lac)?", q)
    if not match:
        if any(keyword in q for keyword in BUDGET_HINTS):
            return float(DEFAULT_BUDGET_PHONE_MAX)
        return None
    value = float(match.group(1))
    unit = (match.group(2) or "").lower()
    if unit == "k":
        value *= 1000
    elif unit == "m":
        value *= 1000000
    elif unit in ("lakh", "lac"):
        value *= 100000
    return value


def _extract_required_gpu(query: str) -> str:
    q = query.lower()
    match = re.search(r"(rtx\s*\d{3,4})", q)
    if match:
        return match.group(1).replace(" ", "")
    return ""


def _extract_required_processor(query: str) -> str:
    q = query.lower()
    for key in ("snapdragon 8", "snapdragon 7", "dimensity 9300", "dimensity 9200", "core i7", "core i9", "ryzen 7", "ryzen 9"):
        if key in q:
            return key
    return ""


def _extract_ram_storage_constraints(query: str):
    q = query.lower()
    ram = None
    storage = None

    ram_match = re.search(r"(\d+)\s*gb\s*ram", q)
    if ram_match:
        ram = int(ram_match.group(1))

    storage_match = re.search(r"(\d+)\s*gb\s*(?:storage|rom)", q)
    if storage_match:
        storage = int(storage_match.group(1))
    else:
        all_gb = [int(n) for n in re.findall(r"(\d+)\s*gb", q)]
        if len(all_gb) >= 2:
            storage = max(all_gb)
            if ram is None:
                ram = min(all_gb)

    return ram, storage


def _parse_query_constraints(query: str):
    q = query.lower()
    budget_max = _extract_budget(q)
    required_gpu = _extract_required_gpu(q)
    required_processor = _extract_required_processor(q)
    min_ram, min_storage = _extract_ram_storage_constraints(q)

    query_category = "unknown"
    if _query_has_any(q, PHONE_HINTS) and not _query_has_any(q, LAPTOP_HINTS):
        query_category = "phones"
    elif _query_has_any(q, LAPTOP_HINTS) and not _query_has_any(q, PHONE_HINTS):
        query_category = "laptops"

    return {
        "budget_max": budget_max,
        "required_gpu": required_gpu,
        "required_processor": required_processor,
        "min_ram": min_ram,
        "min_storage": min_storage,
        "query_category": query_category,
    }


def _apply_filter(current: list, predicate):
    filtered = [p for p in current if predicate(p)]
    return filtered if filtered else current


def _apply_hard_constraints(query: str, products: list) -> list:
    constraints = _parse_query_constraints(query)
    constrained = list(products)

    if constraints["query_category"] != "unknown":
        constrained = _apply_filter(
            constrained,
            lambda p: _category_of(p) == constraints["query_category"],
        )

    if constraints["budget_max"] is not None:
        constrained = _apply_filter(
            constrained,
            lambda p: 0 < _price_to_float(p.get("price")) <= constraints["budget_max"],
        )

    if constraints["required_gpu"]:
        needle = constraints["required_gpu"]
        constrained = _apply_filter(
            constrained,
            lambda p: needle in _clean_text(p.get("gpu", "")).lower().replace(" ", "")
            or needle in _clean_text(p.get("name", "")).lower().replace(" ", ""),
        )

    if constraints["required_processor"]:
        needle = constraints["required_processor"]
        constrained = _apply_filter(
            constrained,
            lambda p: needle in _clean_text(p.get("processor", "")).lower()
            or needle in _clean_text(p.get("name", "")).lower(),
        )

    if constraints["min_ram"]:
        constrained = _apply_filter(
            constrained,
            lambda p: _extract_number(p.get("ram", "")) >= constraints["min_ram"],
        )

    if constraints["min_storage"]:
        constrained = _apply_filter(
            constrained,
            lambda p: _extract_number(p.get("storage", "")) >= constraints["min_storage"],
        )

    return constrained


def _device_quality_score(product: dict) -> float:
    raw = product.get("device_score")
    if raw is None:
        raw = product.get("processor_score", product.get("laptop_score", 0.5))
    try:
        score = float(raw)
    except Exception:
        score = 0.5
    return max(0.0, min(score, 1.0))


def _has_any(query: str, words) -> bool:
    q = query.lower()
    return any(word in q for word in words)


def _battery_value(product: dict) -> int:
    return _extract_number(product.get("battery", ""))


def _ram_value(product: dict) -> int:
    return _extract_number(product.get("ram", ""))


def _storage_value(product: dict) -> int:
    return _extract_number(product.get("storage", ""))


def _processor_tier_score(processor: str, category: str) -> float:
    p = _clean_text(processor).lower()
    if not p:
        return 0.0

    if category == "phones":
        if any(x in p for x in FLAGSHIP_PHONE_HINTS):
            return 1.0
        if "snapdragon 7" in p or "dimensity 8" in p:
            return 0.65
        if "snapdragon 6" in p or "dimensity 7" in p or "helio" in p:
            return 0.35
        return 0.45

    if category == "laptops":
        if any(x in p for x in HIGH_END_LAPTOP_CPU_HINTS):
            return 1.0
        if "core i7" in p or "core ultra 7" in p or "ryzen 7" in p:
            return 0.7
        if "core i5" in p or "ryzen 5" in p:
            return 0.45
        return 0.3

    return 0.0


def _balanced_phone_score(product: dict) -> float:
    ram = _ram_value(product)
    storage = _storage_value(product)
    battery = _battery_value(product)

    ram_score = 1.0 if ram >= 12 else 0.75 if ram >= 8 else 0.45 if ram >= 6 else 0.2
    storage_score = 1.0 if storage >= 256 else 0.75 if storage >= 128 else 0.45 if storage >= 64 else 0.2
    battery_score = 1.0 if battery >= 6500 else 0.85 if battery >= 6000 else 0.7 if battery >= 5000 else 0.35 if battery >= 4000 else 0.15
    return (ram_score * 0.35) + (storage_score * 0.25) + (battery_score * 0.4)


def _balanced_laptop_score(product: dict) -> float:
    ram = _ram_value(product)
    storage = _storage_value(product)
    battery = _battery_value(product)

    ram_score = 1.0 if ram >= 16 else 0.8 if ram >= 8 else 0.5 if ram >= 6 else 0.2
    storage_score = 1.0 if storage >= 512 else 0.8 if storage >= 256 else 0.5 if storage >= 128 else 0.2
    battery_score = 1.0 if battery >= 7000 else 0.8 if battery >= 6000 else 0.6 if battery >= 5000 else 0.3 if battery >= 4000 else 0.15
    return (ram_score * 0.38) + (storage_score * 0.32) + (battery_score * 0.3)


def _gpu_tier_score(gpu: str) -> float:
    g = _clean_text(gpu).lower()
    if not g or g in ("unknown", "n/a", "na", "none"):
        return 0.0
    if any(x in g for x in HIGH_END_LAPTOP_GPU_HINTS):
        return 1.0
    if "rtx 30" in g or "gtx" in g:
        return 0.7
    if "radeon" in g or "iris" in g or "intel uhd" in g:
        return 0.35
    return 0.3


def _camera_signal_score(product: dict) -> float:
    camera_text = _clean_text(product.get("camera", "")).lower()
    if not camera_text:
        camera_text = _clean_text(product.get("name", "")).lower()
    mp_values = [int(v) for v in re.findall(r"(\d+)\s*mp", camera_text)]
    if not mp_values:
        if any(x in camera_text for x in ("ultra", "pro", "pixel", "iphone")):
            return 0.55
        return 0.0
    best = max(mp_values)
    if best >= 200:
        return 1.0
    if best >= 108:
        return 0.8
    if best >= 64:
        return 0.55
    return 0.3


def _intent_boost(query: str, product: dict) -> float:
    q = query.lower()
    category = _category_of(product)
    device_quality = _device_quality_score(product)
    boost = 0.0

    wants_phones = _query_has_any(q, PHONE_HINTS)
    wants_laptops = _query_has_any(q, LAPTOP_HINTS)
    if wants_phones and not wants_laptops:
        boost += 0.22 if category == "phones" else -0.18
    if wants_laptops and not wants_phones:
        boost += 0.22 if category == "laptops" else -0.18

    battery_intent = _has_any(q, BATTERY_HINTS)
    if battery_intent:
        battery = _battery_value(product)
        if category == "phones" and battery:
            boost += min(0.38, max(0.0, (battery - 3500) / 5500))
            boost += device_quality * 0.12
        elif category == "laptops" and battery:
            boost += min(0.2, max(0.0, (battery - 4000) / 5000))

    camera_intent = "camera" in q
    if camera_intent and category == "phones":
        boost += _camera_signal_score(product) * 0.28

    gaming_intent = _has_any(q, GAMING_HINTS)
    processor_intent = any(k in q for k in ("processor", "chipset", "cpu", "flagship", "snapdragon", "core i7", "core i9", "ryzen"))
    if processor_intent:
        boost += _processor_tier_score(product.get("processor"), category) * 0.22

    gpu_intent = any(k in q for k in ("gpu", "graphics", "rtx"))
    if gaming_intent:
        if category == "phones":
            boost += _processor_tier_score(product.get("processor"), category) * 0.28
            boost += device_quality * 0.20
            boost += _balanced_phone_score(product) * 0.12
        elif category == "laptops":
            boost += _processor_tier_score(product.get("processor"), category) * 0.18
            boost += _gpu_tier_score(product.get("gpu")) * 0.30
            boost += device_quality * 0.15

    if gpu_intent and category == "laptops":
        boost += _gpu_tier_score(product.get("gpu")) * 0.24

    social_intent = _has_any(q, SOCIAL_HINTS)
    if social_intent and category == "phones":
        boost += _balanced_phone_score(product) * 0.22
        boost += device_quality * 0.15

    study_intent = _has_any(q, STUDY_HINTS)
    if study_intent:
        if category == "phones":
            boost += _balanced_phone_score(product) * 0.18
            boost += device_quality * 0.10
        elif category == "laptops":
            boost += _balanced_laptop_score(product) * 0.20
            boost += device_quality * 0.12

    general_intent = _has_any(q, GENERAL_HINTS)
    if general_intent:
        if category == "phones":
            boost += _balanced_phone_score(product) * 0.20
            boost += device_quality * 0.10
        elif category == "laptops":
            boost += _balanced_laptop_score(product) * 0.18
            boost += device_quality * 0.10

    office_intent = any(k in q for k in ("office", "lightweight", "portable", "coding"))
    if office_intent and category == "laptops":
        gpu = _clean_text(product.get("gpu", "")).lower()
        price = _price_to_float(product.get("price"))
        if "rtx" in gpu:
            boost -= 0.15
        if 0 < price <= 250000:
            boost += 0.12

    budget_intent = any(k in q for k in BUDGET_HINTS) or any(k in q for k in ("under", "below", "less than", "upto", "up to", "within"))
    if budget_intent:
        price = _price_to_float(product.get("price"))
        if price > 0:
            if price <= DEFAULT_BUDGET_PHONE_MAX:
                boost += 0.18
            elif price <= 50000:
                boost += 0.14
            elif price <= 80000:
                boost += 0.08
            elif price <= 120000:
                boost += 0.0
            elif price <= 180000:
                boost -= 0.18
            else:
                boost -= 0.35

    daily_use_intent = _has_any(q, GENERAL_HINTS)
    if daily_use_intent and category == "phones":
        price = _price_to_float(product.get("price"))
        if 0 < price <= 50000:
            boost += 0.12
        elif 50000 < price <= 90000:
            boost += 0.08
        elif price > 150000:
            boost -= 0.2

    constraints = _parse_query_constraints(query)
    if constraints["budget_max"] is not None:
        price = _price_to_float(product.get("price"))
        if 0 < price <= constraints["budget_max"]:
            boost += 0.2
        elif price > constraints["budget_max"]:
            boost -= 0.35

    return boost


def _normalize_output_product(product: dict) -> dict:
    item = product.copy()
    item["name"] = _clean_text(item.get("normalized_name") or item.get("name", ""))
    item["processor"] = _clean_text(item.get("processor", ""))
    item["gpu"] = _clean_text(item.get("gpu", ""))
    item["battery"] = _clean_text(item.get("battery", ""))
    item["image_url"] = (
        item.get("image_url")
        or item.get("image")
        or item.get("imageLink")
        or item.get("image_link")
        or ""
    )
    return item


def _sigmoid(value: float) -> float:
    return float(1.0 / (1.0 + np.exp(-2.2 * value)))


def _embedding_cache_key(product: dict, product_text: str) -> str:
    product_identity = (
        str(product.get("id") or product.get("product_id") or product.get("url") or product.get("name") or "")
        .strip()
        .lower()
    )
    signature = hashlib.sha1(product_text.encode("utf-8", errors="ignore")).hexdigest()
    return f"{product_identity}:{signature}"


def _get_product_embeddings(model, products: list, product_texts: list) -> np.ndarray:
    cached_embeddings = {}
    missing_indices = []
    missing_texts = []

    with _EMBEDDING_CACHE_LOCK:
        for index, (product, product_text) in enumerate(zip(products, product_texts)):
            cache_key = _embedding_cache_key(product, product_text)
            embedding = _EMBEDDING_CACHE.get(cache_key)
            if embedding is None:
                missing_indices.append(index)
                missing_texts.append(product_text)
            else:
                cached_embeddings[index] = embedding

    if missing_texts:
        fresh_embeddings = model.encode(missing_texts)
        with _EMBEDDING_CACHE_LOCK:
            for index, product_text, embedding in zip(missing_indices, missing_texts, fresh_embeddings):
                cache_key = _embedding_cache_key(products[index], product_text)
                _EMBEDDING_CACHE[cache_key] = embedding
                cached_embeddings[index] = embedding

    return np.vstack([cached_embeddings[index] for index in range(len(products))])


def recommend_products(query: str, products: list, top_n: int = 10):
    """
    Returns top N products based on semantic similarity.
    """
    if not products:
        return []

    constrained_products = _apply_hard_constraints(query, products)
    if len(constrained_products) > 80:
        candidate_limit = min(len(constrained_products), max(80, top_n * 10))
        heuristic_ranked = sorted(
            ((product, _intent_boost(query, product)) for product in constrained_products),
            key=lambda item: item[1],
            reverse=True,
        )
        constrained_products = [product for product, _ in heuristic_ranked[:candidate_limit]]

    model = get_model()

    product_texts = [product_to_text(p) for p in constrained_products]

    query_embedding = model.encode([query])
    product_embeddings = _get_product_embeddings(model, constrained_products, product_texts)

    similarities = np.matmul(query_embedding, product_embeddings.T)[0]

    scored = []
    for product, semantic_score in zip(constrained_products, similarities):
        device_quality = _device_quality_score(product)
        boost = _intent_boost(query, product)
        quality_alignment = (device_quality - 0.5) * 0.55
        raw_score = float(semantic_score) * 0.7 + quality_alignment + boost
        scored.append((product, float(semantic_score), boost, raw_score))

    ranked = sorted(scored, key=lambda x: x[3], reverse=True)

    top_results = []
    for product, semantic_score, boost, raw_score in ranked[:top_n]:
        product_copy = _normalize_output_product(product)
        product_copy["semantic_score"] = round(_sigmoid(float(semantic_score)), 4)
        product_copy["boosted_score"] = round(float(boost), 4)
        product_copy["similarity_score"] = round(_sigmoid(float(raw_score)), 4)
        top_results.append(product_copy)

    return top_results