"""Data cleaning module - normalizes and cleans product data"""
import re


def extract_laptop_specs_from_name(name):
    """Extract processor, GPU, RAM, storage from laptop name"""
    specs = {}
    
    # Extract Processor (e.g., Ci5-13420H, Ci7-13620H, Ryzen 7, Core i5, M4 Chip)
    processor_patterns = [
        r'(Intel Core Ultra [57] \d+\w*)',  # Intel Core Ultra 7 255H (more specific)
        r'(Ci[357]-\w+)',  # Ci5-13420H, Ci7-13620H
        r'(Core [iI][357] \w+)',  # Core i5 13th Gen
        r'(Intel Core Ultra [57])',  # Intel Core Ultra 7 (fallback without model number)
        r'(Ryzen [357] \w+)',  # Ryzen 7 5800H
        r'([AM]MD Ryzen [357] \w+)',  # AMD Ryzen 7
        r'(M[1-9]\d* Chip)',  # M1 Chip, M4 Chip (Apple)
        r'(M[1-9]\d* Pro)',  # M1 Pro, M2 Pro
        r'(M[1-9]\d* Max)',  # M1 Max, M2 Max
    ]
    
    for pattern in processor_patterns:
        match = re.search(pattern, name, re.IGNORECASE)
        if match:
            processor = match.group(1)
            # Normalize processor names
            if processor.startswith('Ci'):
                processor = processor.replace('Ci', 'Intel Core i')
            specs['processor'] = processor
            break
    
    # Extract GPU (e.g., RTX 5050, RTX 4060, GTX 1650)
    gpu_patterns = [
        r'(RTX \d{4}(?:\s*Ti)?)',  # RTX 5050, RTX 4060 Ti
        r'(GTX \d{4}(?:\s*Ti)?)',  # GTX 1650 Ti
        r'(MX\d{3})',  # MX450
        r'(Radeon \w+)',  # Radeon Graphics
    ]
    
    for pattern in gpu_patterns:
        match = re.search(pattern, name, re.IGNORECASE)
        if match:
            gpu = match.group(1)
            specs['gpu'] = gpu
            
            # Try to extract GPU memory (e.g., 8GB, 6GB)
            gpu_memory_match = re.search(r'(RTX|GTX|MX)\s*\d+\s*(\d+GB)', name, re.IGNORECASE)
            if gpu_memory_match:
                specs['gpu_memory'] = gpu_memory_match.group(2)
            break
    
    # Extract RAM from parentheses (e.g., 16GB-512GB SSD)
    ram_match = re.search(r'\((\d+GB)', name)
    if ram_match:
        specs['ram'] = ram_match.group(1)
    
    # Extract Storage from parentheses (e.g., 512GB SSD, 1TB HDD)
    storage_match = re.search(r'[-\s](\d+(?:GB|TB))(?:\s*(?:SSD|HDD))?', name)
    if storage_match:
        specs['storage'] = storage_match.group(1)
    
    return specs


def clean_products(products):
    """Clean and normalize product data"""
    
    cleaned = []
    
    for product in products:
        try:
            name = product.get("name", "").strip()
            category = product.get("category", "Unknown")
            
            cleaned_product = {
                "name": name,
                "category": category,
                "price": product.get("price", "").strip(),
                "url": product.get("url", "").strip(),
                "specs": product.get("specs", {}),
            }
            
            # For laptops, extract specs from name
            if category == "Laptops" and name:
                name_specs = extract_laptop_specs_from_name(name)
                
                # Debug output
                if name_specs:
                    print(f"  [EXTRACTED] {name[:50]}")
                    print(f"              Processor: {name_specs.get('processor', 'N/A')}")
                    print(f"              GPU: {name_specs.get('gpu', 'N/A')}")
                    print(f"              RAM: {name_specs.get('ram', 'N/A')}")
                    print(f"              Storage: {name_specs.get('storage', 'N/A')}")
                
                # Merge name-extracted specs with existing specs (avoiding duplicates)
                existing_specs = cleaned_product["specs"]
                
                # Remove duplicates by converting to dict (if it's somehow a list)
                if isinstance(existing_specs, list):
                    existing_specs = {item[0]: item[1] for item in existing_specs}
                
                for key, value in name_specs.items():
                    # Only add if not exists OR if existing value is empty/None
                    if key not in existing_specs or not existing_specs.get(key):
                        existing_specs[key] = value
                
                # Clean up RAM formatting (remove "RAM" suffix)
                if 'ram' in existing_specs and isinstance(existing_specs['ram'], str):
                    existing_specs['ram'] = existing_specs['ram'].replace(' RAM', '').replace('RAM', '').strip()
                
                # Clean up storage formatting and ensure no duplicates
                if 'storage' in existing_specs:
                    storage_value = existing_specs['storage']
                    if isinstance(storage_value, str):
                        # Remove SSD/HDD suffix
                        cleaned_storage = storage_value.replace(' SSD', '').replace(' HDD', '').replace('SSD', '').replace('HDD', '').strip()
                        existing_specs['storage'] = cleaned_storage
                
                # Ensure specs is a clean dict without duplicates
                cleaned_product["specs"] = dict(existing_specs)
            
            # Remove empty products
            if cleaned_product["name"] and cleaned_product["price"]:
                cleaned.append(cleaned_product)
                
        except Exception as e:
            print(f"  [ERROR] Error cleaning product: {str(e)}")
            continue
    
    return cleaned
