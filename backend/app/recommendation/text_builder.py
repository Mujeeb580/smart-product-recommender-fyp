def product_to_text(product: dict) -> str:
    """
    Convert a Firestore product document into semantic-rich text for embedding.
    Adds quality indicators and context based on specs and price.
    
    Args:
        product: Dictionary containing product fields
        
    Returns:
        Formatted string with product attributes and inferred context
    """
    name = product.get('name', '')
    brand = product.get('brand', '')
    ram = product.get('ram', '')
    storage = product.get('storage', '')
    category = product.get('category', 'product')
    price = product.get('price', 0)
    
    # Build base description
    parts = [f"{name}", f"{brand} brand"]
    
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
    
    # Add price range context
    if isinstance(price, (int, float)):
        if price <= 20000:
            parts.append(f"budget-friendly phone at Rs {price}")
        elif price <= 35000:
            parts.append(f"affordable mid-range phone at Rs {price}")
        elif price <= 60000:
            parts.append(f"mid-range phone at Rs {price}")
        elif price <= 100000:
            parts.append(f"premium phone at Rs {price}")
        else:
            parts.append(f"flagship premium phone at Rs {price}")
    
    # Add premium brand indicators
    premium_brands = ['apple', 'samsung', 'google', 'oneplus', 'xiaomi', 'oppo', 'vivo', 'realme', 'nothing', 'motorola', 'nokia', 'honor', 'huawei']
    if brand.lower() in premium_brands:
        parts.append(f"trusted {brand} brand")
    
    # Add category
    parts.append(f"{category.lower()}")
    
    return " | ".join(parts)


def _extract_number(text: str) -> int:
    """Extract numeric value from text like '8GB' or '256GB'"""
    import re
    if not text:
        return 0
    match = re.search(r'(\d+)', str(text))
    return int(match.group(1)) if match else 0