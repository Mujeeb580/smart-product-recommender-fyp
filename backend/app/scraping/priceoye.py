from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time


def scrape_product_specs_mobile(driver, product_url, category):
    """Scrape mobile-specific specs: brand, storage, RAM only"""
    try:
        driver.get(product_url)
        time.sleep(3)  # Wait for page to load
        
        specs = {}
        brand = ""
        
        try:
            # Extract brand from URL
            url_parts = product_url.split('/')
            if len(url_parts) >= 3:
                brand = url_parts[-2].replace('-', ' ').title()
            
            # Look for data-vars-location attributes - for mobiles only extract storage/ram
            spec_elements = driver.find_elements(By.CSS_SELECTOR, "[data-vars-location]")
            
            if spec_elements:
                for elem in spec_elements:
                    try:
                        location = elem.get_attribute("data-vars-location")
                        span = elem.find_element(By.CSS_SELECTOR, "span")
                        value = span.text.strip() if span else ""
                        
                        if location and value:
                            location_lower = location.lower()
                            # For phones: only extract storage and RAM
                            if location_lower == "storage":
                                specs["storage"] = value
                                # Parse storage and RAM from combined value like "256GB-8GB" (storage-ram)
                                if "-" in value:
                                    parts = value.split("-")
                                    if len(parts) >= 2:
                                        specs["storage"] = parts[0].strip()
                                        specs["ram"] = parts[1].strip()
                            elif location_lower == "ram":
                                specs["ram"] = value
                    except Exception as e:
                        continue
            
            # Add brand to specs
            if brand:
                specs["brand"] = brand
                
        except Exception as e:
            print(f"      Error parsing mobile specs: {str(e)}")
        
        return specs
    except Exception as e:
        print(f"      Error getting mobile specs: {str(e)}")


def scrape_product_specs(driver, product_url, category):
    """Scrape detailed specifications from individual product page"""
    try:
        driver.get(product_url)
        time.sleep(3)  # Wait for page to load
        
        specs = {}
        brand = ""
        model = ""
        
        try:
            # Extract brand and model from URL
            url_parts = product_url.split('/')
            if len(url_parts) >= 3:
                brand = url_parts[-2].replace('-', ' ').title()
                model = url_parts[-1].replace('-', ' ').title()
            
            # Look for data-vars-location attributes which contain spec categories
            spec_elements = driver.find_elements(By.CSS_SELECTOR, "[data-vars-location]")
            
            if spec_elements:
                print(f"      Found {len(spec_elements)} spec elements")
                
                for elem in spec_elements:
                    try:
                        # Get the location/category name
                        location = elem.get_attribute("data-vars-location")
                        
                        # Get the text value from span inside
                        span = elem.find_element(By.CSS_SELECTOR, "span")
                        value = span.text.strip() if span else ""
                        
                        if location and value:
                            # Normalize location names
                            location_lower = location.lower()
                            if location_lower == "storage":
                                specs["storage"] = value
                                # Parse storage and RAM from combined value
                                if "-" in value:
                                    parts = value.split("-")
                                    if len(parts) >= 2:
                                        specs["storage"] = parts[0].strip()
                                        specs["ram"] = parts[1].strip()
                            elif location_lower == "ram":
                                specs["ram"] = value
                            elif "processor" in location_lower or "cpu" in location_lower:
                                specs["processor"] = value
                            elif "display" in location_lower or "screen" in location_lower:
                                specs["display"] = value
                            elif "battery" in location_lower:
                                specs["battery"] = value
                            elif "camera" in location_lower:
                                if "front" in location_lower or "selfie" in location_lower:
                                    specs["front_camera"] = value
                                else:
                                    specs["back_camera"] = value
                    except Exception as e:
                        continue
            
            # Add brand and model to specs
            if brand:
                specs["brand"] = brand
            if model:
                specs["model"] = model
                
        except Exception as e:
            print(f"      Error parsing specs: {str(e)}")
        
        return specs
    except Exception as e:
        print(f"      Error getting specs: {str(e)}")
        return {}


def scrape_products(url, category_name, limit=None):
    """Generic scraper for products with specs"""
    
    # Add options for better compatibility
    options = webdriver.ChromeOptions()
    options.add_argument('--start-maximized')
    options.add_argument('--disable-blink-features=AutomationControlled')
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option('useAutomationExtension', False)
    
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    
    try:
        products = []
        page = 1
        
        while True:
            # If limit is None, keep going until no more products. Otherwise check limit
            if limit and len(products) >= limit:
                break
            
            page_url = f"{url}?page={page}"
            print(f"\n📄 Scraping {category_name} - Page {page}...")
            
            driver.get(page_url)
            time.sleep(3)  # Wait for page to load
            
            # Find product items
            items = driver.find_elements(By.CSS_SELECTOR, ".productBox")
            
            if len(items) == 0:
                print(f"No more products found on page {page}. Stopping scrape.")
                break
            
            print(f"Found {len(items)} items on page {page}")
            
            # Extract all product data from listing page first
            page_products = []
            for i, item in enumerate(items):
                # Stop if we have enough products (if limit is set)
                if limit and len(products) + len(page_products) >= limit:
                    break
                    
                try:
                    # Extract name
                    name_elem = item.find_element(By.CSS_SELECTOR, ".p-title")
                    name = name_elem.text.strip()
                    
                    # Extract price
                    price_elem = item.find_element(By.CSS_SELECTOR, ".price-box span")
                    price = price_elem.text.strip()
                    
                    # Extract product URL
                    product_link = item.find_element(By.CSS_SELECTOR, "a")
                    product_url = product_link.get_attribute("href")
                    if not product_url.startswith("http"):
                        product_url = "https://priceoye.pk" + product_url

                    if name and price:
                        page_products.append({
                            "name": name[:100],
                            "price": price,
                            "url": product_url,
                            "category": category_name
                        })
                        print(f"  [{len(products)+len(page_products):3d}] {name[:50]:50s} - {price:15s}")
                        
                except Exception as e:
                    print(f"  Error extracting item {i+1}: {str(e)}")
                    continue
            
            # Now scrape specs for each product from this page
            print(f"  Fetching specs for {len(page_products)} products...")
            for product in page_products:
                try:
                    # Use mobile-specific scraper for phones, full scraper for laptops
                    if category_name == "Phones":
                        specs = scrape_product_specs_mobile(driver, product["url"], category_name)
                    else:
                        specs = scrape_product_specs(driver, product["url"], category_name)
                    product["specs"] = specs
                    
                    # Extract important specs for display
                    ram = specs.get('ram', 'N/A')
                    storage = specs.get('storage', 'N/A')
                    brand = specs.get('brand', 'N/A')
                    
                    if specs:
                        print(f"    ✓ {brand} | RAM: {ram} | Storage: {storage}")
                    else:
                        print(f"    ✗ NO specs found for {product['name'][:40]}")
                except Exception as e:
                    print(f"    Error getting specs: {str(e)}")
                    product["specs"] = {}
                    continue
            
            # Add page products to main list
            products.extend(page_products)
            
            page += 1
        
        print(f"\n✓ Total {category_name} scraped: {len(products)}")
        return products
        
    except Exception as e:
        print(f"Error during scraping: {str(e)}")
        return []
    
    finally:
        driver.quit()


def scrape_priceoye_phones(limit=None):
    """Scrape phones from Priceoye"""
    return scrape_products("https://priceoye.pk/mobiles", "Phones", limit)


def scrape_priceoye_laptops(limit=None):
    """Scrape laptops from Priceoye"""
    return scrape_products("https://priceoye.pk/laptops", "Laptops", limit)
