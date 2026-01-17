"""Product filtering module - filters products based on criteria"""


def filter_products(products):
    """Filter products based on criteria"""
    
    filtered = []
    
    for product in products:
        try:
            # Check if product has name and price
            if not product.get("name") or not product.get("price"):
                print(f"  [SKIP] Missing name or price: {product}")
                continue
            
            # Check if product has URL
            if not product.get("url"):
                print(f"  [SKIP] Missing URL: {product.get('name')}")
                continue
            
            # Add product if it passes filters
            filtered.append(product)
            print(f"  [PASS] {product.get('name')[:50]}")
            
        except Exception as e:
            print(f"  [ERROR] Error filtering product: {str(e)}")
            continue
    
    return filtered
