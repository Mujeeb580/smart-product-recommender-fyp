import hashlib
import re
import time
from datetime import datetime
from typing import Any, Callable, Dict, Iterable, List, Optional, Sequence

from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from webdriver_manager.chrome import ChromeDriverManager

from app.core.firebase import firestore_db
from app.recommendation.processor_engine import score_product
from app.scraping.processor_normalizer import normalize_scraped_product_fields

ListingFilter = Callable[[str, str], bool]

_PHONE_INCLUSION_HINTS = (
    "iphone",
    "galaxy",
    "pixel",
    "redmi",
    "poco",
    "vivo",
    "oppo",
    "realme",
    "infinix",
    "tecno",
    "honor",
    "huawei",
    "nothing phone",
    "oneplus",
    "dcode",
    "sparx",
    "itel",
    "nokia",
    "motorola",
    "xiaomi",
    "phone",
)

_PHONE_EXCLUSION_HINTS = (
    "charger",
    "cable",
    "case",
    "cover",
    "gimbal",
    "tripod",
    "power bank",
    "holder",
    "adapter",
    "screen protector",
    "earbud",
    "headphone",
    "watch",
    "tablet",
    "laptop",
    "camera",
    "speaker",
    "drone",
)

_LAPTOP_INCLUSION_HINTS = (
    "laptop",
    "notebook",
    "chromebook",
    "macbook",
    "thinkpad",
    "vostro",
    "victus",
    "zenbook",
    "vivobook",
    "probook",
    "spectre",
    "legion",
    "predator",
    "swift",
    "extensa",
    "aspire",
    "inspiron",
    "latitude",
    "xps",
    "elitebook",
    "probook",
    "workstation",
    "gaming laptop",
)

_LAPTOP_EXCLUSION_HINTS = (
    "mouse",
    "keyboard",
    "bag",
    "cable",
    "charger",
    "adapter",
    "cooler",
    "stand",
    "dock",
    "power bank",
    "headphone",
    "speaker",
    "screen protector",
)


def _generate_product_id(product: Dict[str, Any]) -> str:
    unique_name = product.get("normalized_name") or product.get("name", "")
    unique_string = f"{product.get('url', '')}{unique_name}"
    return hashlib.md5(unique_string.encode()).hexdigest()


def _new_driver() -> webdriver.Chrome:
    options = webdriver.ChromeOptions()
    options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option("useAutomationExtension", False)
    return webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)


def _clean_text(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "").replace("\xa0", " ")).strip()


def _first_nonempty_text(element, selectors: Sequence[str]) -> str:
    for selector in selectors:
        try:
            found = element.find_element(By.CSS_SELECTOR, selector)
            text = _clean_text(getattr(found, "text", ""))
            if text:
                return text
        except Exception:
            continue
    return ""


def _first_href(element, selectors: Sequence[str]) -> str:
    for selector in selectors:
        try:
            found = element.find_element(By.CSS_SELECTOR, selector)
            href = _clean_text(found.get_attribute("href"))
            if href:
                return href
        except Exception:
            continue
    return ""


def _first_image_url(element, selectors: Sequence[str]) -> str:
    for selector in selectors:
        try:
            found = element.find_element(By.CSS_SELECTOR, selector)
            for attribute in ("src", "data-src", "data-original"):
                value = _clean_text(found.get_attribute(attribute))
                if value:
                    return value
        except Exception:
            continue
    return ""


def _extract_price(text: str) -> str:
    matches = re.findall(r"(?:Rs\.?|PKR)\s*([0-9][0-9,]*(?:\.[0-9]+)?)", text, re.IGNORECASE)
    if not matches:
        return ""
    return f"Rs {matches[0]}"


def _is_phone_name(name: str) -> bool:
    text = name.lower()
    if any(hint in text for hint in _PHONE_EXCLUSION_HINTS):
        return False
    return any(hint in text for hint in _PHONE_INCLUSION_HINTS)


def _is_laptop_name(name: str) -> bool:
    text = name.lower()
    if any(hint in text for hint in _LAPTOP_EXCLUSION_HINTS):
        return False
    return any(hint in text for hint in _LAPTOP_INCLUSION_HINTS) or bool(
        re.search(r"\b(?:core|ryzen|snapdragon)\b.*\b(?:ssd|ram|gb)\b", text)
    )


def _looks_like_real_product(name: str, category_name: str, listing_filter: Optional[ListingFilter]) -> bool:
    if listing_filter:
        return listing_filter(name, category_name)

    category = category_name.lower()
    if "phone" in category or "mobile" in category:
        return _is_phone_name(name)
    if "laptop" in category or "notebook" in category:
        return _is_laptop_name(name)
    return True


def _normalize_label(label: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", _clean_text(label).lower()).strip()


def _assign_spec(specs: Dict[str, str], label: str, value: str) -> None:
    normalized_label = _normalize_label(label)
    normalized_value = _clean_text(value)
    if not normalized_label or not normalized_value:
        return

    if "brand" in normalized_label:
        specs.setdefault("brand", normalized_value)
    elif "ram" in normalized_label or "memory" in normalized_label:
        specs["ram"] = normalized_value
    elif any(token in normalized_label for token in ("storage", "ssd", "hdd", "rom", "internal memory", "internal storage", "hard disk")):
        specs["storage"] = normalized_value
    elif any(token in normalized_label for token in ("processor", "cpu", "chipset", "soc")):
        specs["processor"] = normalized_value
    elif any(token in normalized_label for token in ("gpu", "graphics", "video card")):
        specs["gpu"] = normalized_value
    elif "battery" in normalized_label:
        specs["battery"] = normalized_value
    elif "screen" in normalized_label or "display" in normalized_label:
        specs.setdefault("screen", normalized_value)
    elif "camera" in normalized_label:
        specs.setdefault("camera", normalized_value)


def _parse_row_text(text: str, specs: Dict[str, str]) -> None:
    line = _clean_text(text)
    if not line:
        return

    if "|" in line:
        parts = [_clean_text(part) for part in line.split("|") if _clean_text(part)]
        if len(parts) >= 2:
            _assign_spec(specs, parts[0], parts[-1])
            return

    if ":" in line:
        label, value = line.split(":", 1)
        _assign_spec(specs, label, value)
        return

    for label in (
        "Brand",
        "RAM",
        "Storage",
        "Internal Storage",
        "Internal Memory",
        "Memory",
        "Processor",
        "Processor Type",
        "CPU",
        "Chipset",
        "GPU",
        "Graphics",
        "Battery",
        "Display",
        "Screen",
        "Camera",
    ):
        if line.lower().startswith(label.lower() + " "):
            _assign_spec(specs, label, line[len(label) :].strip())
            return


def _extract_specs_from_page(driver: webdriver.Chrome, category_name: str) -> Dict[str, str]:
    specs: Dict[str, str] = {}

    try:
        body_text = driver.find_element(By.TAG_NAME, "body").text
        for line in body_text.splitlines():
            _parse_row_text(line, specs)
    except Exception:
        pass

    # Structured rows often contain cleaner values than the free-form body text.
    for selector in (
        "table tr",
        "dl",
        ".specification tr",
        ".product.attribute",
        ".product-specs tr",
    ):
        try:
            rows = driver.find_elements(By.CSS_SELECTOR, selector)
        except Exception:
            rows = []
        for row in rows:
            try:
                row_text = _clean_text(row.text)
                if row_text:
                    _parse_row_text(row_text, specs)

                cells = [cell.text.strip() for cell in row.find_elements(By.CSS_SELECTOR, "th, td, dt, dd, span") if _clean_text(cell.text)]
                if len(cells) >= 2:
                    _assign_spec(specs, cells[0], cells[-1])
            except Exception:
                continue

    if not specs.get("brand"):
        try:
            title = _clean_text(
                driver.find_element(By.CSS_SELECTOR, "h1").text
                or driver.find_element(By.CSS_SELECTOR, "meta[property='og:title']").get_attribute("content")
            )
            if title:
                specs["brand"] = title.split(" ", 1)[0]
        except Exception:
            pass

    try:
        image = driver.find_element(By.CSS_SELECTOR, "img.main-product-img, img.product-image-photo, meta[property='og:image']")
        if image.tag_name.lower() == "meta":
            image_url = _clean_text(image.get_attribute("content"))
        else:
            image_url = _clean_text(image.get_attribute("src") or image.get_attribute("data-src"))
    except Exception:
        image_url = ""

    return {"specs": specs, "image_url": image_url}


def _extract_listing_products(
    driver: webdriver.Chrome,
    category_name: str,
    listing_filter: Optional[ListingFilter] = None,
) -> List[Dict[str, Any]]:
    candidates: List[Any] = []
    for selector in (
        ".product-item-info",
        "li.product-item",
        ".product-item",
        ".productBox",
        ".product",
    ):
        try:
            candidates.extend(driver.find_elements(By.CSS_SELECTOR, selector))
        except Exception:
            continue

    products: List[Dict[str, Any]] = []
    seen_urls: set[str] = set()

    for candidate in candidates:
        try:
            name = _first_nonempty_text(
                candidate,
                (
                    ".product-item-link",
                    ".p-title",
                    "h2",
                    "h3",
                    "a[title]",
                    "a",
                ),
            )
            if not name:
                continue

            url = _first_href(
                candidate,
                (
                    ".product-item-link",
                    ".p-title a",
                    "a[href]",
                ),
            )
            if not url or url in seen_urls:
                continue

            if not _looks_like_real_product(name, category_name, listing_filter):
                continue

            price_text = _first_nonempty_text(
                candidate,
                (
                    ".special-price .price",
                    ".price-box .price",
                    ".price",
                    ".regular-price .price",
                ),
            )
            if not price_text:
                price_text = _extract_price(candidate.text)
            if not price_text:
                continue

            image_url = _first_image_url(
                candidate,
                (
                    "img.product-image-photo",
                    "img",
                ),
            )

            products.append(
                {
                    "name": name[:150],
                    "price": _extract_price(price_text),
                    "url": url,
                    "image_url": image_url,
                    "category": category_name,
                }
            )
            seen_urls.add(url)
        except Exception:
            continue

    return products


def _build_page_url(base_url: str, page: int, page_param: str) -> str:
    if page <= 1:
        return base_url

    separator = "&" if "?" in base_url else "?"
    return f"{base_url}{separator}{page_param}={page}"


def _save_product(
    product: Dict[str, Any],
    firestore_collection: str,
    source_name: str,
    stop_on_existing: bool,
) -> Dict[str, Any]:
    product = dict(product)
    driver = product.pop("driver", None)
    product["raw_name"] = product.get("raw_name") or product.get("name", "")

    normalized_snapshot = normalize_scraped_product_fields(product)
    normalized_name = normalized_snapshot.get("name", "")
    if normalized_name:
        product["normalized_name"] = normalized_name
        product["name"] = normalized_name

    doc_id = _generate_product_id(product)
    doc_ref = firestore_db.collection(firestore_collection).document(doc_id)
    existing_doc = doc_ref.get()

    if existing_doc.exists and stop_on_existing:
        return {"skipped": True, "existing": True, "doc_id": doc_id}

    if driver is None:
        raise ValueError("A browser driver is required to scrape the detail page")

    details = _extract_specs_from_page(driver, product["category"])
    specs = details.get("specs", {}) if isinstance(details, dict) else {}
    if not isinstance(specs, dict):
        specs = {}

    specs.setdefault("brand", product["name"].split(" ", 1)[0])
    product["specs"] = specs

    detail_image = details.get("image_url", "") if isinstance(details, dict) else ""
    if detail_image:
        product["image_url"] = detail_image

    product["scraped_at"] = datetime.now().isoformat()
    product["source"] = source_name
    product["source_site"] = source_name
    product["product_id"] = doc_id

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
        return {"saved": 0, "updated": 1, "existing": True, "doc_id": doc_id}

    doc_ref.set(product)
    return {"saved": 1, "updated": 0, "existing": False, "doc_id": doc_id}


def scrape_marketplace_collection(
    *,
    base_url: str,
    category_name: str,
    firestore_collection: str,
    source_name: str,
    page_param: str = "page",
    stop_on_existing: bool = False,
    max_pages: int = 100,
    max_products: int = 0,
    listing_filter: Optional[ListingFilter] = None,
) -> Dict[str, Any]:
    driver = _new_driver()

    total_seen = 0
    saved_count = 0
    updated_count = 0
    existing_hits = 0
    stopped_on_existing = False
    error_count = 0
    last_error = ""

    try:
        for page in range(1, max_pages + 1):
            if max_products > 0 and total_seen >= max_products:
                break

            page_url = _build_page_url(base_url, page, page_param)
            driver.get(page_url)
            time.sleep(2)

            page_products = _extract_listing_products(driver, category_name, listing_filter=listing_filter)
            if not page_products:
                break

            for product in page_products:
                if max_products > 0 and total_seen >= max_products:
                    break

                try:
                    product["driver"] = driver
                    result = _save_product(
                        product,
                        firestore_collection=firestore_collection,
                        source_name=source_name,
                        stop_on_existing=stop_on_existing,
                    )

                    if result.get("existing"):
                        existing_hits += 1
                        if stop_on_existing:
                            stopped_on_existing = True
                            break

                    saved_count += int(result.get("saved", 0))
                    updated_count += int(result.get("updated", 0))
                    total_seen += 1
                except Exception as exc:
                    error_count += 1
                    last_error = f"{product.get('name', 'Unknown')}: {exc}"

            if stopped_on_existing:
                break

        return {
            "collection": firestore_collection,
            "category": category_name,
            "source": source_name,
            "total_seen": total_seen,
            "saved": saved_count,
            "updated": updated_count,
            "existing_hits": existing_hits,
            "stopped_on_existing": stopped_on_existing,
            "errors": error_count,
            "last_error": last_error,
        }
    finally:
        driver.quit()


def scrape_shophive_phones(
    stop_on_existing: bool = False,
    max_pages: int = 100,
    max_products: int = 0,
) -> Dict[str, Any]:
    return scrape_marketplace_collection(
        base_url="https://www.shophive.com/mobile-phones",
        category_name="Phones",
        firestore_collection="phones",
        source_name="Shophive",
        page_param="p",
        stop_on_existing=stop_on_existing,
        max_pages=max_pages,
        max_products=max_products,
    )


def scrape_shophive_laptops(
    stop_on_existing: bool = False,
    max_pages: int = 100,
    max_products: int = 0,
) -> Dict[str, Any]:
    return scrape_marketplace_collection(
        base_url="https://www.shophive.com/laptops-computers/laptops",
        category_name="Laptops",
        firestore_collection="laptops",
        source_name="Shophive",
        page_param="p",
        stop_on_existing=stop_on_existing,
        max_pages=max_pages,
        max_products=max_products,
    )


def scrape_ishopping_phones(
    stop_on_existing: bool = False,
    max_pages: int = 100,
    max_products: int = 0,
) -> Dict[str, Any]:
    return scrape_marketplace_collection(
        base_url="https://www.ishopping.pk/mobiles",
        category_name="Phones",
        firestore_collection="phones",
        source_name="iShopping",
        page_param="p",
        stop_on_existing=stop_on_existing,
        max_pages=max_pages,
        max_products=max_products,
    )


def scrape_ishopping_laptops(
    stop_on_existing: bool = False,
    max_pages: int = 100,
    max_products: int = 0,
) -> Dict[str, Any]:
    featured = scrape_marketplace_collection(
        base_url="https://www.ishopping.pk/laptops/featured",
        category_name="Laptops",
        firestore_collection="laptops",
        source_name="iShopping",
        page_param="p",
        stop_on_existing=stop_on_existing,
        max_pages=max_pages,
        max_products=max_products,
    )
    preowned = scrape_marketplace_collection(
        base_url="https://www.ishopping.pk/pre-owned/pre-owned-laptops",
        category_name="Laptops",
        firestore_collection="laptops",
        source_name="iShopping",
        page_param="p",
        stop_on_existing=stop_on_existing,
        max_pages=max_pages,
        max_products=max_products,
    )
    return {
        "collection": "laptops",
        "category": "Laptops",
        "source": "iShopping",
        "total_seen": int(featured.get("total_seen", 0)) + int(preowned.get("total_seen", 0)),
        "saved": int(featured.get("saved", 0)) + int(preowned.get("saved", 0)),
        "updated": int(featured.get("updated", 0)) + int(preowned.get("updated", 0)),
        "existing_hits": int(featured.get("existing_hits", 0)) + int(preowned.get("existing_hits", 0)),
        "stopped_on_existing": bool(featured.get("stopped_on_existing")) or bool(preowned.get("stopped_on_existing")),
        "errors": int(featured.get("errors", 0)) + int(preowned.get("errors", 0)),
        "runs": [featured, preowned],
        "sources": ["iShopping"],
        "last_error": featured.get("last_error") or preowned.get("last_error") or "",
    }
