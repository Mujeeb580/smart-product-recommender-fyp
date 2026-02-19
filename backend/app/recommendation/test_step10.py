from .firestore import fetch_products
from .engine import recommend_products

def main():
    """
    Test the recommendation engine locally.
    """
    print("=" * 60)
    print("STEP 10: Recommendation Engine Test")
    print("=" * 60)
    
    # Hardcoded test query (Pakistani user intent)
    query = "best phone under 30k for daily use"
    
    print(f"\nUser Query: '{query}'")
    print("-" * 60)
    
    # Fetch products from Firestore
    # Try 'phones' collection first, fallback to 'products'
    try:
        products = fetch_products("phones")
        if not products:
            print("No products in 'phones' collection, trying 'products'...")
            products = fetch_products("products")
    except Exception as e:
        print(f"Error fetching from 'phones': {e}")
        print("Trying 'products' collection...")
        products = fetch_products("products")
    
    if not products:
        print("\n❌ No products found in Firestore!")
        return
    
    # Filter products under 30k (since price is now numeric)
    filtered_products = [p for p in products if isinstance(p.get('price'), (int, float)) and p.get('price') <= 30000]
    print(f"Filtered to {len(filtered_products)} products under Rs 30,000")
    
    # Run recommendation engine
    print(f"\nRunning recommendation engine on {len(filtered_products)} products...")
    recommendations = recommend_products(query, filtered_products, top_n=10)
    
    # Print results
    print("\n" + "=" * 60)
    print("TOP RECOMMENDATIONS")
    print("=" * 60)
    
    for i, product in enumerate(recommendations, 1):
        print(f"\n{i}. {product.get('name', 'Unknown Product')}")
        print(f"   Brand: {product.get('brand', 'N/A')}")
        print(f"   RAM: {product.get('ram', 'N/A')}")
        print(f"   Storage: {product.get('storage', 'N/A')}")
        print(f"   Price: {product.get('price', 'N/A')}")
        print(f"   Similarity Score: {product['similarity_score']:.4f}")
    
    print("\n" + "=" * 60)
    print("Test completed successfully!")
    print("=" * 60)

if __name__ == "__main__":
    main()