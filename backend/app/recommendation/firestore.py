import firebase_admin
from firebase_admin import credentials, firestore
from typing import List, Dict
import os

# Global Firestore client
_db = None

def get_firestore_client():
    """
    Initialize and return Firestore client.
    Uses singleton pattern to avoid multiple initializations.
    """
    global _db
    if _db is None:
        # Initialize Firebase (assumes credentials already exist)
        if not firebase_admin._apps:
            default_path = os.path.abspath(
                os.path.join(os.path.dirname(__file__), "../../firebase-key.json")
            )
            env_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
            cred_path = os.path.abspath(env_path) if env_path else default_path
            if not os.path.exists(cred_path):
                raise FileNotFoundError(f"firebase-key.json not found at {cred_path}")
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
        _db = firestore.client()
    return _db

def fetch_products(collection_name: str = "products") -> List[Dict]:
    """
    Fetch all products from Firestore collection.
    
    Args:
        collection_name: Name of the Firestore collection
        
    Returns:
        List of product dictionaries
    """
    db = get_firestore_client()
    products = []
    
    print(f"Fetching products from '{collection_name}' collection...")
    docs = db.collection(collection_name).stream()
    
    for doc in docs:
        product = doc.to_dict()
        product['id'] = doc.id  # Add document ID
        products.append(product)
    
    print(f"Fetched {len(products)} products.")
    return products