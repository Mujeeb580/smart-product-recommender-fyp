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


def _category_label(category: str) -> str:
    normalized = _clean_text(category).lower()
    if "laptop" in normalized or "notebook" in normalized:
        return "laptop"
    if "phone" in normalized or "mobile" in normalized or "smartphone" in normalized:
        return "phone"
    return "product"


def _price_context(price, category_label: str) -> str:
    if not isinstance(price, (int, float)) or price <= 0:
        return ""

    if category_label == "laptop":
        if price <= 40000:
            return f"budget-friendly laptop at PKR {price}"
        if price <= 80000:
            return f"mid-range laptop at PKR {price}"
        if price <= 150000:
            return f"performance laptop at PKR {price}"
        return f"premium laptop at PKR {price}"

    if price <= 20000:
        return f"budget-friendly phone at PKR {price}"
    if price <= 35000:
        return f"affordable mid-range phone at PKR {price}"
    if price <= 60000:
        return f"mid-range phone at PKR {price}"
    if price <= 100000:
        return f"premium phone at PKR {price}"
    return f"flagship premium phone at PKR {price}"


def product_to_text(product: dict) -> str:
    """
    Convert a Firestore product document into semantic-rich text for embedding.
    Adds quality indicators and context based on specs and price.
    
    Args:
        product: Dictionary containing product fields
        
    Returns:
        Formatted string with product attributes and inferred context
    """
    name = _clean_text(product.get('normalized_name') or product.get('name', ''))
    brand = _clean_text(product.get('brand', ''))
    ram = _clean_text(product.get('ram', ''))
    storage = _clean_text(product.get('storage', ''))
    processor = _clean_text(product.get('normalized_processor') or product.get('processor', ''))
    gpu = _clean_text(product.get('gpu', ''))
    battery = _clean_text(product.get('battery', ''))
    category = product.get('category', 'product')
    category_label = _category_label(category)
    price = _to_numeric_price(product.get('price', 0))
    
    # Build base description
    parts = [name, f"{brand} brand".strip()]
    
    # Add RAM context
    if ram:
        ram_value = _extract_number(ram)
        if ram_value:
            if ram_value >= 12:
                parts.append(f"{ram} RAM for heavy multitasking and gaming")
            elif ram_value >= 8:
                parts.append(f"{ram} RAM for smooth daily use and multitasking")
            elif ram_value >= 6:
                parts.append(f"{ram} RAM for moderate daily use")
            elif ram_value >= 4:
                parts.append(f"{ram} RAM for basic daily tasks")
            else:
                parts.append(f"{ram} RAM for light use")
        else:
            parts.append(f"{ram} RAM")
    
    # Add storage context
    if storage:
        storage_value = _extract_number(storage)
        if storage_value:
            if storage_value >= 512:
                parts.append(f"{storage} storage for extensive media and apps")
            elif storage_value >= 256:
                parts.append(f"{storage} storage for plenty of apps and photos")
            elif storage_value >= 128:
                parts.append(f"{storage} storage for everyday use")
            else:
                parts.append(f"{storage} storage for basic needs")
        else:
            parts.append(f"{storage} storage")

    if processor:
        parts.append(f"processor {processor}")

    if gpu and str(gpu).strip().lower() not in ('unknown', 'n/a', 'na', 'none'):
        parts.append(f"gpu {gpu}")

    battery_value = _extract_number(str(battery))
    if battery_value:
        parts.append(f"{battery_value} mAh battery")
        if battery_value >= 6000:
            parts.append("very strong battery backup")
        elif battery_value >= 5000:
            parts.append("strong battery backup")
    
    # Add category-aware price context
    price_context = _price_context(price, category_label)
    if price_context:
        parts.append(price_context)

    if category_label == "phone":
        if any(key in processor.lower() for key in ("snapdragon 8", "dimensity 9", "a17", "a16", "a15", "exynos 2400")):
            parts.append("flagship gaming phone")
        elif any(key in processor.lower() for key in ("snapdragon 7", "dimensity 8", "helio g99", "helio g95")):
            parts.append("balanced performance phone")
    elif category_label == "laptop":
        if any(key in processor.lower() for key in ("core i7", "core i9", "ryzen 7", "ryzen 9", "core ultra 7", "core ultra 9")):
            parts.append("high performance laptop")
        if any(key in gpu.lower() for key in ("rtx", "gtx")):
            parts.append("gaming laptop")
        elif any(key in gpu.lower() for key in ("iris", "uhd", "integrated", "radeon graphics")):
            parts.append("portable everyday laptop")
    
    # Add premium brand indicators
    premium_brands = ['apple', 'samsung', 'google', 'oneplus', 'xiaomi', 'oppo', 'vivo', 'realme', 'nothing', 'motorola', 'nokia', 'honor', 'huawei']
    if brand.lower() in premium_brands:
        parts.append(f"trusted {brand} brand")
    
    # Add category
    category_lower = str(category).lower()
    parts.append(category_lower)
    if category_label == 'phone':
        parts.append('smartphone mobile device')
    if category_label == 'laptop':
        parts.append('laptop notebook computer')
    
    return " | ".join(parts)


def _extract_number(text: str) -> int:
    """Extract numeric value from text like '8GB' or '256GB'"""
    import re
    if not text:
        return 0
    match = re.search(r'(\d+)', str(text))
    return int(match.group(1)) if match else 0


def _to_numeric_price(price) -> float:
    if isinstance(price, (int, float)):
        return float(price)
    text = str(price or '').replace('Rs', '').replace('PKR', '').replace(',', '').strip()
    try:
        return float(text)
    except Exception:
        return 0.0
