import hashlib
import re
import time
from datetime import datetime
from typing import Any, Dict, List

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager

from app.core.firebase import firestore_db
from app.recommendation.processor_engine import score_product
from app.scraping.processor_normalizer import normalize_scraped_product_fields


def _generate_product_id(product: Dict[str, Any]) -> str:
    unique_name = product.get('normalized_name') or product.get('name', '')
    unique_string = f"{product.get('url', '')}{unique_name}"
    return hashlib.md5(unique_string.encode()).hexdigest()


def _extract_escaped_spec(page_source: str, pattern: str) -> str:
    match = re.search(pattern, page_source, re.IGNORECASE)
    if not match:
        return ""

    value = match.group(1).strip()
    return (
        value.replace("\\u0026", "&")
        .replace("\\u0027", "'")
        .replace("\\u002F", "/")
    )


def _parse_detail_page(driver: webdriver.Chrome, product_url: str) -> Dict[str, Any]:
    driver.get(product_url)
    time.sleep(2)

    specs: Dict[str, str] = {}

    # Primary extraction from semantic attributes.
    spec_elements = driver.find_elements(By.CSS_SELECTOR, "[data-vars-location]")
    for elem in spec_elements:
        try:
            location = (elem.get_attribute("data-vars-location") or "").strip().lower()
            text = elem.text.strip().replace("\n", " ")
            if not location or not text:
                continue

            if location == "storage":
                specs["storage"] = text
                if "-" in text:
                    parts = text.split("-")
                    if len(parts) >= 2:
                        specs["storage"] = parts[0].strip()
                        specs.setdefault("ram", parts[1].strip())
            elif location == "ram":
                specs["ram"] = text
            elif "processor" in location or "chipset" in location or "cpu" in location:
                specs["processor"] = text
            elif "gpu" in location or "graphics" in location:
                specs["gpu"] = text
            elif "battery" in location:
                specs["battery"] = text
        except Exception:
            continue

    page_source = driver.page_source

    # Fallback extraction from escaped JSON in page source.
    if not specs.get("processor"):
        specs["processor"] = _extract_escaped_spec(
            page_source, r"\\u0022Processor\\u0022:\\u0022(.*?)\\u0022"
        )
    if not specs.get("gpu"):
        specs["gpu"] = _extract_escaped_spec(
            page_source, r"\\u0022GPU\\u0022:\\u0022(.*?)\\u0022"
        )
    if not specs.get("battery"):
        specs["battery"] = _extract_escaped_spec(
            page_source,
            r"\\u0022Battery\\u0022:\[\{\\u0022Type\\u0022:\\u0022(.*?)\\u0022",
        )
    if not specs.get("ram"):
        specs["ram"] = _extract_escaped_spec(page_source, r"\\u0022RAM\\u0022:\\u0022(.*?)\\u0022")

    image_url = ""
    try:
        main_img = driver.find_element(By.CSS_SELECTOR, "img.main-product-img")
        image_url = (main_img.get_attribute("src") or "").strip()
    except Exception:
        image_url = ""

    return {
        "specs": specs,
        "image_url": image_url,
    }


def _new_driver() -> webdriver.Chrome:
    options = webdriver.ChromeOptions()
    options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option("useAutomationExtension", False)
    return webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)


def scrape_priceoye_collection(
    base_url: str,
    category_name: str,
    firestore_collection: str,
    stop_on_existing: bool = False,
    max_pages: int = 100,
) -> Dict[str, Any]:
    driver = _new_driver()

    total_seen = 0
    saved_count = 0
    updated_count = 0
    existing_hits = 0
    stopped_on_existing = False

    try:
        for page in range(1, max_pages + 1):
            page_url = f"{base_url}?page={page}"
            driver.get(page_url)
            time.sleep(2)

            cards = driver.find_elements(By.CSS_SELECTOR, ".productBox")
            if not cards:
                break

            for card in cards:
                try:
                    name = card.find_element(By.CSS_SELECTOR, ".p-title").text.strip()
                    price = card.find_element(By.CSS_SELECTOR, ".price-box span").text.strip()
                    product_url = card.find_element(By.CSS_SELECTOR, "a").get_attribute("href")

                    image_url = ""
                    try:
                        img = card.find_element(By.CSS_SELECTOR, "img")
                        image_url = (
                            img.get_attribute("src")
                            or img.get_attribute("data-src")
                            or img.get_attribute("data-original")
                            or ""
                        ).strip()
                    except Exception:
                        image_url = ""

                    if not name or not price or not product_url:
                        continue

                    product = {
                        "name": name[:100],
                        "price": price,
                        "url": product_url,
                        "category": category_name,
                        "image_url": image_url,
                    }

                    product["raw_name"] = product["name"]
                    normalized_snapshot = normalize_scraped_product_fields(product)
                    normalized_name = normalized_snapshot.get("name", "")
                    if normalized_name:
                        product["normalized_name"] = normalized_name
                        product["name"] = normalized_name

                    doc_id = _generate_product_id(product)
                    doc_ref = firestore_db.collection(firestore_collection).document(doc_id)
                    existing_doc = doc_ref.get()

                    if existing_doc.exists and stop_on_existing:
                        existing_hits += 1
                        stopped_on_existing = True
                        break

                    details = _parse_detail_page(driver, product_url)
                    specs = details.get("specs", {}) if isinstance(details, dict) else {}
                    detail_image = details.get("image_url", "") if isinstance(details, dict) else ""
                    if detail_image:
                        product["image_url"] = detail_image

                    product["scraped_at"] = datetime.now().isoformat()
                    product["source"] = "PriceOye"
                    product["product_id"] = doc_id
                    product["category"] = category_name

                    normalized = normalize_scraped_product_fields(product)
                    product["normalized_name"] = normalized["name"]
                    product["brand"] = normalized["brand"]
                    product["ram"] = normalized["ram"]
                    product["storage"] = normalized["storage"]
                    product["processor"] = normalized["processor"]
                    product["gpu"] = normalized["gpu"]
                    product["battery"] = normalized["battery"]
                    product["gpu_memory"] = normalized["gpu_memory"]
                    product["image_url"] = normalized["image_url"] or product.get("image_url", "")
                    product["price_numeric"] = normalized["price_numeric"]

                    score_info = score_product(product)
                    product["device_score"] = float(score_info.get("score", 0.0))
                    product["device_tier"] = score_info.get("tier", "Unknown")
                    product["normalized_processor"] = score_info.get("normalized_processor", "Unknown")
                    product["performance_breakdown"] = score_info.get("breakdown", {})
                    product["score_specs"] = score_info.get("specs", {})
                    product["score_type"] = score_info.get("score_type", "unknown")

                    if existing_doc.exists:
                        doc_ref.set(product, merge=True)
                        updated_count += 1
                    else:
                        doc_ref.set(product)
                        saved_count += 1

                    total_seen += 1
                except Exception:
                    continue

            if stopped_on_existing:
                break

        return {
            "collection": firestore_collection,
            "category": category_name,
            "total_seen": total_seen,
            "saved": saved_count,
            "updated": updated_count,
            "existing_hits": existing_hits,
            "stopped_on_existing": stopped_on_existing,
        }
    finally:
        driver.quit()


def scrape_phones(stop_on_existing: bool = False) -> Dict[str, Any]:
    return scrape_priceoye_collection(
        base_url="https://priceoye.pk/mobiles",
        category_name="Phones",
        firestore_collection="phones",
        stop_on_existing=stop_on_existing,
    )


def scrape_laptops(stop_on_existing: bool = False) -> Dict[str, Any]:
    return scrape_priceoye_collection(
        base_url="https://priceoye.pk/laptops",
        category_name="Laptops",
        firestore_collection="laptops",
        stop_on_existing=stop_on_existing,
    )
