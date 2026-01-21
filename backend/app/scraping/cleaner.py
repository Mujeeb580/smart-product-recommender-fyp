"""Data cleaning module - normalizes and cleans product data"""
import re


def extract_laptop_specs_from_name(name):
    """Extract processor, GPU, RAM, storage from laptop name"""
    specs = {}
    
    # Extract Processor - Updated patterns for modern naming schemes
    processor_patterns = [
        # Intel Core Ultra series (priority) - with "Processor" word and special chars
        r'(Intel®?\s*Core™?\s*Ultra\s+[579]\s+Processor\s+\d+\w*)',  # Intel® Core™ Ultra 7 Processor 155U
        r'(Core\s+Ultra\s+[579]-?\s*\d+\w*)',  # Core Ultra 7-256V, Core Ultra 5 125H
        r'(Intel\s*Core\s+Ultra\s+[579]-?\s*\d+\w*)',  # Intel Core Ultra 9-275HX
        r'(Ultra\s+[579]-?\s*\d+\w*)',  # Ultra 7 256V, Ultra 9-275HX
        
        # Intel Core i-series with short form (Ci with space or dash)
        r'(Ci[3579][\s-]+\w+)',  # Ci5-13420H, Ci7 14650HX, Ci5 1334U
        
        # Intel Core with "CORE" prefix (Dell style)
        r'(CORE[357]\s+\d+\w*)',  # CORE7 150U
        
        # Intel Core i-series with generation numbers like 1065G7, 1035G1
        r'(Core\s+[iI][3579]\s+\d{4}[A-Z]\d+)',  # Core i7 1065G7, Core i5 1035G1
        
        # Standard Intel Core i-series (with or without trademark symbol)
        r'(Core™?\s*[iI][3579]\s*-?\s*\d+\w+)',  # Core™ i5-1355U, Core i7-13650HX
        r'(Intel\s*Core™?\s*[iI][3579]\s*-?\s*\d+\w+)',  # Intel Core™ i9-14900HX
        
        # Intel N-series
        r'(N\d{3,4})',  # N305, N5095
        
        # AMD Ryzen short form
        r'(R[3579]-\d+\w+)',  # R5-8645HS, R9-8940HX
        
        # AMD Ryzen standard (including RYZEN uppercase, with or without trademark)
        r'(RYZEN\s*(?:AI\s*)?[3579]\s+\w+)',  # RYZEN AI 9 HX370
        r'(Ryzen™?\s*(?:AI\s*)?[3579]\s*-?\s*\d+\w*)',  # Ryzen 7-7445H, Ryzen AI 9 HX370
        r'(AMD\s*Ryzen™?\s*(?:AI\s*)?[3579]\s*-?\s*\d+\w*)',  # AMD Ryzen 5-7533HS
        
        # Intel Core 3/5/7 (new numbering without 'i') - with dash
        r'(Core™?\s+[357]\s*-\s*\d+\w*)',  # Core 7-150U, Core 3-100U
        r'(Core™?\s+[357]\s+\d+\w*)',  # Core 5 120U, Core 7 150U
        r'(Intel\s*Core™?\s+[357]\s*-?\s*\d+\w*)',  # Intel Core 7-150U, Intel® Core™ Ultra 7
        
        # Short form U7/U5/U9 (Lenovo/HP style)
        r'(U[579]-\d+\w*)',  # U7-255H
        
        # Gen-only patterns with model numbers (must be more specific)
        r'(\d+th\s*Gen\s+Core™?\s*[iI][3579]\s*-?\s*\d+\w*)',  # 13th Gen Core i7-1355U
        r'(\d+th\s*Gen\s+\d+\w+)',  # 13th Gen 1355U (without "Core")
        r'(\d+th\s*Gen\s+Core™?\s*[iI][3579])',  # 13th Gen Core i7, 12thGen Core i3
        r'(\d+th\s*Gen\s+Core\s+[357])',  # 14th Gen Core 7, 13th Gen Core 5
        r'(\d+th\s+Generation\s+Core\s+[iI][3579])',  # 13th Generation Core i9
        
        # Fallback patterns without model numbers (lower priority)
        r'(Intel®?\s*Core™?\s*Ultra\s+[579])',  # Intel® Core™ Ultra 5
        r'(Core\s+Ultra\s+[579])',  # Core Ultra 7
        r'(Ultra\s+[579])',  # Ultra 7
        r'(Core™?\s*[iI][3579])',  # Core™ i5, Core i7
        r'(AMD\s*Ryzen™?\s*[3579])',  # AMD Ryzen 7
        r'(Ryzen™?\s*[3579])',  # Ryzen 5
        r'(\d+th\s+Core\s+[357])',  # 14th Core 7
        
        # Apple Silicon
        r'(M[1-9]\d*\s*Chip)',  # M1 Chip, M4 Chip
        r'(M[1-9]\d*\s*Pro)',  # M1 Pro, M2 Pro
        r'(M[1-9]\d*\s*Max)',  # M1 Max, M2 Max
    ]
    
    for pattern in processor_patterns:
        match = re.search(pattern, name, re.IGNORECASE)
        if match:
            processor = match.group(1)
            
            # Normalize processor names
            if processor.upper().startswith('CI'):
                processor = processor.replace('Ci', 'Intel Core i').replace('CI', 'Intel Core i')
            elif processor.upper().startswith('CORE') and not processor.lower().startswith('core ultra'):
                # CORE7 150U -> Intel Core 7 150U
                processor = 'Intel ' + processor
            elif processor.startswith('R') and '-' in processor and len(processor.split('-')[0]) <= 2:
                # R5-8645HS -> AMD Ryzen 5 8645HS
                processor = processor.replace('R', 'AMD Ryzen ').replace('-', ' ')
            elif processor.startswith('U') and '-' in processor and len(processor.split('-')[0]) <= 2:
                # U7-255H -> Intel Core Ultra 7 255H
                processor = processor.replace('U', 'Intel Core Ultra ').replace('-', ' ')
            elif processor.upper().startswith('RYZEN'):
                # RYZEN AI 9 HX370 -> AMD Ryzen AI 9 HX370
                if not processor.upper().startswith('AMD'):
                    processor = 'AMD ' + processor
            
            # Clean up trademark symbols
            processor = processor.replace('™', '').replace('®', '').strip()
            
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
