import numpy as np
import re
import hashlib
from difflib import SequenceMatcher
from threading import RLock

from .model import get_model
from .text_builder import product_to_text
from .processor_engine import (
    infer_score_from_gpu,
    laptop_cpu_performance,
    phone_chipset_performance,
    score_product,
)
from .query_language import normalize_user_query


PHONE_HINTS = (
    "phone", "phones", "mobile", "mobiles", "smartphone", "iphone",
    "galaxy", "pixel", "redmi", "poco",
)
LAPTOP_HINTS = ("laptop", "laptops", "notebook", "ultrabook", "macbook")

GAMING_HINTS = (
    "gaming",
    "game",
    "games",
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

BASIC_LAPTOP_USE_HINTS = (
    "work",
    "office work",
    "study",
    "student",
    "school",
    "college",
    "university",
    "assignments",
    "documents",
    "browsing",
    "email",
    "typing",
    "meetings",
    "video calls",
    "spreadsheets",
    "presentations",
    "coding",
    "programming",
    "business",
    "research",
    "online class",
    "online classes",
    "classes",
    "zoom",
    "basic use",
    "daily use",
    "general use",
)

BASIC_PHONE_USE_HINTS = (
    "work",
    "study",
    "student",
    "school",
    "college",
    "university",
    "daily use",
    "everyday",
    "general use",
    "basic use",
    "calls",
    "calling",
    "whatsapp",
    "messaging",
    "email",
    "browsing",
    "assignments",
    "notes",
    "online class",
    "online classes",
    "classes",
    "video calls",
    "meetings",
    "business",
    "navigation",
    "streaming",
    "netflix",
    "social media",
    "instagram",
    "facebook",
    "tiktok",
)

SENIOR_PHONE_HINTS = (
    "senior",
    "elderly",
    "senior citizen",
    "older person",
    "easy to use",
)

HIGH_PERFORMANCE_HINTS = (
    "gaming",
    "rendering",
    "3d",
    "video editing",
    "machine learning",
    "deep learning",
    "data science",
    "autocad",
    "cad",
    "rtx",
    "powerful",
    "performance",
    "workstation",
)

BUDGET_HINTS = (
    "cheap",
    "cheaper",
    "cheapest",
    "budget",
    "affordable",
    "low budget",
    "budget friendly",
    "value for money",
)

FLAGSHIP_PHONE_HINTS = (
    "snapdragon 8",
    "snapdragon 8 elite",
    "snapdragon 8 gen 4",
    "dimensity 9300",
    "dimensity 9200",
    "dimensity 9400",
    "a18",
    "a17",
    "a16",
    "exynos 2400",
)

HIGH_END_LAPTOP_CPU_HINTS = (
    "core i9",
    "core ultra 9",
    "ryzen 9",
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
    raw = str(price or "").lower().replace(",", "").strip()
    match = re.search(r"(\d+(?:\.\d+)?)\s*(crore|lakhs?|lacs?|laac|lak|million|m|k|thousands?|hazar|hazaar)?", raw)
    if not match:
        return 0.0
    value = float(match.group(1))
    unit = match.group(2) or ""
    if unit in ("k", "thousand", "thousands", "hazar", "hazaar"):
        value *= 1_000
    elif unit in ("m", "million"):
        value *= 1_000_000
    elif unit in ("lakh", "lakhs", "lac", "lacs", "laac", "lak"):
        value *= 100_000
    elif unit == "crore":
        value *= 10_000_000
    return value


def _format_price_pkr(price) -> str:
    """Return a consistent display price while keeping invalid values untouched."""
    value = _price_to_float(price)
    if value <= 0:
        return str(price or "").strip()
    if value.is_integer():
        return f"PKR {value:,.0f}"
    return f"PKR {value:,.2f}".rstrip("0").rstrip(".")


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


_MONEY_TOKEN = r"(?:rs\.?|pkr)?\s*\d[\d,]*(?:\.\d+)?\s*(?:crore|lakhs?|lacs?|laac|lak|million|m|k|thousands?|hazar|hazaar)?"


def _money_value(token: str, inherited_unit: str = "") -> float:
    value = _price_to_float(token)
    if value <= 0:
        return 0.0
    if inherited_unit and not re.search(r"(?:crore|lakhs?|lacs?|laac|lak|million|m|k|thousands?|hazar|hazaar)\s*$", token.strip(), re.IGNORECASE):
        return _price_to_float(f"{token}{inherited_unit}")
    return value


def _extract_price_constraints(query: str):
    """Return explicit minimum/maximum prices without inventing a category budget."""
    q = " ".join(str(query or "").lower().split())

    range_match = re.search(
        rf"(?:between|from)\s+({_MONEY_TOKEN})\s*(?:and|to|-)\s*({_MONEY_TOKEN})",
        q,
    )
    if range_match:
        high_token = range_match.group(2)
        unit_match = re.search(r"(crore|lakhs?|lacs?|laac|lak|million|m|k|thousands?|hazar|hazaar)\s*$", high_token)
        inherited_unit = unit_match.group(1) if unit_match else ""
        first = _money_value(range_match.group(1), inherited_unit)
        second = _money_value(high_token)
        if first > 0 and second > 0:
            return min(first, second), max(first, second)

    max_match = re.search(
        rf"(?:under|below|less than|not more than|up to|upto|within|in|for|max(?:imum)?(?: budget)?(?: of| is|:)?|budget(?: of| is|:)?)\s*({_MONEY_TOKEN})",
        q,
    )
    if not max_match:
        max_match = re.search(rf"({_MONEY_TOKEN})\s+(?:or less|max(?:imum)?|budget)\b", q)

    min_match = re.search(
        rf"(?:above|over|more than|at least|minimum(?: budget)?(?: of| is|:)?)\s*({_MONEY_TOKEN})",
        q,
    )

    minimum = _money_value(min_match.group(1)) if min_match else None
    maximum = _money_value(max_match.group(1)) if max_match else None
    return minimum or None, maximum or None


def _extract_budget(query: str):
    """Backward-compatible helper returning an explicitly stated maximum budget."""
    return _extract_price_constraints(query)[1]


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

    storage_match = re.search(r"(\d+(?:\.\d+)?)\s*(gb|tb)\s*(?:storage|rom|ssd)", q)
    if storage_match:
        storage = int(float(storage_match.group(1)) * (1024 if storage_match.group(2) == "tb" else 1))
    else:
        all_gb = [int(n) for n in re.findall(r"(\d+)\s*gb", q)]
        if len(all_gb) >= 2:
            storage = max(all_gb)
            if ram is None:
                ram = min(all_gb)

    return ram, storage


def _product_feature_text(product: dict) -> str:
    """Return normalized searchable catalog facts, including nested specs."""
    values = []
    for key in (
        "name", "normalized_name", "description", "display", "screen",
        "network", "connectivity", "charging", "os", "operating_system",
        "features", "keyboard", "ports", "fingerprint", "camera",
    ):
        value = product.get(key)
        if value:
            values.append(str(value))
    specs = product.get("specs")
    if isinstance(specs, dict):
        for key, value in specs.items():
            values.extend((str(key), str(value)))
    return _clean_text(" ".join(values)).lower().replace("‑", "-")


def _extract_required_features(query: str) -> tuple[str, ...]:
    q = query.lower()
    features = []
    simple_features = (
        "5g", "4g", "amoled", "oled", "nfc", "wifi 6", "wi-fi 6",
        "thunderbolt", "backlit keyboard", "fingerprint",
    )
    for feature in simple_features:
        if re.search(rf"\b{re.escape(feature)}\b", q):
            features.append(feature)
    refresh_rate = re.search(r"\b(60|90|120|144|165|240)\s*hz\b", q)
    if refresh_rate:
        features.append(f"{refresh_rate.group(1)}hz")
    charging = re.search(r"\b(\d{2,3})\s*w(?:att)?\s*(?:fast\s*)?charg", q)
    if charging:
        features.append(f"{charging.group(1)}w charging")
    return tuple(dict.fromkeys(features))


def _matches_required_feature(product: dict, feature: str) -> bool:
    text = _product_feature_text(product)
    compact = re.sub(r"\s+", "", text)
    if feature in ("wifi 6", "wi-fi 6"):
        return bool(re.search(r"\bwi-?fi\s*6\b|\bwifi\s*6\b", text))
    if feature.endswith("hz"):
        return feature in compact
    if feature.endswith("w charging"):
        watts = feature.split("w", 1)[0]
        return bool(re.search(rf"\b{re.escape(watts)}\s*w(?:att)?\b", text))
    if feature == "oled":
        return "oled" in text  # AMOLED is also an OLED display.
    return bool(re.search(rf"\b{re.escape(feature)}\b", text))


def _capacity_gb(value) -> int:
    text = _clean_text(value).lower()
    match = re.search(r"(\d+(?:\.\d+)?)\s*(tb|gb)?", text)
    if not match:
        return 0
    amount = float(match.group(1))
    if match.group(2) == "tb":
        amount *= 1024
    return int(amount)


def _parse_query_constraints(query: str):
    q = query.lower()
    budget_min, budget_max = _extract_price_constraints(q)
    required_gpu = _extract_required_gpu(q)
    required_processor = _extract_required_processor(q)
    min_ram, min_storage = _extract_ram_storage_constraints(q)
    required_features = _extract_required_features(q)

    query_category = "unknown"
    if _query_has_any(q, PHONE_HINTS) and not _query_has_any(q, LAPTOP_HINTS):
        query_category = "phones"
    elif _query_has_any(q, LAPTOP_HINTS) and not _query_has_any(q, PHONE_HINTS):
        query_category = "laptops"

    return {
        "budget_min": budget_min,
        "budget_max": budget_max,
        "required_gpu": required_gpu,
        "required_processor": required_processor,
        "min_ram": min_ram,
        "min_storage": min_storage,
        "required_features": required_features,
        "query_category": query_category,
    }


_BRAND_FUZZY_STOPWORDS = {
    "phone", "phones", "mobile", "mobiles", "smartphone", "laptop", "laptops",
    "notebook", "under", "below", "budget", "best", "good", "cheap", "want",
    "show", "with", "without", "basic", "student", "gaming", "camera", "battery",
    "social", "media", "calling", "daily", "office", "work", "study", "thousand",
    "lakh", "price", "range", "recommend", "available",
}

_PRODUCT_FAMILY_BRANDS = {
    "iphone": "apple",
    "macbook": "apple",
    "galaxy": "samsung",
    "pixel": "google",
    "redmi": "xiaomi",
    "poco": "xiaomi",
}


def _extract_requested_brands(query: str, products: list) -> set[str]:
    """Resolve explicit and conservatively misspelled brands from this catalog.

    Catalog-derived matching keeps this generic when new brands are added. A
    fuzzy match is accepted only when it is strong and clearly better than the
    next brand, preventing ordinary requirement words from becoming brands.
    """
    q = _clean_text(query).lower()
    brands = sorted({
        _clean_text(product.get("brand", "")).lower()
        for product in products
        if _clean_text(product.get("brand", "")).lower() not in ("", "unknown", "n/a")
    })
    family_brands = {
        brand for family, brand in _PRODUCT_FAMILY_BRANDS.items()
        if brand in brands and re.search(rf"\b{re.escape(family)}\b", q)
    }
    if family_brands:
        return family_brands
    exact = {brand for brand in brands if re.search(rf"\b{re.escape(brand)}\b", q)}
    if exact:
        return exact

    query_tokens = {
        token for token in re.findall(r"[a-z][a-z0-9-]*", q)
        if len(token) >= 3 and token not in _BRAND_FUZZY_STOPWORDS
    }
    fuzzy = set()
    for token in query_tokens:
        candidates = []
        for brand in brands:
            compact_brand = re.sub(r"[^a-z0-9]", "", brand)
            if len(compact_brand) < 3 or abs(len(token) - len(compact_brand)) > 2:
                continue
            score = SequenceMatcher(None, token, compact_brand).ratio()
            threshold = 0.86 if min(len(token), len(compact_brand)) == 3 else 0.78
            if score >= threshold:
                candidates.append((score, brand))
        candidates.sort(reverse=True)
        if candidates and (len(candidates) == 1 or candidates[0][0] - candidates[1][0] >= 0.08):
            fuzzy.add(candidates[0][1])
    return fuzzy


def _apply_hard_constraints(query: str, products: list) -> list:
    constraints = _parse_query_constraints(query)
    constrained = list(products)

    if constraints["query_category"] != "unknown":
        constrained = [p for p in constrained if _category_of(p) == constraints["query_category"]]

    requested_brands = _extract_requested_brands(query, products)
    if requested_brands:
        constrained = [
            p for p in constrained
            if _clean_text(p.get("brand", "")).lower() in requested_brands
        ]

    if constraints["budget_min"] is not None:
        constrained = [
            p for p in constrained
            if _price_to_float(p.get("price")) >= constraints["budget_min"]
        ]

    if constraints["budget_max"] is not None:
        constrained = [
            p for p in constrained
            if 0 < _price_to_float(p.get("price")) <= constraints["budget_max"]
        ]

    if constraints["required_gpu"]:
        needle = constraints["required_gpu"]
        constrained = [
            p for p in constrained
            if needle in _clean_text(p.get("gpu", "")).lower().replace(" ", "")
            or needle in _clean_text(p.get("name", "")).lower().replace(" ", "")
        ]

    if constraints["required_processor"]:
        needle = constraints["required_processor"]
        constrained = [
            p for p in constrained
            if needle in _clean_text(p.get("processor", "")).lower()
            or needle in _clean_text(p.get("name", "")).lower()
        ]

    if constraints["min_ram"]:
        constrained = [
            p for p in constrained
            if _memory_values(p)[0] >= constraints["min_ram"]
        ]

    if constraints["min_storage"]:
        constrained = [
            p for p in constrained
            if _memory_values(p)[1] >= constraints["min_storage"]
        ]

    for feature in constraints["required_features"]:
        constrained = [
            product for product in constrained
            if _matches_required_feature(product, feature)
        ]

    return constrained


def _device_quality_score(product: dict) -> float:
    # Recalculate from current specs. Persisted scores may have been produced by
    # an older chipset table and were the source of several inverted rankings.
    calculated = score_product(product).get("score")
    raw = calculated
    if raw is None:
        raw = product.get("device_score", product.get("processor_score", product.get("laptop_score", 0.5)))
    try:
        score = float(raw)
    except Exception:
        score = 0.5
    return max(0.0, min(score, 1.0))


def _has_any(query: str, words) -> bool:
    q = query.lower()
    # Letter-aware boundaries still recognize values such as "5000mAh", but
    # prevent short intents such as "cod" from matching unrelated "coding".
    return any(
        re.search(rf"(?<![a-z]){re.escape(word)}(?![a-z])", q)
        for word in words
    )


def _term_is_negated(query: str, start: int, end: int | None = None) -> bool:
    """Detect common negation close to an intent term."""
    prefix = query[max(0, start - 70):start].lower()
    prefix_negated = bool(
        re.search(
            r"(?:\b(?:no|not|never|without|dont|don't|do\s+not|hardly)\b)"
            r"(?:[^.!?,;]*\b\w+\b){0,10}[^.!?,;]*$",
            prefix,
        )
    )
    if prefix_negated:
        return True
    suffix = query[end if end is not None else start:start + 35].lower()
    return bool(
        re.match(
            r"^\s*(?:(?:is|was|should\s+be)\s+)?"
            r"(?:\b(?:no|not|never|without|dont|don't|do\s+not)\b)",
            suffix,
        )
    )


def _has_positive_any(query: str, words) -> bool:
    """Return True when an intent appears outside nearby negation."""
    q = query.lower()
    for word in words:
        pattern = rf"(?<![a-z]){re.escape(word)}(?![a-z])"
        if any(
            not _term_is_negated(q, match.start(), match.end())
            for match in re.finditer(pattern, q)
        ):
            return True
    return False


def _workload_level(query: str) -> str | None:
    """Map free-form needs onto capability levels instead of query templates."""
    q = query.lower()
    if _has_positive_any(q, HIGH_PERFORMANCE_HINTS):
        return "high"

    light_language = bool(
        re.search(
            r"\b(?:basic\w*|simple|minimal|light\s+(?:use|tasks?|work)|"
            r"nothing\s+heavy|casual|just\s+need|only\s+need)\b",
            q,
        )
    )
    negative_workload = bool(
        re.search(
            r"\b(?:dont|don't|do\s+not|not)\b[^.!?,;]{0,55}"
            r"\b(?:much|lot|heavy|demanding|intensive|work|tasks?)\b",
            q,
        )
    )
    medium_terms = (
        "office",
        "coding",
        "programming",
        "professional",
        "business",
        "development",
        "multitasking",
    )
    medium_work = _has_positive_any(q, medium_terms)
    study = _has_positive_any(q, STUDY_HINTS)
    routine_tasks = _has_positive_any(
        q,
        (
            "browsing",
            "email",
            "typing",
            "documents",
            "assignments",
            "presentations",
            "online class",
            "classes",
            "zoom",
        ),
    )

    if light_language or negative_workload or ((study or routine_tasks) and not medium_work):
        return "light"
    if medium_work or _has_positive_any(q, ("work", "meetings", "documents")):
        return "standard"
    return None


def _battery_value(product: dict) -> int:
    return _extract_number(product.get("battery", ""))


def _ram_value(product: dict) -> int:
    return _memory_values(product)[0]


def _storage_value(product: dict) -> int:
    return _memory_values(product)[1]


def _memory_values(product: dict) -> tuple[int, int]:
    """Read RAM/storage and repair a common scraper field swap in memory."""
    raw_ram = _clean_text(product.get("ram", "")).lower()
    raw_storage = _clean_text(product.get("storage", "")).lower()
    ram = _capacity_gb(raw_ram)
    storage = _capacity_gb(raw_storage)
    if ("tb" in raw_ram or ram > 64) and 0 < storage <= 64:
        return storage, ram
    return ram, storage


def _processor_tier_score(processor: str, category: str) -> float:
    p = _clean_text(processor).lower()
    if not p:
        return 0.0

    if category == "phones":
        return phone_chipset_performance({"processor": processor, "category": "Phones"})

    if category == "laptops":
        return laptop_cpu_performance({"processor": processor, "category": "Laptops"})

    return 0.0


def _product_processor_score(product: dict) -> float:
    category = _category_of(product)
    if category == "phones":
        return phone_chipset_performance(product)
    if category == "laptops":
        return laptop_cpu_performance(product)
    return 0.0


def _product_processor_score(product: dict) -> float:
    category = _category_of(product)
    if category == "phones":
        return phone_chipset_performance(product)
    if category == "laptops":
        return laptop_cpu_performance(product)
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
    g = re.sub(r"[^a-z0-9]+", " ", _clean_text(gpu).lower()).strip()
    if not g or g in ("unknown", "n/a", "na", "none"):
        return 0.0
    tiers = (
        ("rtx 5090", 1.00), ("rtx 5080", 0.98), ("rtx 4090", 0.96),
        ("rtx 5070 ti", 0.93), ("rtx 4080", 0.91), ("rtx 5070", 0.88),
        ("rtx 5060", 0.83), ("rtx 4070", 0.81), ("rtx 4060", 0.75),
        ("rtx 4050", 0.66), ("rtx 3090", 0.76), ("rtx 3080", 0.72),
        ("rtx 3070", 0.65), ("rtx 3060", 0.58), ("rtx 3050", 0.50),
    )
    for model, score in tiers:
        if model in g:
            return score
    if "rtx 30" in g or "gtx" in g:
        return 0.45
    if "radeon" in g or "iris" in g or "intel uhd" in g:
        return 0.35
    return 0.3


def _camera_signal_score(product: dict) -> float:
    camera_text = _clean_text(product.get("camera", "")).lower()
    name = _clean_text(product.get("name", "")).lower()
    if not camera_text:
        if "ultra" in name:
            return 0.90
        if "pro max" in name or "pixel" in name:
            return 0.85
        if "pro" in name:
            return 0.72
        if "iphone" in name:
            return 0.70
        return 0.25
    mp_values = [int(v) for v in re.findall(r"(\d+)\s*mp", camera_text)]
    if not mp_values:
        if any(x in camera_text for x in ("ultra", "pro", "pixel", "iphone")):
            return 0.55
        return 0.0
    best = max(mp_values)
    if best >= 200:
        megapixel_score = 0.55
    elif best >= 108:
        megapixel_score = 0.52
    elif best >= 64:
        megapixel_score = 0.48
    else:
        megapixel_score = 0.35

    # Camera hardware and image-processing signals matter more than a large MP
    # number on its own. These bonuses only use explicit catalog facts.
    feature_bonus = 0.0
    if re.search(r"\bois\b|optical image stabil", camera_text):
        feature_bonus += 0.22
    if re.search(r"telephoto|optical zoom|periscope", camera_text):
        feature_bonus += 0.18
    if re.search(r"flagship camera|large sensor|leica|hasselblad", camera_text):
        feature_bonus += 0.15
    if "pixel" in name or "iphone" in name or "ultra" in name or "pro max" in name:
        feature_bonus += 0.12
    return min(megapixel_score + feature_bonus, 1.0)


def _phone_gaming_score(product: dict) -> float:
    chipset = phone_chipset_performance(product)
    gpu = infer_score_from_gpu(product.get("gpu", ""))
    ram_score = min(_ram_value(product) / 12.0, 1.0) if _ram_value(product) else 0.35
    storage_score = min(_storage_value(product) / 512.0, 1.0) if _storage_value(product) else 0.35
    battery = _battery_value(product)
    battery_score = min(battery / 6500.0, 1.0) if battery else 0.4
    name = _clean_text(product.get("name", "")).lower()
    gaming_design = 1.0 if any(token in name for token in ("rog", "redmagic", "red magic", "legion", "gt ")) else 0.0
    return (
        chipset * 0.72
        + gpu * 0.10
        + ram_score * 0.08
        + storage_score * 0.04
        + battery_score * 0.04
        + gaming_design * 0.02
    )


def _laptop_gaming_score(product: dict) -> float:
    return (
        _gpu_tier_score(product.get("gpu")) * 0.72
        + laptop_cpu_performance(product) * 0.15
        + min(_ram_value(product) / 32.0, 1.0) * 0.08
        + min(_storage_value(product) / 1024.0, 1.0) * 0.05
    )


def _is_basic_laptop_use_query(query: str) -> bool:
    q = query.lower()
    wants_phone = _query_has_any(q, PHONE_HINTS)
    return _workload_level(q) == "light" and not wants_phone


def _basic_laptop_value_score(product: dict) -> float:
    """Prefer adequate, affordable laptops over unnecessary premium hardware."""
    if _category_of(product) != "laptops":
        return 0.0

    price = _price_to_float(product.get("price"))
    if price <= 0:
        return 0.0

    ram = _ram_value(product)
    storage = _storage_value(product)
    processor = laptop_cpu_performance(product)
    ram_score = 1.0 if 8 <= ram <= 24 else 0.85 if ram > 24 else 0.35 if ram >= 4 else 0.1
    storage_score = 1.0 if 256 <= storage <= 1024 else 0.85 if storage > 1024 else 0.3
    processor_score = min(processor / 0.55, 1.0)
    capability = ram_score * 0.35 + storage_score * 0.30 + processor_score * 0.35

    if price <= 125_000:
        affordability = 1.0
    elif price <= 150_000:
        affordability = 0.92
    elif price <= 175_000:
        affordability = 0.82
    elif price <= 225_000:
        affordability = 0.65
    elif price <= 300_000:
        affordability = 0.40
    elif price <= 500_000:
        affordability = 0.15
    else:
        affordability = 0.0

    gpu = _clean_text(product.get("gpu", "")).lower()
    unnecessary_gpu_penalty = 0.15 if re.search(r"\b(?:rtx|gtx)\s*\d", gpu) else 0.0
    premium_price_penalty = 0.30 if price > 500_000 else 0.12 if price > 300_000 else 0.0
    return max(
        0.0,
        capability * 0.60
        + affordability * 0.40
        - unnecessary_gpu_penalty
        - premium_price_penalty,
    )


def _is_basic_phone_use_query(query: str) -> bool:
    q = query.lower()
    wants_phone = _query_has_any(q, PHONE_HINTS)
    basic_use = any(
        _query_has_any(q, hints)
        for hints in (BASIC_PHONE_USE_HINTS, STUDY_HINTS, GENERAL_HINTS, SOCIAL_HINTS)
    )
    high_performance = _has_positive_any(q, HIGH_PERFORMANCE_HINTS) or "camera" in q
    return wants_phone and basic_use and not high_performance


def _basic_phone_value_score(product: dict) -> float:
    """Rank affordable phones that comfortably cover everyday tasks."""
    if _category_of(product) != "phones":
        return 0.0

    price = _price_to_float(product.get("price"))
    if price <= 0:
        return 0.0

    ram = _ram_value(product)
    storage = _storage_value(product)
    battery = _battery_value(product)
    processor = phone_chipset_performance(product)
    ram_score = 1.0 if 6 <= ram <= 12 else 0.85 if ram > 12 else 0.55 if ram >= 4 else 0.2
    storage_score = 1.0 if 128 <= storage <= 512 else 0.85 if storage > 512 else 0.55 if storage >= 64 else 0.2
    battery_score = 1.0 if battery >= 5000 else 0.75 if battery >= 4000 else 0.4
    processor_score = min(processor / 0.65, 1.0)
    capability = (
        ram_score * 0.25
        + storage_score * 0.25
        + battery_score * 0.25
        + processor_score * 0.25
    )

    if price <= 30_000:
        affordability = 1.0
    elif price <= 50_000:
        affordability = 0.95
    elif price <= 80_000:
        affordability = 0.85
    elif price <= 120_000:
        affordability = 0.65
    elif price <= 160_000:
        affordability = 0.45
    elif price <= 220_000:
        affordability = 0.20
    else:
        affordability = 0.0

    premium_price_penalty = 0.20 if price > 220_000 else 0.0
    return max(0.0, capability * 0.60 + affordability * 0.40 - premium_price_penalty)


def _is_senior_phone_query(query: str) -> bool:
    q = query.lower()
    return (
        _query_has_any(q, PHONE_HINTS)
        and _query_has_any(q, SENIOR_PHONE_HINTS)
        and not _query_has_any(q, HIGH_PERFORMANCE_HINTS)
    )


def _is_office_laptop_query(query: str) -> bool:
    q = query.lower()
    return (
        _query_has_any(q, LAPTOP_HINTS)
        and _has_positive_any(q, ("office", "coding", "programming", "business", "meetings", "work"))
        and _workload_level(q) != "light"
        and not _has_positive_any(q, HIGH_PERFORMANCE_HINTS)
    )


def _office_laptop_score(product: dict) -> float:
    """Prefer capable, portable office laptops without drifting to gaming rigs."""
    if _category_of(product) != "laptops":
        return 0.0
    price = _price_to_float(product.get("price"))
    ram = _ram_value(product)
    storage = _storage_value(product)
    processor = laptop_cpu_performance(product)
    gpu = _clean_text(product.get("gpu", "")).lower()
    if price <= 0:
        return 0.0
    ram_score = min(ram / 16.0, 1.0) if ram else 0.25
    storage_score = min(storage / 512.0, 1.0) if storage else 0.25
    value = 1.0 if price <= 150_000 else 0.75 if price <= 220_000 else 0.35 if price <= 300_000 else 0.0
    score = processor * 0.45 + ram_score * 0.25 + storage_score * 0.15 + value * 0.15
    if re.search(r"\b(?:rtx|gtx)\s*\d", gpu):
        score -= 0.18
    if price > 300_000:
        score -= 0.15
    return max(0.0, score)


def _display_size_inches(product: dict) -> float:
    specs = product.get("specs") if isinstance(product.get("specs"), dict) else {}
    display = _clean_text(
        product.get("display") or product.get("screen") or specs.get("display") or specs.get("screen")
    ).lower()
    match = re.search(r"(\d(?:\.\d+)?)\s*(?:inch|inches|\")", display)
    return float(match.group(1)) if match else 0.0


def _senior_phone_score(product: dict) -> float:
    """Rank practical, readable, dependable phones for older users.

    The catalog does not consistently contain accessibility metadata, so the
    score uses only defensible proxies: adequate memory/performance, battery,
    screen size when known, and value. It avoids both underpowered devices and
    expensive flagships that add little for calls and social media.
    """
    if _category_of(product) != "phones":
        return 0.0
    price = _price_to_float(product.get("price"))
    if price <= 0:
        return 0.0

    ram, storage = _memory_values(product)
    battery = _battery_value(product)
    chipset = phone_chipset_performance(product)
    display_size = _display_size_inches(product)

    memory = (
        (1.0 if 4 <= ram <= 12 else 0.85 if ram > 12 else 0.25)
        + (1.0 if 64 <= storage <= 512 else 0.85 if storage > 512 else 0.30)
    ) / 2
    battery_score = 1.0 if battery >= 5000 else 0.78 if battery >= 4000 else 0.35
    performance = min(chipset / 0.55, 1.0) if chipset else 0.35
    readability = (
        1.0
        if display_size >= 6.5
        else 0.82
        if display_size >= 6.1
        else 0.65
        if display_size
        else 0.70
    )

    if price <= 30_000:
        value = 1.0
    elif price <= 50_000:
        value = 0.95
    elif price <= 80_000:
        value = 0.80
    elif price <= 120_000:
        value = 0.55
    elif price <= 180_000:
        value = 0.25
    else:
        value = 0.0

    score = (
        battery_score * 0.28
        + memory * 0.23
        + performance * 0.18
        + readability * 0.13
        + value * 0.18
    )
    if ram and ram < 4:
        score -= 0.18
    if battery and battery < 4000:
        score -= 0.15
    if price > 180_000:
        score -= 0.15
    return max(0.0, score)


def _iphone_model_score(product: dict) -> float:
    """Rank iPhone generations and tiers when the user explicitly asks for top/latest."""
    name = _clean_text(product.get("name", "")).lower()
    match = re.search(r"\biphone\s*(\d{1,2})(?:e\b|\b)", name)
    generation = int(match.group(1)) if match else 0
    tier = (
        1.0 if "pro max" in name
        else 0.92 if re.search(r"\bpro\b", name)
        else 0.82 if re.search(r"\bplus\b", name)
        else 0.78 if re.search(r"\bair\b", name)
        else 0.62 if re.search(r"\biphone\s*\d+e\b", name)
        else 0.50 if re.search(r"\bse\b", name)
        else 0.75
    )
    generation_score = min(generation / 20.0, 1.0) if generation else 0.35
    return generation_score * 0.72 + tier * 0.28


def _is_macbook_work_query(query: str) -> bool:
    q = query.lower()
    return "macbook" in q and _has_positive_any(
        q,
        ("coding", "programming", "development", "developer", "editing", "video editing", "photo editing", "rendering"),
    )


def _macbook_work_score(query: str, product: dict) -> float:
    """Rank MacBooks by editing capability or practical coding value."""
    q = query.lower()
    text = _product_feature_text(product)
    name = _clean_text(product.get("name", "")).lower()
    chip_match = re.search(r"\bm\s*([1-9])\s*(ultra|pro|max)?\b", text)
    if chip_match:
        generation = int(chip_match.group(1))
        family = chip_match.group(2) or "base"
        generation_score = min(generation / 4.0, 1.0)
        family_bonus = {"base": 0.0, "pro": 0.15, "max": 0.23, "ultra": 0.28}[family]
        chip_score = min(generation_score * 0.82 + family_bonus, 1.0)
    else:
        chip_score = 0.28 if "intel" in text else _device_quality_score(product)

    ram = _ram_value(product)
    storage = _storage_value(product)
    ram_score = min(ram / 24.0, 1.0) if ram else 0.25
    storage_score = min(storage / 1024.0, 1.0) if storage else 0.25
    is_pro_model = "macbook pro" in name
    price = _price_to_float(product.get("price"))
    value = 1.0 if 0 < price <= 300_000 else 0.75 if price <= 420_000 else 0.50 if price <= 550_000 else 0.25

    editing = _has_positive_any(q, ("editing", "video editing", "photo editing", "rendering"))
    if editing:
        return (
            chip_score * 0.42
            + ram_score * 0.25
            + storage_score * 0.15
            + (0.18 if is_pro_model else 0.0)
        )
    return chip_score * 0.45 + min(ram / 16.0, 1.0) * 0.25 + min(storage / 512.0, 1.0) * 0.10 + value * 0.20


def _intent_priority(query: str, product: dict) -> float:
    q = query.lower()
    category = _category_of(product)
    if "iphone" in q and any(term in q for term in ("top", "best", "latest", "newest")):
        return _iphone_model_score(product)
    if _is_macbook_work_query(q):
        return _macbook_work_score(q, product)
    if _is_senior_phone_query(q):
        return _senior_phone_score(product)
    if _has_positive_any(q, GAMING_HINTS):
        if category == "phones":
            return _phone_gaming_score(product)
        if category == "laptops":
            return _laptop_gaming_score(product)
    if "camera" in q and category == "phones":
        # Explicit camera hardware signals lead. Overall device/chipset quality
        # remains a supporting proxy for image processing, not the main score.
        return (
            _camera_signal_score(product) * 0.60
            + _device_quality_score(product) * 0.22
            + phone_chipset_performance(product) * 0.18
        )
    if _has_positive_any(
        q,
        ("performance", "fastest", "powerful", "processor", "chipset", "flagship"),
    ):
        return _product_processor_score(product)
    if _has_any(q, BATTERY_HINTS):
        battery = _battery_value(product)
        return min(battery / (8500.0 if category == "phones" else 9000.0), 1.0) if battery else 0.0
    if _is_basic_laptop_use_query(q):
        return _basic_laptop_value_score(product)
    if _is_basic_phone_use_query(q):
        return _basic_phone_value_score(product)
    if _is_office_laptop_query(q):
        return _office_laptop_score(product)
    budget_max = _extract_budget(q)
    if budget_max is not None:
        price = _price_to_float(product.get("price"))
        if price <= 0 or price > budget_max:
            return 0.0
        affordability = max(0.0, 1.0 - (price / budget_max))
        if any(term in q for term in ("cheapest", "lowest price", "least expensive")):
            return affordability
        quality = _device_quality_score(product)
        if "best" in q:
            # "Best" means the strongest capable product inside the hard
            # ceiling; price is only a tie-breaker once every item fits.
            return quality * 0.97 + affordability * 0.03
        # Once the hard ceiling is satisfied, recommend the strongest option
        # and use price only as a tie-breaker. Explicit cheapest queries above
        # still sort by affordability.
        return quality * 0.97 + affordability * 0.03
    return 0.0


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

    gaming_intent = _has_positive_any(q, GAMING_HINTS)
    processor_intent = _has_positive_any(
        q,
        ("processor", "chipset", "cpu", "flagship", "snapdragon", "core i7", "core i9", "ryzen"),
    )
    if processor_intent:
        boost += _product_processor_score(product) * 0.22

    gpu_intent = _has_positive_any(q, ("gpu", "graphics", "rtx"))
    if gaming_intent:
        if category == "phones":
            processor_score = _processor_tier_score(product.get("processor"), category)
            boost += processor_score * 0.38
            boost += device_quality * 0.16
            boost += _balanced_phone_score(product) * 0.08
            if processor_score >= 1.0:
                boost += 0.08
        elif category == "laptops":
            boost += _product_processor_score(product) * 0.18
            boost += _gpu_tier_score(product.get("gpu")) * 0.30
            boost += device_quality * 0.15

    if gpu_intent and category == "laptops":
        boost += _gpu_tier_score(product.get("gpu")) * 0.24

    social_intent = _has_any(q, SOCIAL_HINTS)
    if social_intent and category == "phones":
        boost += _balanced_phone_score(product) * 0.22
        boost += device_quality * 0.15

    if _is_senior_phone_query(q) and category == "phones":
        boost += _senior_phone_score(product) * 0.30

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
    explicit_budget = _extract_budget(q) is not None
    cheapest_intent = any(term in q for term in ("cheapest", "lowest price", "least expensive"))
    if budget_intent and (not explicit_budget or cheapest_intent):
        price = _price_to_float(product.get("price"))
        if price > 0:
            if price <= 30000:
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
    raw_ram = _capacity_gb(item.get("ram"))
    raw_storage = _capacity_gb(item.get("storage"))
    if raw_ram > 128 and 0 < raw_storage <= 64:
        repaired_ram, repaired_storage = _memory_values(item)
        item["ram"] = f"{repaired_ram}GB"
        item["storage"] = (
            f"{repaired_storage // 1024}TB"
            if repaired_storage >= 1024 and repaired_storage % 1024 == 0
            else f"{repaired_storage}GB"
        )
    item["image_url"] = (
        item.get("image_url")
        or item.get("image")
        or item.get("imageLink")
        or item.get("image_link")
        or ""
    )
    score_details = score_product(item)
    if score_details.get("score_type") != "unknown":
        item["device_score"] = score_details.get("score", 0.5)
        item["device_tier"] = score_details.get("tier", "Unknown")
        item["normalized_processor"] = score_details.get("normalized_processor", item.get("processor", ""))
        item["performance_breakdown"] = score_details.get("breakdown", {})
    item["price"] = _format_price_pkr(item.get("price"))
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


def recommend_products(
    query: str,
    products: list,
    top_n: int = 10,
    *,
    query_is_normalized: bool = False,
):
    """
    Returns top N products based on semantic similarity.
    """
    if not query_is_normalized:
        query = normalize_user_query(query)
    if not products:
        return []

    constrained_products = _apply_hard_constraints(query, products)
    if not constrained_products:
        return []
    gaming_intent = _has_positive_any(query, GAMING_HINTS)
    has_priority_intent = _extract_budget(query) is not None or gaming_intent or _is_basic_laptop_use_query(query) or _is_basic_phone_use_query(query) or _is_office_laptop_query(query) or _is_macbook_work_query(query) or _is_senior_phone_query(query) or _has_any(query, BATTERY_HINTS) or "camera" in query.lower() or ("iphone" in query.lower() and any(term in query.lower() for term in ("top", "best", "latest", "newest"))) or any(
        term in query.lower() for term in ("performance", "fastest", "powerful", "processor", "chipset", "flagship")
    )
    wants_both_categories = _query_has_any(query, PHONE_HINTS) and _query_has_any(query, LAPTOP_HINTS)
    generic_budget_intent = any(k in query.lower() for k in BUDGET_HINTS) and _extract_budget(query) is None
    candidate_prices = [_price_to_float(p.get("price")) for p in constrained_products]
    candidate_prices = [price for price in candidate_prices if price > 0]
    min_price = min(candidate_prices) if candidate_prices else 0.0
    max_price = max(candidate_prices) if candidate_prices else 0.0
    if len(constrained_products) > 80:
        candidate_limit = min(len(constrained_products), max(80, top_n * 10))
        def candidate_key(product: dict):
            priority = _intent_priority(query, product) if has_priority_intent else 0.0
            return priority, _intent_boost(query, product)

        if wants_both_categories:
            per_category = max(1, candidate_limit // 2)
            phones = sorted(
                (p for p in constrained_products if _category_of(p) == "phones"),
                key=candidate_key,
                reverse=True,
            )[:per_category]
            laptops = sorted(
                (p for p in constrained_products if _category_of(p) == "laptops"),
                key=candidate_key,
                reverse=True,
            )[:per_category]
            constrained_products = phones + laptops
        else:
            constrained_products = sorted(constrained_products, key=candidate_key, reverse=True)[:candidate_limit]

    model = get_model()

    product_texts = [product_to_text(p) for p in constrained_products]

    query_embedding = model.encode([query])
    product_embeddings = _get_product_embeddings(model, constrained_products, product_texts)

    similarities = np.matmul(query_embedding, product_embeddings.T)[0]

    scored = []
    for product, semantic_score in zip(constrained_products, similarities):
        device_quality = _device_quality_score(product)
        boost = _intent_boost(query, product)
        if generic_budget_intent and max_price > min_price:
            price = _price_to_float(product.get("price"))
            if price > 0:
                boost += ((max_price - price) / (max_price - min_price)) * 0.32
        quality_alignment = (device_quality - 0.5) * 0.55
        raw_score = float(semantic_score) * 0.7 + quality_alignment + boost
        intent_priority = _intent_priority(query, product)
        scored.append((product, float(semantic_score), boost, raw_score, intent_priority))

    if has_priority_intent:
        ranked = sorted(scored, key=lambda x: (x[4], x[3]), reverse=True)
    else:
        ranked = sorted(scored, key=lambda x: x[3], reverse=True)

    if wants_both_categories and top_n >= 2:
        selected = [ranked[0]]
        first_category = _category_of(ranked[0][0])
        other = next((item for item in ranked if _category_of(item[0]) not in ("unknown", first_category)), None)
        if other is not None:
            selected.append(other)
        selected.extend(item for item in ranked if item not in selected)
        ranked = selected

    top_results = []
    for product, semantic_score, boost, raw_score, intent_priority in ranked[:top_n]:
        product_copy = _normalize_output_product(product)
        product_copy["semantic_score"] = round(_sigmoid(float(semantic_score)), 4)
        product_copy["boosted_score"] = round(float(boost), 4)
        product_copy["similarity_score"] = round(_sigmoid(float(raw_score)), 4)
        if has_priority_intent:
            product_copy["intent_score"] = round(float(intent_priority), 4)
        top_results.append(product_copy)

    return top_results
