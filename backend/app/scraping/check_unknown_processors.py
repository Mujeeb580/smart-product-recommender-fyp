from app.core.firebase import firestore_db

def check_unknown_processors():
    """Find and analyze laptops with Unknown processor"""
    try:
        print("=" * 80)
        print("FINDING LAPTOPS WITH UNKNOWN PROCESSORS")
        print("=" * 80)
        
        # Query laptops with processor = "Unknown"
        laptops_ref = firestore_db.collection('laptops')
        query = laptops_ref.where('processor', '==', 'Unknown')
        docs = query.stream()
        
        unknown_count = 0
        for doc in docs:
            data = doc.to_dict()
            unknown_count += 1
            
            name = data.get('name', 'N/A')
            url = data.get('url', 'N/A')
            brand = data.get('brand', 'N/A')
            
            print(f"\n[{unknown_count}] {name}")
            print(f"    Brand: {brand}")
            print(f"    URL: {url}")
            print(f"    All fields:")
            for key, value in data.items():
                if key not in ['scraped_at', 'source', 'product_id', 'url']:
                    print(f"      {key}: {value}")
        
        print(f"\n{'=' * 80}")
        print(f"Total laptops with Unknown processor: {unknown_count}")
        print("=" * 80)
        
        if unknown_count > 0:
            print("\n💡 Analysis:")
            print("Check if processor info is in the product name but not matching regex patterns")
            print("Or if specs weren't scraped from product pages correctly")
        
    except Exception as e:
        print(f"[ERROR] Failed to query: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    check_unknown_processors()
