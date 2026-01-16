from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time


def scrape_phone_specs(driver, product_url):
    """Scrape detailed specifications from individual product page"""
    try:
        driver.get(product_url)
        time.sleep(3)  # Wait for page to load
        
        specs = {}
        
        # Try to find specifications table or list
        try:
            spec_items = driver.find_elements(By.CSS_SELECTOR, ".spec-item, .specification-item, tr")
            for spec_item in spec_items:
                try:
                    # Try different patterns for spec name and value
                    spec_name = spec_item.find_element(By.CSS_SELECTOR, ".spec-name, .spec-key, td:first-child, th").text.strip()
                    spec_value = spec_item.find_element(By.CSS_SELECTOR, ".spec-value, td:last-child").text.strip()
                    
                    if spec_name and spec_value:
                        # Extract common specs
                        if "ram" in spec_name.lower():
                            specs["ram"] = spec_value
                        elif "storage" in spec_name.lower() or "memory" in spec_name.lower() or "rom" in spec_name.lower():
                            specs["storage"] = spec_value
                        elif "camera" in spec_name.lower() and "back" in spec_name.lower():
                            specs["back_camera"] = spec_value
                        elif "camera" in spec_name.lower() and "front" in spec_name.lower():
                            specs["front_camera"] = spec_value
                        elif "battery" in spec_name.lower():
                            specs["battery"] = spec_value
                        elif "screen" in spec_name.lower() or "display" in spec_name.lower():
                            specs["display"] = spec_value
                        elif "processor" in spec_name.lower() or "chipset" in spec_name.lower():
                            specs["processor"] = spec_value
                except:
                    continue
        except:
            pass
        
        return specs
    except Exception as e:
        print(f"    Error getting specs: {str(e)}")
        return {}


def scrape_priceoye_phones():
    url = "https://priceoye.pk/mobiles"
    
    # Add options for better compatibility
    options = webdriver.ChromeOptions()
    options.add_argument('--start-maximized')
    options.add_argument('--disable-blink-features=AutomationControlled')
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option('useAutomationExtension', False)
    
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    
    try:
        print("Opening PriceOye URL...")
        driver.get(url)
        
        print("Waiting for page to load...")
        time.sleep(10)  # Wait for page to load
        
        # Save page source for debugging
        with open("priceoye_debug.html", "w", encoding="utf-8") as f:
            f.write(driver.page_source)
        print("Page source saved to priceoye_debug.html")
        
        products = []
        
        # Try to find product items with multiple selectors
        items = driver.find_elements(By.CSS_SELECTOR, ".productBox")
        print(f"Found {len(items)} items with selector .productBox")
        
        # If not found, try alternative selectors
        if len(items) == 0:
            items = driver.find_elements(By.CSS_SELECTOR, ".product-card")
            print(f"Found {len(items)} items with alternative selector .product-card")
        
        if len(items) == 0:
            items = driver.find_elements(By.CSS_SELECTOR, "[class*='product']")
            print(f"Found {len(items)} items with generic product selector")
        
        if len(items) == 0:
            print("No product items found!")
            
        for i, item in enumerate(items[:15]):
            try:
                # Extract name from .p-title h4 or h5
                name_elem = item.find_element(By.CSS_SELECTOR, ".p-title")
                name = name_elem.text.strip()
                
                # Extract price from .price-box span
                price_elem = item.find_element(By.CSS_SELECTOR, ".price-box span")
                price = price_elem.text.strip()
                
                # Extract product URL
                product_link = item.find_element(By.CSS_SELECTOR, "a")
                product_url = product_link.get_attribute("href")
                if not product_url.startswith("http"):
                    product_url = "https://priceoye.pk" + product_url

                if name and price:
                    print(f"  {i+1}. {name[:60]}... - {price}")
                    print(f"    Getting specs from: {product_url}")
                    
                    # Get detailed specifications
                    specs = scrape_phone_specs(driver, product_url)
                    
                    product_data = {
                        "name": name[:100],
                        "price": price,
                        "category": "Phone",
                        "source": "PriceOye",
                        "url": product_url,
                        "specs": specs
                    }
                    
                    products.append(product_data)
                    print(f"    Specs: {specs}")
                    
                    # Go back to main listing page
                    driver.back()
                    time.sleep(2)
                    
            except Exception as e:
                print(f"  Error extracting item {i+1}: {str(e)}")
                continue
        
        print(f"\nTotal products scraped: {len(products)}")
        return products
        
    except Exception as e:
        print(f"Error during scraping: {str(e)}")
        return []
    
    finally:
        driver.quit()
