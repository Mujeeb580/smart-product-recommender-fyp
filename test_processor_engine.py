"""
Test script for processor_engine integration with backend API.
Tests all new endpoints and processor scoring functionality.
"""

import requests
import json
import time
from typing import List, Dict

BASE_URL = "http://127.0.0.1:8000"

def test_phones_performance():
    """Test /products/phones/performance endpoint"""
    print("\n" + "="*70)
    print("TEST: GET /products/phones/performance")
    print("="*70)
    
    try:
        # Test with default parameters
        url = f"{BASE_URL}/products/phones/performance"
        response = requests.get(url, timeout=30)
        data = response.json()
        
        print(f"Status: {response.status_code}")
        print(f"Products returned: {data.get('count', 0)}")
        
        if data.get("products"):
            for i, phone in enumerate(data["products"][:3], 1):
                print(f"\n  [{i}] {phone.get('name', 'Unknown')}")
                print(f"      Price: {phone.get('price', 'N/A')}")
                print(f"      Processor: {phone.get('normalized_processor', 'Unknown')}")
                print(f"      Tier: {phone.get('processor_tier', 'Unknown')}")
                print(f"      Score: {phone.get('processor_score', 'N/A')}")
        
        return response.status_code == 200
    
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False


def test_phones_by_score():
    """Test /products/phones/performance with min_score filter"""
    print("\n" + "="*70)
    print("TEST: GET /products/phones/performance?min_score=0.8")
    print("="*70)
    
    try:
        url = f"{BASE_URL}/products/phones/performance?min_score=0.8&limit=10"
        response = requests.get(url, timeout=30)
        data = response.json()
        
        print(f"Status: {response.status_code}")
        print(f"High-end phones (score >= 0.8): {data.get('count', 0)}")
        
        if data.get("products"):
            for phone in data["products"][:2]:
                print(f"  - {phone.get('name')[:40]}: {phone.get('processor_score')}")
        
        return response.status_code == 200
    
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False


def test_phones_by_tier():
    """Test /products/phones/by-tier endpoint"""
    print("\n" + "="*70)
    print("TEST: GET /products/phones/by-tier?tier=Flagship")
    print("="*70)
    
    try:
        for tier in ["Flagship", "Upper Mid", "Mid", "Low"]:
            url = f"{BASE_URL}/products/phones/by-tier?tier={tier}&limit=5"
            response = requests.get(url, timeout=30)
            data = response.json()
            
            count = data.get('count', 0)
            print(f"\n  Tier '{tier}': {count} phones")
            
            if data.get("products"):
                for phone in data["products"][:2]:
                    print(f"    - {phone.get('name')[:35]}: {phone.get('processor_score')}")
        
        return True
    
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False


def test_phone_score_details():
    """Test /products/phones/score-details endpoint"""
    print("\n" + "="*70)
    print("TEST: POST /products/phones/score-details")
    print("="*70)
    
    try:
        # First get a product
        url = f"{BASE_URL}/products/phones/performance?limit=1"
        response = requests.get(url, timeout=30)
        products = response.json().get("products", [])
        
        if not products:
            print("❌ No phones available to test")
            return False
        
        product_id = products[0].get("id")
        
        # Now test score details
        url = f"{BASE_URL}/products/phones/score-details?product_id={product_id}"
        response = requests.post(url, timeout=30)
        data = response.json()
        
        print(f"Status: {response.status_code}")
        if "product" in data:
            product = data["product"]
            print(f"\nProduct: {product.get('name')}")
            print(f"  Processor: {product.get('processor')}")
            print(f"  RAM: {product.get('ram')}")
            print(f"  Battery: {product.get('battery')}")
            
            score = data.get("score", {})
            print(f"\nScore Details:")
            print(f"  Overall: {score.get('overall')}")
            print(f"  Tier: {score.get('tier')}")
            print(f"  Breakdown: {score.get('breakdown')}")
        
        return response.status_code == 200
    
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False


def test_recommend_with_processor():
    """Test recommendations with processor scoring"""
    print("\n" + "="*70)
    print("TEST: GET /products/recommend (with processor scores)")
    print("="*70)
    
    try:
        queries = [
            "best flagship phone",
            "budget phone under 50000",
            "phone with good battery",
        ]
        
        for query in queries:
            url = f"{BASE_URL}/products/recommend?query={query}&top_n=3&collection=phones"
            response = requests.get(url, timeout=30)
            data = response.json()
            
            print(f"\n  Query: '{query}'")
            print(f"  Results: {data.get('count', 0)}")
            
            for phone in data.get("products", [])[:2]:
                print(f"    - {phone.get('name')[:35]}")
                print(f"      Processor Score: {phone.get('processor_score', 'N/A')}")
                print(f"      Similarity: {phone.get('similarity_score', 'N/A')}")
        
        return True
    
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False


def test_chat_with_processor_scores():
    """Test chat endpoint with processor scores"""
    print("\n" + "="*70)
    print("TEST: POST /chat/send-message (processor scores)")
    print("="*70)
    
    try:
        messages = [
            "i want flagship phone with best performance",
            "best phone under 100k",
            "phone with 12gb ram",
        ]
        
        for msg in messages:
            url = f"{BASE_URL}/chat/send-message"
            response = requests.post(
                url,
                json={"message": msg},
                timeout=30
            )
            data = response.json()
            
            print(f"\n  User: '{msg}'")
            print(f"  Bot Reply: {data.get('reply', 'No reply')[:100]}...")
            print(f"  Products: {len(data.get('products', []))} found")
            
            for phone in data.get("products", [])[:1]:
                score = phone.get("processor_score")
                print(f"    - {phone.get('name')[:35]} (Score: {score})")
        
        return True
    
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False


def run_all_tests():
    """Run all tests and summarize results"""
    print("\n\n")
    print("█" * 70)
    print("  PROCESSOR ENGINE BACKEND INTEGRATION TEST SUITE")
    print("█" * 70)
    
    tests = [
        ("Phones by Performance", test_phones_performance),
        ("Phones with Min Score Filter", test_phones_by_score),
        ("Phones by Tier", test_phones_by_tier),
        ("Phone Score Details", test_phone_score_details),
        ("Recommendations with Scores", test_recommend_with_processor),
        ("Chat with Processor Scores", test_chat_with_processor_scores),
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            success = test_func()
            results.append((test_name, success))
            time.sleep(1)  # Small delay between tests
        except Exception as e:
            print(f"\n❌ Test '{test_name}' crashed: {str(e)}")
            results.append((test_name, False))
    
    # Summary
    print("\n\n" + "="*70)
    print("TEST SUMMARY")
    print("="*70)
    
    passed = sum(1 for _, success in results if success)
    total = len(results)
    
    for test_name, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status:8} | {test_name}")
    
    print("="*70)
    print(f"Total: {passed}/{total} tests passed ({100*passed//total}%)")
    print("="*70 + "\n")
    
    return passed == total


if __name__ == "__main__":
    print("Starting test suite...")
    print(f"Target: {BASE_URL}")
    time.sleep(1)
    
    all_passed = run_all_tests()
    exit(0 if all_passed else 1)
