"""Shared helpers for cleaning scraper-derived specs before Firestore writes."""

import re
from typing import Any, Dict

GENERIC_PROCESSOR_PATTERNS = (
    r"^octa\s*core(?:\s*processor)?$",
    r"^octa-core(?:\s*processor)?$",
    r"^unknown$",
    r"^n/?a$",
    r"^na$",
    r"^none$",
)


def normalize_spec_text(value: str) -> str:
    """Normalize escaped/unicode-noisy spec text into stable plain text."""
    text = str(value or "").strip()
    if not text:
        return ""

    # Decode unicode escapes from page JSON blobs (example: \u00ae).
    text = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), text)
    text = text.replace("\\/", "/")

    # Drop trademark and known noisy symbols from scraped values.
    text = text.replace("®", "").replace("™", "")

    # Remove malformed backslash escape fragments (example: Intel\ù Core\ù).
    text = re.sub(r"\\[^\s/.-]?", " ", text)

    return re.sub(r"\s+", " ", text).strip()


def normalize_generic_processor(value: str) -> str:
    text = normalize_spec_text(value)
    if not text:
        return "Unknown"

    normalized = text.lower()
    if any(re.match(pattern, normalized, re.IGNORECASE) for pattern in GENERIC_PROCESSOR_PATTERNS):
        return "Unknown"
    return text


def parse_price_numeric(value: Any) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)

    text = normalize_spec_text(str(value or ""))
    cleaned = re.sub(r"[^0-9.]", "", text)
    if not cleaned:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def normalize_scraped_product_fields(product: Dict[str, Any]) -> Dict[str, Any]:
    """Return normalized Firestore-ready core fields from a scraped product payload."""
    specs = product.get("specs", {})
    if not isinstance(specs, dict):
        specs = {}

    ram_text = normalize_spec_text(specs.get("ram", "Unknown")) or "Unknown"
    storage_text = normalize_spec_text(specs.get("storage", "Unknown")) or "Unknown"

    return {
        "brand": normalize_spec_text(specs.get("brand", "Unknown")) or "Unknown",
        "ram": ram_text.replace(" RAM", "").replace("RAM", "").strip() or "Unknown",
        "storage": storage_text.replace(" SSD", "").replace(" HDD", "").replace("SSD", "").replace("HDD", "").strip() or "Unknown",
        "processor": normalize_generic_processor(specs.get("processor", "Unknown")),
        "gpu": normalize_spec_text(specs.get("gpu", "Unknown")) or "Unknown",
        "battery": normalize_spec_text(specs.get("battery", "Unknown")) or "Unknown",
        "gpu_memory": normalize_spec_text(specs.get("gpu_memory", "Unknown")) or "Unknown",
        "price_numeric": parse_price_numeric(product.get("price")),
        "image_url": normalize_spec_text(product.get("image_url", "")),
    }
