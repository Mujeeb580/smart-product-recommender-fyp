from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
import time
import re
import os


def _decode_escaped_unicode(text):
    """Convert escaped unicode sequences like \u00ae into readable characters."""
    if not text:
        return ""

    decoded = re.sub(
        r"\\u([0-9a-fA-F]{4})",
        lambda m: chr(int(m.group(1), 16)),
        text,
    )
    return decoded.replace("\\/", "/")


def _extract_escaped_spec(page_source, pattern):
    """Extract spec values from PriceOye escaped JSON present in page source."""
    match = re.search(pattern, page_source, re.IGNORECASE)
    if not match:
        return ""

    value = match.group(1).strip()
    value = _decode_escaped_unicode(value)
    value = value.replace("\\u0026", "&").replace("\\u0027", "'").replace("\\u002F", "/")
    return value


def scrape_product_specs_mobile(driver, product_url, category):
    """Scrape mobile-specific specs from detail page including image URL."""
    try:
        driver.get(product_url)
        time.sleep(3)  # Wait for page to load
        
        specs = {}
        brand = ""
        detail_image_url = ""
        
        try:
            # Extract brand from URL
            url_parts = product_url.split('/')
            if len(url_parts) >= 3:
                brand = url_parts[-2].replace('-', ' ').title()
            
            # Primary source: data-vars-location attributes.
            spec_elements = driver.find_elements(By.CSS_SELECTOR, "[data-vars-location]")
            
            if spec_elements:
                for elem in spec_elements:
                    try:
                        location = elem.get_attribute("data-vars-location")
                        span = elem.find_element(By.CSS_SELECTOR, "span")
                        value = span.text.strip() if span else ""
                        
                        if location and value:
                            location_lower = location.lower()
                            # Capture common phone fields from semantic keys.
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
                            elif "processor" in location_lower or "chipset" in location_lower or "cpu" in location_lower:
                                specs["processor"] = value
                            elif "gpu" in location_lower or "graphics" in location_lower:
                                specs["gpu"] = value
                            elif "battery" in location_lower:
                                specs["battery"] = value
                    except Exception as e:
                        continue

            # Fallback source: specification dt/dd pairs used by PriceOye details.
            dd_specs = driver.find_elements(By.CSS_SELECTOR, "dd.spec-detail.bold")
            for dd in dd_specs:
                try:
                    spec_name = dd.find_element(By.XPATH, "./preceding-sibling::dt[1]").text.strip().lower()
                    spec_value = dd.text.strip()
                    if not spec_name or not spec_value:
                        continue

                    if "ram" in spec_name:
                        specs["ram"] = spec_value
                    elif "storage" in spec_name or "rom" in spec_name:
                        specs["storage"] = spec_value
                    elif "processor" in spec_name or "chipset" in spec_name or "cpu" in spec_name:
                        specs["processor"] = spec_value
                    elif "gpu" in spec_name or "graphics" in spec_name:
                        specs["gpu"] = spec_value
                    elif "battery" in spec_name:
                        specs["battery"] = spec_value
                except Exception:
                    continue

            # Product detail hero image.
            try:
                main_img = driver.find_element(By.CSS_SELECTOR, "img.main-product-img")
                detail_image_url = (main_img.get_attribute("src") or "").strip()
            except Exception:
                detail_image_url = ""

            # Final fallback: parse escaped specification JSON in page source.
            page_source = driver.page_source
            if not specs.get("processor"):
                specs["processor"] = _extract_escaped_spec(page_source, r"\\u0022Processor\\u0022:\\u0022(.*?)\\u0022")
            if not specs.get("processor"):
                specs["processor"] = _extract_escaped_spec(page_source, r"\\u0022Processor Type\\u0022:\\u0022(.*?)\\u0022")
            if not specs.get("processor"):
                specs["processor"] = _extract_escaped_spec(page_source, r"\\u0022Processor Model\\u0022:\\u0022(.*?)\\u0022")
            if not specs.get("processor"):
                specs["processor"] = _extract_escaped_spec(page_source, r"\\u0022CPU\\u0022:\\u0022(.*?)\\u0022")
            if not specs.get("processor"):
                specs["processor"] = _extract_escaped_spec(page_source, r"\\u0022Chipset\\u0022:\\u0022(.*?)\\u0022")
            if not specs.get("processor"):
                specs["processor"] = _extract_escaped_spec(page_source, r"\\u0022Processor Speed\\u0022:\\u0022(.*?)\\u0022")
            if not specs.get("gpu"):
                specs["gpu"] = _extract_escaped_spec(page_source, r"\\u0022GPU\\u0022:\\u0022(.*?)\\u0022")
            if not specs.get("gpu"):
                specs["gpu"] = _extract_escaped_spec(page_source, r"\\u0022Graphics\\u0022:\\u0022(.*?)\\u0022")
            if not specs.get("gpu"):
                specs["gpu"] = _extract_escaped_spec(page_source, r"\\u0022Graphics Memory\\u0022:\\u0022(.*?)\\u0022")
            if not specs.get("gpu"):
                specs["gpu"] = _extract_escaped_spec(page_source, r"\\u0022Graphic Card\\u0022:\\u0022(.*?)\\u0022")
            if not specs.get("gpu"):
                specs["gpu"] = _extract_escaped_spec(page_source, r"\\u0022Video Card\\u0022:\\u0022(.*?)\\u0022")
            if not specs.get("battery"):
                specs["battery"] = _extract_escaped_spec(page_source, r"\\u0022Battery\\u0022:\[\{\\u0022Type\\u0022:\\u0022(.*?)\\u0022")
            if not specs.get("ram"):
                specs["ram"] = _extract_escaped_spec(page_source, r"\\u0022RAM\\u0022:\\u0022(.*?)\\u0022")

            if specs.get("ram") and "-" in specs.get("storage", "") and not specs.get("storage").endswith("GB"):
                parts = specs["storage"].split("-")
                if len(parts) >= 2:
                    specs["storage"] = parts[0].strip()
                    if not specs.get("ram"):
                        specs["ram"] = parts[1].strip()
            
            # Add brand to specs
            if brand:
                specs["brand"] = brand
            
            # For Apple phones, RAM is not listed - set to "To Be Added"
            if brand.lower() in ['apple', 'iphone']:
                if 'ram' not in specs or not specs.get('ram'):
                    specs["ram"] = "To Be Added"
                
        except Exception as e:
            print(f"      Error parsing mobile specs: {str(e)}")
        
        return {
            "specs": specs,
            "image_url": detail_image_url,
        }
    except Exception as e:
        print(f"      Error getting mobile specs: {str(e)}")
        return {
            "specs": {},
            "image_url": "",
        }


def scrape_product_specs(driver, product_url, category):
    """Scrape laptop specs using the same extraction flow as mobile scraper."""
    try:
        # Reuse the mobile extractor so laptops and mobiles share the same robust selector flow.
        details = scrape_product_specs_mobile(driver, product_url, category)
        specs = details.get("specs", {}) if isinstance(details, dict) else {}
        if not isinstance(specs, dict):
            return {}

        # Laptop flow does not need battery/camera fields.
        specs.pop("battery", None)
        specs.pop("front_camera", None)
        specs.pop("back_camera", None)
        return specs
    except Exception as e:
        print(f"      Error getting specs: {str(e)}")
        return {}


def scrape_products(url, category_name, limit=None, max_pages=None):
    """Generic scraper for products with specs"""
    
    # Add options for better compatibility
    options = webdriver.ChromeOptions()
    options.add_argument('--start-maximized')
    # Show browser in real time by default; set SCRAPER_HEADLESS=1 to hide it.
    headless = os.getenv("SCRAPER_HEADLESS", "0").lower() in ("1", "true", "yes")
    if headless:
        options.add_argument('--headless=new')
    options.add_argument('--disable-gpu')
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

            if max_pages is not None and page > max_pages:
                print(f"Reached max page limit ({max_pages}) for {category_name}. Stopping scrape.")
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

                    # Extract image URL (from listing item)
                    image_url = ""
                    try:
                        img_elem = item.find_element(By.CSS_SELECTOR, "img")
                        # Try multiple attributes commonly used for lazy-loaded images
                        image_url = (
                            img_elem.get_attribute("src")
                            or img_elem.get_attribute("data-src")
                            or img_elem.get_attribute("data-original")
                            or ""
                        )
                        if image_url and not image_url.startswith("http"):
                            image_url = "https://priceoye.pk" + image_url
                    except Exception:
                        image_url = ""

                    if name and price:
                        page_products.append({
                            "name": name[:100],
                            "price": price,
                            "url": product_url,
                            "category": category_name,
                            "image_url": image_url
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
                        mobile_details = scrape_product_specs_mobile(driver, product["url"], category_name)
                        specs = mobile_details.get("specs", {}) if isinstance(mobile_details, dict) else {}
                        detail_image_url = mobile_details.get("image_url", "") if isinstance(mobile_details, dict) else ""
                        if detail_image_url:
                            product["image_url"] = detail_image_url
                    else:
                        specs = scrape_product_specs(driver, product["url"], category_name)
                    product["specs"] = specs
                    
                    # Extract important specs for display
                    ram = specs.get('ram', 'N/A')
                    storage = specs.get('storage', 'N/A')
                    brand = specs.get('brand', 'N/A')
                    processor = specs.get('processor', 'N/A')
                    gpu = specs.get('gpu', 'N/A')
                    
                    if specs:
                        if category_name == "Laptops":
                            print(f"    ✓ {brand} | CPU: {processor} | GPU: {gpu} | RAM: {ram} | Storage: {storage}")
                        else:
                            battery = specs.get('battery', 'N/A')
                            print(f"    ✓ {brand} | CPU: {processor} | GPU: {gpu} | RAM: {ram} | Battery: {battery} | Storage: {storage}")
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
    """Scrape phones from Priceoye (first 11 pages only)."""
    return scrape_products("https://priceoye.pk/mobiles", "Phones", limit, max_pages=11)


def scrape_priceoye_laptops(limit=None):
    """Scrape laptops from Priceoye (first 6 pages only)."""
    return scrape_products("https://priceoye.pk/laptops", "Laptops", limit, max_pages=6)
