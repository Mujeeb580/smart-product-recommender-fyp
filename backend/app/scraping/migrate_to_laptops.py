from app.core.firebase import firestore_db

def migrate_products_to_laptops():
    """Migrate all documents from 'products' collection to 'laptops' collection"""
    try:
        print("=" * 60)
        print("MIGRATING PRODUCTS TO LAPTOPS COLLECTION")
        print("=" * 60)
        
        # Get all documents from products collection
        products_ref = firestore_db.collection('products')
        docs = products_ref.stream()
        
        migrated_count = 0
        for doc in docs:
            doc_data = doc.to_dict()
            doc_id = doc.id
            
            # Copy to laptops collection with same ID
            laptops_ref = firestore_db.collection('laptops').document(doc_id)
            laptops_ref.set(doc_data)
            
            migrated_count += 1
            product_name = doc_data.get('name', 'Unknown')[:50]
            print(f"[MIGRATED] {product_name}")
        
        print(f"\n✓ Total migrated: {migrated_count} products")
        print("\nNow deleting old 'products' collection...")
        
        # Delete old products collection
        docs = products_ref.stream()
        deleted_count = 0
        for doc in docs:
            doc.reference.delete()
            deleted_count += 1
            print(f"[DELETED] {doc.id}")
        
        print(f"\n✓ Total deleted from 'products': {deleted_count}")
        print("=" * 60)
        print("MIGRATION COMPLETED!")
        print("=" * 60)
        
    except Exception as e:
        print(f"[ERROR] Failed to migrate: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    migrate_products_to_laptops()
