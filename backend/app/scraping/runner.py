from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time


def scrape_daraz_phones():
    url = "https://www.daraz.pk/smartphones/"
    
    # Add options for better compatibility
    options = webdriver.ChromeOptions()
    options.add_argument('--start-maximized')
    options.add_argument('--disable-blink-features=AutomationControlled')
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option('useAutomationExtension', False)
    
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    
    try:
        print("Opening Daraz URL...")
        driver.get(url)
        
        print("Waiting for page to load...")
        time.sleep(10)  # Increased wait time
        
        products = []
        
        # Try to find product items with multiple selectors
        items = driver.find_elements(By.CSS_SELECTOR, ".Bm3ON")
        print(f"Found {len(items)} items with selector .Bm3ON")
        
        # If not found, try alternative selectors
        if len(items) == 0:
            items = driver.find_elements(By.CSS_SELECTOR, "[data-qa-locator*='product']")
            print(f"Found {len(items)} items with alternative selector")
        
        if len(items) == 0:
            print("No product items found!")
            
        for i, item in enumerate(items[:15]):
            try:
                # Extract name from link title attribute
                name_link = item.find_element(By.CSS_SELECTOR, ".RfADt a")
                name = name_link.get_attribute("title") or name_link.text
                
                # Extract price - this selector still works
                price_elem = item.find_element(By.CSS_SELECTOR, ".aBrP0")
                price = price_elem.text

                if name and price:
                    products.append({
                        "name": name[:100],
                        "price": price,
                        "category": "Phone",
                        "source": "Daraz"
                    })
                    print(f"  {i+1}. {name[:60]}... - {price}")
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

if __name__ == "__main__":
    result = scrape_daraz_phones()
    print(result)