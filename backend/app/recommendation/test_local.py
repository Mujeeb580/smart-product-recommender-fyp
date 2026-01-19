# backend/app/recommendation/test_local.py

from service import get_recommendations

products = [
    {
        "name": "itel P55 Plus",
        "brand": "Itel",
        "price": "Rs 26,999",
        "ram": "8GB",
        "storage": "256GB",
        "category": "Phones",
        "source": "PriceOye"
    },
    {
        "name": "Samsung Galaxy A15",
        "brand": "Samsung",
        "price": "Rs 38,999",
        "ram": "6GB",
        "storage": "128GB",
        "category": "Phones",
        "source": "PriceOye"
    },
    {
        "name": "HP Laptop 15S i3 12th Gen",
        "brand": "HP",
        "price": "Rs 107,999",
        "ram": "4GB",
        "storage": "256GB",
        "category": "Laptops",
        "source": "PriceOye"
    }
]

query = "best phone under 30k for daily use"

results = get_recommendations(query, products)

for r in results:
    print(r["name"], "→", r["similarity_score"])
