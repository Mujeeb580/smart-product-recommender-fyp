from .priceoye import scrape_priceoye_phones
from .filters import filter_products
from .cleaner import clean_products
from app.core.firebase import firestore_db
from datetime import datetime
import hashlib


def generate_product_id(product):
    """Generate a unique ID based on product name and URL to prevent duplicates"""
    unique_string = product.get('url', '') + product.get('name', '')
    return hashlib.md5(unique_string.encode()).hexdigest()


def save_products_to_firestore(products, source):
    """Save cleaned products to Firestore 'phones' collection with upsert updates."""
    try:
        saved_count = 0
        updated_count = 0
        
        for product in products:
            try:
                # Generate unique document ID to prevent duplicates
                doc_id = generate_product_id(product)
                
                # Check if product already exists in phones collection
                doc_ref = firestore_db.collection('phones').document(doc_id)
                existing_doc = doc_ref.get()
                
                # Add metadata
                product['scraped_at'] = datetime.now().isoformat()
                product['source'] = source
                product['product_id'] = doc_id
                
                # Extract specs for mobile (name, price, model, storage, ram)
                specs = product.get('specs', {})
                
                # Ensure specs is a dict (not list or other type)
                if not isinstance(specs, dict):
                    specs = {}
                
                # Clean and deduplicate spec values for mobile phones
                product['brand'] = specs.get('brand', 'Unknown')
                product['ram'] = specs.get('ram', 'Unknown').replace(' RAM', '').replace('RAM', '').strip()
                product['storage'] = specs.get('storage', 'Unknown').replace(' SSD', '').replace(' HDD', '').strip()
                product['processor'] = specs.get('processor', 'Unknown').strip()
                product['gpu'] = specs.get('gpu', 'Unknown').strip()
                product['battery'] = specs.get('battery', 'Unknown').strip()
                product['image_url'] = product.get('image_url', '').strip()
                
                # Remove specs field to avoid duplication
                if 'specs' in product:
                    del product['specs']
                
                # Upsert to phones collection: create new docs and update existing docs.
                if existing_doc.exists:
                    doc_ref.set(product, merge=True)
                    updated_count += 1
                else:
                    doc_ref.set(product)
                    saved_count += 1
                
                brand = product.get('brand', 'Unknown')
                ram = product.get('ram', 'N/A')
                storage = product.get('storage', 'N/A')
                processor = product.get('processor', 'N/A')
                gpu = product.get('gpu', 'N/A')
                battery = product.get('battery', 'N/A')
                state = 'UPDATED' if existing_doc.exists else 'SAVED'
                print(f"[{state}] {brand} | CPU: {processor} | GPU: {gpu} | RAM: {ram} | Battery: {battery} | Storage: {storage}")
                
            except Exception as e:
                print(f"[ERROR] Failed to save {product.get('name', 'Unknown')}: {str(e)}")
        
        print(f"\n✓ Saved: {saved_count} | Updated: {updated_count} | Total: {len(products)}")
        return saved_count
    except Exception as e:
        print(f"[ERROR] Critical error saving to Firestore: {str(e)}")
        import traceback
        traceback.print_exc()
        return 0


if __name__ == "__main__":
    print("=" * 60)
    print("SCRAPING PIPELINE - ALL MOBILES")
    print("=" * 60)
    
    all_products = []
    
    # Scrape all mobiles (high limit to get all available phones)
    print("\n[1/5] SCRAPING ALL MOBILES FROM PRICEOYE...")
    print("-" * 60)
    mobiles = scrape_priceoye_phones(limit=1000)
    print(f"Mobiles scraped: {len(mobiles)}")
    all_products.extend(mobiles)
    
    print(f"\n[SUMMARY] Total raw products: {len(all_products)}")
    
    # Step 2: Filter by price (exclude phones under Rs. 15000)
    print("\n[2/4] FILTERING BY PRICE (Rs. 15000+)...")
    print("-" * 60)
    price_filtered = []
    for product in all_products:
        price_str = product.get('price', '').replace('Rs', '').replace(',', '').strip()
        try:
            price = int(price_str)
            if price >= 15000:
                price_filtered.append(product)
            else:
                print(f"[SKIP] {product['name'][:40]} - Price: Rs. {price:,} (below threshold)")
        except:
            price_filtered.append(product)  # Keep if price can't be parsed
    print(f"After price filter: {len(price_filtered)}")
    
    # Step 3: Filter relevant products
    print("\n[3/4] FILTERING RELEVANT PRODUCTS...")
    print("-" * 60)
    filtered_products = filter_products(price_filtered)
    print(f"Filtered products: {len(filtered_products)}")
    
    # Step 4: Clean data
    print("\n[4/4] CLEANING DATA...")
    print("-" * 60)
    cleaned_products = clean_products(filtered_products)
    print(f"Cleaned products: {len(cleaned_products)}")
    
    # Step 5: Save to Firestore
    print("\n[5/5] SAVING TO FIRESTORE...")
    print("-" * 60)
    saved_count = save_products_to_firestore(cleaned_products, "PriceOye")
    
    print("\n" + "=" * 60)
    print("PIPELINE COMPLETED!")
    print("=" * 60)
