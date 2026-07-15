"""
Processor Engine Module

Deterministic scoring system for phone performance evaluation.
No LLM dependencies - rule-based chipset and spec analysis.
"""

import re
from datetime import datetime


# ============================================================================
# STEP 1: CHIPSET DATABASE
# ============================================================================

CHIPSET_DB = {
    # Snapdragon Flagship
    "Snapdragon 8 Gen 3": {"tier": "Flagship", "score": 0.97},
    "Snapdragon 8 Gen 2": {"tier": "Flagship", "score": 0.95},
    "Snapdragon 8 Gen 1": {"tier": "Flagship", "score": 0.90},

    # Snapdragon Upper Mid
    "Snapdragon 7 Gen 3": {"tier": "Upper Mid", "score": 0.80},
    "Snapdragon 7 Gen 2": {"tier": "Upper Mid", "score": 0.78},
    "Snapdragon 7 Gen 1": {"tier": "Upper Mid", "score": 0.75},
    "Snapdragon 778": {"tier": "Upper Mid", "score": 0.77},

    # Snapdragon Mid
    "Snapdragon 6 Gen 1": {"tier": "Mid", "score": 0.65},
    "Snapdragon 695": {"tier": "Mid", "score": 0.63},
    "Snapdragon 680": {"tier": "Mid", "score": 0.58},

    # Snapdragon Low
    "Snapdragon 662": {"tier": "Low", "score": 0.48},
    "Snapdragon 665": {"tier": "Low", "score": 0.50},

    # Dimensity Flagship
    "Dimensity 9300": {"tier": "Flagship", "score": 0.96},
    "Dimensity 9200": {"tier": "Flagship", "score": 0.93},

    # Dimensity Upper Mid
    "Dimensity 8200": {"tier": "Upper Mid", "score": 0.80},
    "Dimensity 8100": {"tier": "Upper Mid", "score": 0.78},

    # Dimensity Mid
    "Dimensity 7050": {"tier": "Mid", "score": 0.68},
    "Dimensity 6080": {"tier": "Mid", "score": 0.60},

    # Helio Processors
    "Helio G99": {"tier": "Mid", "score": 0.60},
    "Helio G95": {"tier": "Mid", "score": 0.58},
    "Helio G88": {"tier": "Low", "score": 0.50},

    # Unisoc (Budget)
    "Unisoc T7250": {"tier": "Low", "score": 0.40},
    "Unisoc T612": {"tier": "Low", "score": 0.35},

    # Apple
    "Apple A17 Pro": {"tier": "Flagship", "score": 0.98},
    "Apple A16": {"tier": "Flagship", "score": 0.95},
    "Apple A15": {"tier": "Flagship", "score": 0.92},

    # Exynos
    "Exynos 2400": {"tier": "Flagship", "score": 0.92},
    "Exynos 1480": {"tier": "Upper Mid", "score": 0.78},

    # MediaTek
    "MediaTek Kompanio": {"tier": "Low", "score": 0.45},
}


PHONE_FLAGSHIP_HINTS = (
    "snapdragon 8",
    "dimensity 9300",
    "dimensity 9200",
    "a17",
    "a16",
    "a15",
    "exynos 2400",
)

PHONE_UPPER_MID_HINTS = (
    "snapdragon 7",
    "dimensity 8200",
    "dimensity 8100",
    "snapdragon 778",
    "exynos 1480",
)

PHONE_MID_HINTS = (
    "snapdragon 6",
    "dimensity 7050",
    "dimensity 6080",
    "helio g99",
    "helio g95",
    "helio g88",
)

PHONE_LOW_HINTS = (
    "unisoc",
    "helio g85",
    "helio g80",
    "helio g37",
    "helio p",
    "snapdragon 4",
)

LAPTOP_HIGH_CPU_HINTS = (
    "core ultra 9",
    "core i9",
    "ryzen 9",
    "hx",
    "m4 max",
    "m3 max",
    "m2 max",
    "m1 max",
)

LAPTOP_UPPER_CPU_HINTS = (
    "core ultra 7",
    "core i7",
    "ryzen 7",
    "u7",
    "h7",
)

LAPTOP_MID_CPU_HINTS = (
    "core ultra 5",
    "core i5",
    "ryzen 5",
    "u5",
    "i5-",
)

LAPTOP_LOW_CPU_HINTS = (
    "core i3",
    "ryzen 3",
    "celeron",
    "pentium",
    "n100",
    "n200",
    "n305",
)

HIGH_END_LAPTOP_GPU_HINTS = (
    "rtx 4090",
    "rtx 4080",
    "rtx 4070",
    "rtx 5070",
    "rtx 5060",
    "rtx 4060",
)


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


def _extract_storage_gb(text: str) -> int:
    cleaned = _clean_text(text).lower()
    if not cleaned:
        return 0

    match = re.search(r"(\d+(?:\.\d+)?)\s*(tb|gb)", cleaned)
    if not match:
        return 0

    value = float(match.group(1))
    if match.group(2) == "tb":
        value *= 1024
    return int(round(value))


def _extract_year(text: str) -> int:
    match = re.search(r"\b(20\d{2})\b", str(text or ""))
    return int(match.group(1)) if match else 2020


def _bounded_ratio(value: int, maximum: float, missing_default: float = 0.5) -> float:
    if not value or value <= 0:
        return missing_default
    return min(value / maximum, 1.0)


def _phone_chipset_profile(product: dict) -> tuple[str, float, str]:
    raw_text = " ".join(
        _clean_text(product.get(field, "")) for field in ("processor", "name", "gpu")
    ).lower()

    normalized = normalize_processor(product.get("processor", ""))
    if normalized in CHIPSET_DB:
        chipset_info = CHIPSET_DB[normalized]
        return normalized, chipset_info["score"], chipset_info["tier"]

    if any(hint in raw_text for hint in PHONE_FLAGSHIP_HINTS):
        if "snapdragon" in raw_text or "sd" in raw_text:
            return "Snapdragon 8 Series", 0.97, "Flagship"
        if "dimensity" in raw_text:
            return "Dimensity 9 Series", 0.96, "Flagship"
        if "apple" in raw_text or "a17" in raw_text or "a16" in raw_text or "a15" in raw_text:
            return "Apple A-Series", 0.97, "Flagship"
        if "exynos" in raw_text:
            return "Exynos 2400", 0.92, "Flagship"

    if any(hint in raw_text for hint in PHONE_UPPER_MID_HINTS):
        if "snapdragon" in raw_text or "sd" in raw_text:
            return "Snapdragon 7 Series", 0.80, "Upper Mid"
        if "dimensity" in raw_text:
            return "Dimensity 8 Series", 0.79, "Upper Mid"
        if "exynos" in raw_text:
            return "Exynos Upper Mid", 0.78, "Upper Mid"

    if any(hint in raw_text for hint in PHONE_MID_HINTS):
        if "snapdragon" in raw_text or "sd" in raw_text:
            return "Snapdragon 6 Series", 0.63, "Mid"
        if "dimensity" in raw_text:
            return "Dimensity Mid", 0.62, "Mid"
        if "helio" in raw_text:
            return "Helio Series", 0.60, "Mid"

    if any(hint in raw_text for hint in PHONE_LOW_HINTS):
        return _clean_text(product.get("processor", "")) or "Unknown", 0.40, "Low"

    if raw_text:
        return _clean_text(product.get("processor", "")) or "Unknown", 0.45, "Unknown"

    return "Unknown", 0.0, "Unknown"


def _laptop_cpu_profile(product: dict) -> tuple[str, float, str]:
    raw_text = " ".join(
        _clean_text(product.get(field, "")) for field in ("processor", "name", "gpu")
    ).lower()
    display = _clean_text(product.get("processor", "")) or _clean_text(product.get("name", "")) or "Unknown"

    if not raw_text:
        return "Unknown", 0.0, "Unknown"

    if any(hint in raw_text for hint in LAPTOP_HIGH_CPU_HINTS):
        return display, 1.0, "Flagship"

    if any(hint in raw_text for hint in LAPTOP_UPPER_CPU_HINTS):
        return display, 0.82, "Upper Mid"

    if any(hint in raw_text for hint in LAPTOP_MID_CPU_HINTS):
        return display, 0.62, "Mid"

    if any(hint in raw_text for hint in LAPTOP_LOW_CPU_HINTS):
        return display, 0.35, "Low"

    if any(model in raw_text for model in ("m4", "m3", "m2", "m1")):
        return display, 0.90, "Upper Mid"

    if any(token in raw_text for token in ("ultra 7", "u7", "13500h", "13620h", "13700h", "14650hx", "12700h")):
        return display, 0.84, "Upper Mid"

    if any(token in raw_text for token in ("i5-", "1235u", "1240p", "1335u", "7530u", "7730u", "7520u")):
        return display, 0.62, "Mid"

    if any(token in raw_text for token in ("n305", "n200", "n100", "celeron", "pentium")):
        return display, 0.30, "Low"

    return display, 0.50, "Unknown"


def _laptop_gpu_score(gpu: str) -> float:
    g = _clean_text(gpu).lower()
    if not g or g in ("unknown", "n/a", "na", "none"):
        return 0.45
    if any(x in g for x in HIGH_END_LAPTOP_GPU_HINTS):
        return 1.0
    if any(x in g for x in ("rtx 4050", "rtx 3050", "rtx 3060", "rtx 4060", "rtx 4070")):
        return 0.80
    if any(x in g for x in ("gtx", "rtx 20", "rtx 30")):
        return 0.65
    if any(x in g for x in ("iris xe", "iris", "uhd", "radeon graphics", "integrated")):
        return 0.35
    return 0.45


def _camera_signal_score(product: dict) -> float:
    camera_text = _clean_text(product.get("camera", "")).lower()
    if not camera_text:
        camera_text = _clean_text(product.get("name", "")).lower()
    mp_values = [int(v) for v in re.findall(r"(\d+)\s*mp", camera_text)]
    if not mp_values:
        if any(x in camera_text for x in ("ultra", "pro", "pixel", "iphone")):
            return 0.55
        return 0.3
    best = max(mp_values)
    if best >= 200:
        return 1.0
    if best >= 108:
        return 0.8
    if best >= 64:
        return 0.55
    return 0.3


# ============================================================================
# STEP 2: NORMALIZE PROCESSOR NAME
# ============================================================================

def normalize_processor(processor_str: str) -> str:
    """
    Normalize processor string to match CHIPSET_DB keys.

    Handles:
    - "SD 7Gen" → "Snapdragon 7 Gen"
    - Spacing variations
    - Case sensitivity
    - Common abbreviations

    Args:
        processor_str: Raw processor string from database

    Returns:
        Normalized processor name (best match from CHIPSET_DB)
    """
    if not processor_str or not isinstance(processor_str, str):
        return "Unknown"

    # Clean input
    clean = processor_str.strip().lower()

    # Replace common abbreviations
    replacements = {
        r'\bsd\b': 'snapdragon',
        r'\bqc\b': 'snapdragon',
        r'\bmt\b': 'dimensity',  # MediaTek
        r'\bkirin\b': 'kirin',
        r'gen ': 'gen ',
        r' +': ' ',  # Multiple spaces
    }

    for pattern, repl in replacements.items():
        clean = re.sub(pattern, repl, clean)

    # Try exact match first (case-insensitive)
    for db_key in CHIPSET_DB.keys():
        if clean == db_key.lower():
            return db_key

    # Try partial/fuzzy match
    for db_key in CHIPSET_DB.keys():
        db_lower = db_key.lower()
        if db_lower in clean or clean in db_lower:
            return db_key

    # Extract brand + series if possible
    # E.g., "snapdragon 7" or "dimensity 8200"
    for db_key in CHIPSET_DB.keys():
        db_lower = db_key.lower()
        # Check if core components match (words longer than 2 chars)
        if all(word in clean for word in db_lower.split() if len(word) > 2):
            return db_key

    return "Unknown"


# ============================================================================
# STEP 3: GPU-BASED FALLBACK
# ============================================================================

def infer_score_from_gpu(gpu_str: str) -> float:
    """
    Infer processor score from GPU name if chipset is unknown.

    GPU Hierarchy (rough):
    - Adreno 8xx → Flagship (~0.9+)
    - Adreno 7xx → Upper Mid (~0.75-0.85)
    - Mali-G710 → Upper Mid (~0.8)
    - Mali-G77 → Upper Mid (~0.78)
    - Mali-G57 → Low-Mid (~0.5)
    - Mali-G57 MP1 → Low (~0.3)
    - Unknown → Default (~0.5)

    Args:
        gpu_str: GPU string (e.g., "Adreno 722@1150MHz")

    Returns:
        Score between 0 and 1
    """
    if not gpu_str or not isinstance(gpu_str, str):
        return 0.5

    gpu_lower = gpu_str.lower()

    # Adreno 8xx (Flagship)
    if 'adreno' in gpu_lower:
        if any(x in gpu_lower for x in ['870', '880', '885']):
            return 0.95
        elif any(x in gpu_lower for x in ['850', '860']):
            return 0.90
        elif any(x in gpu_lower for x in ['750', '755', '760']):
            return 0.80
        elif any(x in gpu_lower for x in ['700', '710', '720', '722']):
            return 0.75
        else:
            return 0.65  # Generic Adreno

    # Mali-G chips
    if 'mali' in gpu_lower:
        if 'g710' in gpu_lower:
            return 0.80
        elif 'g77' in gpu_lower or 'g78' in gpu_lower:
            return 0.78
        elif 'g76' in gpu_lower:
            return 0.75
        elif 'g57' in gpu_lower:
            # Check for MP variant
            if 'mp1' in gpu_lower:
                return 0.30
            else:
                return 0.50
        elif 'g55' in gpu_lower:
            return 0.25

    # PowerVR (Apple legacy)
    if 'powervr' in gpu_lower:
        return 0.85

    # Unknown GPU
    return 0.50


# ============================================================================
# STEP 4: PARSE NUMERIC VALUES
# ============================================================================

def extract_ram(ram_str: str) -> int:
    """
    Extract RAM value in GB.

    Examples:
        "12GB" → 12
        "4 GB" → 4
        "2048MB" → 2

    Args:
        ram_str: RAM string

    Returns:
        RAM in GB as integer
    """
    if not ram_str or not isinstance(ram_str, str):
        return 0

    # Try to find number + GB
    match_gb = re.search(r'(\d+)\s*gb', ram_str.lower())
    if match_gb:
        return int(match_gb.group(1))

    # Try MB conversion
    match_mb = re.search(r'(\d+)\s*mb', ram_str.lower())
    if match_mb:
        return int(match_mb.group(1)) // 1024

    return 0


def extract_battery(battery_str: str) -> int:
    """
    Extract battery capacity in mAh.

    Examples:
        "5000mAh" → 5000
        "7000 mAh" → 7000

    Args:
        battery_str: Battery string

    Returns:
        Battery capacity in mAh as integer
    """
    if not battery_str or not isinstance(battery_str, str):
        return 0

    match = re.search(r'(\d+)\s*mah', battery_str.lower())
    if match:
        return int(match.group(1))

    return 0


def extract_year(date_str: str) -> int:
    """
    Extract year from date string.

    Examples:
        "25 Jun 2025" → 2025
        "2024" → 2024
        "Q4 2024" → 2024

    Args:
        date_str: Date string

    Returns:
        Year as integer, or 2020 if not found
    """
    if not date_str or not isinstance(date_str, str):
        return 2020

    match = re.search(r'\b(20\d{2})\b', date_str)
    if match:
        return int(match.group(1))

    return 2020


# ============================================================================
# STEP 5: MAIN SCORING FUNCTION
# ============================================================================

def calculate_phone_score(phone: dict) -> dict:
    """
    Calculate comprehensive phone performance score.

    Scoring formula:
    - Chipset Score (base):        60% weight
    - RAM Score:                   20% weight
    - Battery Score:               10% weight
    - Recency Score:               10% weight

    Args:
        phone: Phone data dict with fields:
            - processor (str): Processor name
            - gpu (str, optional): GPU name
            - ram (str): RAM string (e.g., "12GB")
            - battery (str): Battery string (e.g., "5000mAh")
            - release_date (str, optional): Release date

    Returns:
        Dict with:
            - score: Final score (0-1, rounded to 2 decimals)
            - tier: Processor tier (Flagship, Upper Mid, Mid, Low, Unknown)
            - normalized_processor: Cleaned processor name
            - breakdown: Dict with component scores
            - specs: Dict with extracted specs
    """
    processor_raw = phone.get("processor", "Unknown")
    processor_normalized, base_score, tier = _phone_chipset_profile(phone)

    ram_value = extract_ram(phone.get("ram", "0GB"))
    ram_score = _bounded_ratio(ram_value, 12.0, missing_default=0.45)

    battery_value = extract_battery(phone.get("battery", "0mAh"))
    battery_score = _bounded_ratio(battery_value, 7000.0, missing_default=0.45)

    storage_value = _extract_storage_gb(phone.get("storage", ""))
    storage_score = _bounded_ratio(storage_value, 512.0, missing_default=0.45)

    camera_score = _camera_signal_score(phone)

    release_year = _extract_year(phone.get("release_date", phone.get("launch_date", "2020")))
    years_old = max(0, 2025 - release_year)
    recency_score = max(1.0 - (years_old * 0.1), 0.3)

    final_score = (
        base_score * 0.50 +
        ram_score * 0.18 +
        battery_score * 0.10 +
        storage_score * 0.08 +
        camera_score * 0.07 +
        recency_score * 0.07
    )

    # Ensure score is in valid range
    final_score = max(0.0, min(final_score, 1.0))

    return {
        "score": round(final_score, 2),
        "tier": tier,
        "normalized_processor": processor_normalized,
        "breakdown": {
            "base_chipset_score": round(base_score, 2),
            "ram_score": round(ram_score, 2),
            "battery_score": round(battery_score, 2),
            "storage_score": round(storage_score, 2),
            "camera_score": round(camera_score, 2),
            "recency_score": round(recency_score, 2),
        },
        "specs": {
            "processor": processor_normalized,
            "ram_gb": ram_value,
            "battery_mah": battery_value,
            "storage_gb": storage_value,
            "release_year": release_year,
        }
    }


def calculate_laptop_score(laptop: dict) -> dict:
    """Calculate structured laptop performance score."""
    cpu_normalized, cpu_score, tier = _laptop_cpu_profile(laptop)
    gpu_score = _laptop_gpu_score(laptop.get("gpu", "Unknown"))

    ram_value = extract_ram(laptop.get("ram", "0GB"))
    ram_score = _bounded_ratio(ram_value, 32.0, missing_default=0.5)

    storage_value = _extract_storage_gb(laptop.get("storage", ""))
    storage_score = _bounded_ratio(storage_value, 1024.0, missing_default=0.5)

    battery_value = extract_battery(laptop.get("battery", "0mAh"))
    battery_score = _bounded_ratio(battery_value, 7000.0, missing_default=0.5)

    release_year = _extract_year(laptop.get("release_date", laptop.get("launch_date", "2020")))
    years_old = max(0, 2025 - release_year)
    recency_score = max(1.0 - (years_old * 0.08), 0.35)

    final_score = (
        cpu_score * 0.38 +
        gpu_score * 0.24 +
        ram_score * 0.16 +
        storage_score * 0.10 +
        battery_score * 0.05 +
        recency_score * 0.07
    )

    final_score = max(0.0, min(final_score, 1.0))

    return {
        "score": round(final_score, 2),
        "tier": tier,
        "normalized_processor": cpu_normalized,
        "breakdown": {
            "base_cpu_score": round(cpu_score, 2),
            "gpu_score": round(gpu_score, 2),
            "ram_score": round(ram_score, 2),
            "storage_score": round(storage_score, 2),
            "battery_score": round(battery_score, 2),
            "recency_score": round(recency_score, 2),
        },
        "specs": {
            "processor": cpu_normalized,
            "ram_gb": ram_value,
            "storage_gb": storage_value,
            "battery_mah": battery_value,
            "release_year": release_year,
        }
    }


def score_product(product: dict) -> dict:
    """Score a product using the appropriate category-specific scorer."""
    category = _clean_text(product.get("category", "")).lower()
    if "phone" in category or "mobile" in category:
        result = calculate_phone_score(product)
        result["score_type"] = "phone"
        return result
    if "laptop" in category or "notebook" in category:
        result = calculate_laptop_score(product)
        result["score_type"] = "laptop"
        return result

    return {
        "score": 0.5,
        "tier": "Unknown",
        "normalized_processor": _clean_text(product.get("processor", "")) or "Unknown",
        "breakdown": {},
        "specs": {},
        "score_type": "unknown",
    }


# ============================================================================
# STEP 7: TEST CASE
# ============================================================================

def test_processor_engine():
    """Test the processor engine with sample phones."""

    test_cases = [
        {
            "name": "Budget Phone (T7250)",
            "phone": {
                "processor": "T7250",
                "gpu": "Mali-G57 MP1",
                "ram": "4GB",
                "battery": "5000mAh",
                "release_date": "25 Jun 2025"
            }
        },
        {
            "name": "Mid-range Phone (Snapdragon 695)",
            "phone": {
                "processor": "SD 695",
                "gpu": "Adreno 720",
                "ram": "6GB",
                "battery": "5500mAh",
                "release_date": "Q2 2024"
            }
        },
        {
            "name": "Flagship Phone (Snapdragon 8 Gen 3)",
            "phone": {
                "processor": "Snapdragon 8 Gen 3",
                "gpu": "Adreno 830",
                "ram": "12GB",
                "battery": "7000mAh",
                "release_date": "2024"
            }
        }
    ]

    print("=" * 70)
    print("PROCESSOR ENGINE TEST RESULTS")
    print("=" * 70)

    for test in test_cases:
        result = calculate_phone_score(test["phone"])
        print(f"\n{test['name']}")
        print(f"  Raw Processor: {test['phone']['processor']}")
        print(f"  Normalized: {result['normalized_processor']}")
        print(f"  Tier: {result['tier']}")
        print(f"  Final Score: {result['score']}")
        print(f"  Breakdown: {result['breakdown']}")
        print(f"  Specs: {result['specs']}")
        print("\n" + "=" * 70)


if __name__ == "__main__":
    test_processor_engine()
