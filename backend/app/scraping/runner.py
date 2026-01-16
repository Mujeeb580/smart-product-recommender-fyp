from priceoye import scrape_priceoye_phones

if __name__ == "__main__":
    print("=== Scraping PriceOye ===")
    priceoye_products = scrape_priceoye_phones()
    
    print(f"\n=== Total Products: {len(priceoye_products)} ===")
    print(priceoye_products)