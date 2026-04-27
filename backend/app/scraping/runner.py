from .priceoye import scrape_priceoye_phones, scrape_priceoye_laptops
from .filters import filter_products
from .cleaner import clean_products
from app.core.firebase import firestore_db
from datetime import datetime
import hashlib

def generate_product_id(product):
    """Generate a unique ID based on product name and URL to prevent duplicates"""
    # Use URL as the primary unique identifier
    unique_string = product.get('url', '') + product.get('name', '')
    return hashlib.md5(unique_string.encode()).hexdigest()

def save_products_to_firestore(products, source):
    """Save cleaned products to Firestore 'laptops' collection (prevents duplicates)"""
    try:
        saved_count = 0
        skipped_count = 0
        
        for product in products:
            try:
                # Generate unique document ID to prevent duplicates
                doc_id = generate_product_id(product)
                
                # Check if product already exists in laptops collection
                doc_ref = firestore_db.collection('laptops').document(doc_id)
                existing_doc = doc_ref.get()
                
                if existing_doc.exists:
                    print(f"[SKIP] Duplicate: {product['name'][:50]}")
                    skipped_count += 1
                    continue
                
                # Add metadata
                product['scraped_at'] = datetime.now().isoformat()
                product['source'] = source
                product['product_id'] = doc_id
                
                # Extract specs for easier querying (ensuring clean values)
                specs = product.get('specs', {})
                
                # Ensure specs is a dict (not list or other type)
                if not isinstance(specs, dict):
                    specs = {}
                
                # Clean and deduplicate spec values
                product['brand'] = specs.get('brand', 'Unknown')
                product['ram'] = specs.get('ram', 'Unknown').replace(' RAM', '').replace('RAM', '').strip()
                product['storage'] = specs.get('storage', 'Unknown').replace(' SSD', '').replace(' HDD', '').strip()
                product['processor'] = specs.get('processor', 'Unknown')
                product['gpu'] = specs.get('gpu', 'Unknown')
                product['gpu_memory'] = specs.get('gpu_memory', 'Unknown')
                
                # Remove specs field to avoid duplication
                if 'specs' in product:
                    del product['specs']
                
                # Save to laptops collection
                doc_ref.set(product)
                saved_count += 1
                
                brand = product.get('brand', 'Unknown')
                ram = product.get('ram', 'N/A')
                storage = product.get('storage', 'N/A')
                processor = product.get('processor', 'N/A')
                gpu = product.get('gpu', 'N/A')
                print(f"[SAVED] {brand} | {processor} | {gpu} | {ram} | {storage}")
                
            except Exception as e:
                print(f"[ERROR] Failed to save {product.get('name', 'Unknown')}: {str(e)}")
        
        print(f"\n✓ Saved: {saved_count} | Skipped duplicates: {skipped_count} | Total: {len(products)}")
        return saved_count
    except Exception as e:
        print(f"[ERROR] Critical error saving to Firestore: {str(e)}")
        import traceback
        traceback.print_exc()
        return 0

if __name__ == "__main__":
    print("=" * 60)
    print("SCRAPING PIPELINE - ALL LAPTOPS (307 PRODUCTS)")
    print("=" * 60)
    
    all_products = []
    
    # Scrape all laptops (no limit - will get all ~307)
    print("\n[1/4] SCRAPING ALL LAPTOPS FROM PRICEOYE...")
    print("-" * 60)
    laptops = scrape_priceoye_laptops()  # No limit = get all
    print(f"Laptops scraped: {len(laptops)}")
    all_products.extend(laptops)
    
    print(f"\n[SUMMARY] Total raw products: {len(all_products)}")
    
    # Step 2: Filter relevant products
    print("\n[2/4] FILTERING RELEVANT PRODUCTS...")
    print("-" * 60)
    filtered_products = filter_products(all_products)
    print(f"Filtered products: {len(filtered_products)}")
    
    # Step 3: Clean data
    print("\n[3/4] CLEANING DATA...")
    print("-" * 60)
    cleaned_products = clean_products(filtered_products)
    print(f"Cleaned products: {len(cleaned_products)}")
    
    # Step 4: Save to Firestore
    print("\n[4/4] SAVING TO FIRESTORE...")
    print("-" * 60)
    saved_count = save_products_to_firestore(cleaned_products, "PriceOye")
    
    # Verify saved data
    print("\n[VERIFICATION] CHECKING FIRESTORE...")
    print("-" * 60)
    try:
        products_ref = firestore_db.collection('products')
        docs = products_ref.limit(10).stream()
        
        doc_count = 0
        for doc in docs:
            doc_count += 1
            data = doc.to_dict()
            print(f"  ✓ Found: {data.get('name', 'Unknown')} ({data.get('category', 'Unknown')})")
        
        print(f"\nTotal documents in Firestore products collection: {doc_count}+")
    except Exception as e:
        print(f"[ERROR] Could not verify Firestore data: {str(e)}")
    
    print("\n" + "=" * 60)
    print("PIPELINE COMPLETED!")
    print("=" * 60)