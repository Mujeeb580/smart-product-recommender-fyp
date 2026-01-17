"""Clear all products from Firestore"""
from app.core.firebase import firestore_db

def clear_all_products():
    """Delete all products from the products collection"""
    try:
        products_ref = firestore_db.collection('products')
        docs = products_ref.stream()
        
        count = 0
        for doc in docs:
            doc.reference.delete()
            count += 1
            print(f"Deleted: {doc.id}")
        
        print(f"\n✓ Deleted {count} products from Firestore")
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    print("Clearing Firestore products collection...")
    clear_all_products()
