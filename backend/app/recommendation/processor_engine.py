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
    # Extract and normalize processor
    processor_raw = phone.get("processor", "Unknown")
    processor_normalized = normalize_processor(processor_raw)

    # Step 1: Get base score from chipset DB or GPU fallback
    if processor_normalized in CHIPSET_DB:
        chipset_info = CHIPSET_DB[processor_normalized]
        base_score = chipset_info["score"]
        tier = chipset_info["tier"]
    else:
        # Fallback to GPU-based scoring
        gpu_str = phone.get("gpu", "Unknown")
        base_score = infer_score_from_gpu(gpu_str)
        tier = "Unknown"

    # Step 2: Calculate RAM score (normalized to 12GB as max)
    ram_str = phone.get("ram", "0GB")
    ram_value = extract_ram(ram_str)
    ram_score = min(ram_value / 12.0, 1.0)

    # Step 3: Calculate battery score (normalized to 7000mAh as max)
    battery_str = phone.get("battery", "0mAh")
    battery_value = extract_battery(battery_str)
    battery_score = min(battery_value / 7000.0, 1.0)

    # Step 4: Calculate recency score
    # Phones from 2024-2025 get high scores, older phones get lower
    release_date_str = phone.get("release_date", "2020")
    year = extract_year(release_date_str)
    years_old = 2025 - year
    recency_score = max(1.0 - (years_old * 0.1), 0.3)  # Floor at 0.3

    # Step 5: Calculate final score
    final_score = (
        base_score * 0.6 +
        ram_score * 0.2 +
        battery_score * 0.1 +
        recency_score * 0.1
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
            "recency_score": round(recency_score, 2),
        },
        "specs": {
            "processor": processor_normalized,
            "ram_gb": ram_value,
            "battery_mah": battery_value,
            "release_year": year,
        }
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
