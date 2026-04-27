from app.core.firebase import firestore_db

def clear_mobile_products():
    """Delete all mobile products from 'phones' collection in Firestore"""
    try:
        print("=" * 60)
        print("DELETING ALL MOBILE PRODUCTS FROM DATABASE")
        print("=" * 60)
        
        # Query all documents in phones collection
        products_ref = firestore_db.collection('phones')
        docs = products_ref.stream()
        
        deleted_count = 0
        for doc in docs:
            doc.reference.delete()
            deleted_count += 1
            product_name = doc.to_dict().get('name', 'Unknown')[:50] if doc.to_dict() else 'Unknown'
            print(f"[DELETED] {product_name}")
        
        print(f"\n✓ Total deleted: {deleted_count} mobile products")
        print("=" * 60)
        
    except Exception as e:
        print(f"[ERROR] Failed to delete mobile products: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    clear_mobile_products()
