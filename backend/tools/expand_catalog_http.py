"""Expand Firestore with live catalog data using plain HTTP requests.

This avoids Selenium/ChromeDriver so it can run in restricted environments
where the browser driver cannot be downloaded.
"""

from __future__ import annotations

import html
import hashlib
import re
import os
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional

import requests

from app.core.firebase import firestore_db
from app.scraping.processor_normalizer import normalize_scraped_product_fields


USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
TIMEOUT = 25
SCORE_PRODUCTS = os.getenv("SCORE_PRODUCTS", "0").lower() in {"1", "true", "yes"}
score_product = None

if SCORE_PRODUCTS:
    from app.recommendation.processor_engine import score_product as _score_product

    score_product = _score_product


def _clean_text(value: Any) -> str:
    text = html.unescape(re.sub(r"\s+", " ", str(value or "").replace("\xa0", " ")))
    return re.sub(r"<[^>]+>", " ", text).strip()


def _strip_tags(value: str) -> str:
    return _clean_text(re.sub(r"(?is)<(script|style).*?>.*?</\\1>", " ", value))


def _generate_product_id(product: Dict[str, Any]) -> str:
    unique_name = product.get("normalized_name") or product.get("name", "")
    unique_string = f"{product.get('url', '')}{unique_name}"
    return hashlib.md5(unique_string.encode()).hexdigest()


def _request(url: str, session: requests.Session) -> Optional[str]:
    try:
        response = session.get(url, timeout=TIMEOUT, headers={"User-Agent": USER_AGENT})
        if response.status_code != 200:
            return None
        return response.text
    except Exception as exc:
        print(f"[HTTP ERR] {url}: {exc}")
        return None


def _extract_meta(html_text: str, prop: str) -> str:
    patterns = [
        rf'<meta[^>]+property="{re.escape(prop)}"[^>]+content="([^"]+)"',
        rf"<meta[^>]+property='{re.escape(prop)}'[^>]+content='([^']+)'",
        rf'<meta[^>]+name="{re.escape(prop)}"[^>]+content="([^"]+)"',
        rf"<meta[^>]+name='{re.escape(prop)}'[^>]+content='([^']+)'",
    ]
    for pattern in patterns:
        match = re.search(pattern, html_text, re.IGNORECASE | re.DOTALL)
        if match:
            return html.unescape(match.group(1)).strip()
    return ""


def _extract_plain_text_after_label(text: str, label: str) -> str:
    pattern = rf"{re.escape(label)}\s*[:\-]?\s*([^,\n\r<]+)"
    match = re.search(pattern, text, re.IGNORECASE)
    return _clean_text(match.group(1)) if match else ""


def _extract_first(patterns: Iterable[str], text: str) -> str:
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE | re.DOTALL)
        if match:
            return _clean_text(match.group(1))
    return ""


def _save_product(product: Dict[str, Any], collection: str) -> Dict[str, Any]:
    product = dict(product)
    product["raw_name"] = product.get("raw_name") or product.get("name", "")
    normalized_snapshot = normalize_scraped_product_fields(product)
    normalized_name = normalized_snapshot.get("name", "")
    if normalized_name:
        product["normalized_name"] = normalized_name
        product["name"] = normalized_name

    doc_id = _generate_product_id(product)
    doc_ref = firestore_db.collection(collection).document(doc_id)
    existing = doc_ref.get()

    product["product_id"] = doc_id
    product["scraped_at"] = __import__("datetime").datetime.now().isoformat()
    product["category"] = product.get("category") or ("Phones" if collection == "phones" else "Laptops")

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

    if SCORE_PRODUCTS:
        score_info = score_product(product)
        product["device_score"] = float(score_info.get("score", 0.0))
        product["device_tier"] = score_info.get("tier", "Unknown")
        product["normalized_processor"] = score_info.get("normalized_processor", "Unknown")
        product["performance_breakdown"] = score_info.get("breakdown", {})
        product["score_specs"] = score_info.get("specs", {})
        product["score_type"] = score_info.get("score_type", "unknown")
    else:
        product["device_score"] = float(product.get("device_score", 0.0) or 0.0)
        product["device_tier"] = product.get("device_tier", "Unknown")
        product["normalized_processor"] = product.get("normalized_processor", product.get("processor", "Unknown"))
        product["performance_breakdown"] = product.get("performance_breakdown", {})
        product["score_specs"] = product.get("score_specs", {})
        product["score_type"] = product.get("score_type", "unknown")

    if existing.exists:
        doc_ref.set(product, merge=True)
        return {"saved": 0, "updated": 1, "existing": True}

    doc_ref.set(product)
    return {"saved": 1, "updated": 0, "existing": False}


def _priceoye_listing_cards(html_text: str) -> List[Dict[str, str]]:
    cards: List[Dict[str, str]] = []
    for match in re.finditer(
        r'<div class="productBox[^"]*">.*?<a href="(?P<url>[^"]+)".*?<h4 class="p-title[^"]*">(?P<name>.*?)</h4>.*?<div class="price-box[^"]*"><span><sup>Rs</sup>\s*(?P<price>[^<]+)</span>',
        html_text,
        re.IGNORECASE | re.DOTALL,
    ):
        cards.append(
            {
                "url": html.unescape(match.group("url")).strip(),
                "name": _strip_tags(match.group("name")),
                "price": f"Rs {_clean_text(match.group('price'))}",
            }
        )
    return cards


def _priceoye_detail_specs(html_text: str) -> Dict[str, str]:
    specs: Dict[str, str] = {}
    patterns = {
        "processor": [
            r"\\u0022Processor\\u0022:\\u0022(.*?)\\u0022",
            r"\\u0022Processor Type\\u0022:\\u0022(.*?)\\u0022",
            r"\\u0022Processor Model\\u0022:\\u0022(.*?)\\u0022",
            r"\\u0022CPU\\u0022:\\u0022(.*?)\\u0022",
            r"\\u0022Chipset\\u0022:\\u0022(.*?)\\u0022",
        ],
        "gpu": [
            r"\\u0022GPU\\u0022:\\u0022(.*?)\\u0022",
            r"\\u0022Graphics\\u0022:\\u0022(.*?)\\u0022",
            r"\\u0022Graphic Card\\u0022:\\u0022(.*?)\\u0022",
        ],
        "battery": [
            r"\\u0022Battery\\u0022:\[\{\\u0022Type\\u0022:\\u0022(.*?)\\u0022",
        ],
        "ram": [
            r"\\u0022RAM\\u0022:\\u0022(.*?)\\u0022",
        ],
        "storage": [
            r"\\u0022Internal Memory\\u0022:\\u0022(.*?)\\u0022",
            r"\\u0022Storage\\u0022:\\u0022(.*?)\\u0022",
        ],
    }

    for field, field_patterns in patterns.items():
        for pattern in field_patterns:
            value = _extract_first([pattern], html_text)
            if value:
                specs[field] = value
                break

    if not specs.get("brand"):
        title = _extract_meta(html_text, "og:title")
        if title:
            specs["brand"] = title.split(" ", 1)[0]

    return specs


def scrape_priceoye(
    category: str,
    base_url: str,
    collection: str,
    max_pages: int = 100,
    max_products: int = 0,
) -> Dict[str, Any]:
    session = requests.Session()
    total_seen = saved = updated = errors = 0
    seen_urls: set[str] = set()

    for page in range(1, max_pages + 1):
        url = f"{base_url}?page={page}"
        print(f"[PriceOye] page {page}: fetching listing", flush=True)
        page_html = _request(url, session)
        if not page_html:
            break

        cards = _priceoye_listing_cards(page_html)
        print(f"[PriceOye] page {page}: {len(cards)} cards", flush=True)
        if not cards:
            break

        for card in cards:
            if max_products > 0 and total_seen >= max_products:
                break
            if card["url"] in seen_urls:
                continue
            seen_urls.add(card["url"])

            print(f"[PriceOye] detail fetch: {card['name']}", flush=True)
            detail_html = _request(card["url"], session)
            if not detail_html:
                errors += 1
                continue

            specs = _priceoye_detail_specs(detail_html)
            name = _extract_meta(detail_html, "og:title") or card["name"]
            image_url = _extract_meta(detail_html, "og:image")
            if not image_url:
                match = re.search(r'<img[^>]+class="[^"]*main-product-img[^"]*"[^>]+src="([^"]+)"', detail_html, re.IGNORECASE)
                if match:
                    image_url = html.unescape(match.group(1)).strip()

            product = {
                "name": name,
                "raw_name": card["name"],
                "price": card["price"],
                "url": card["url"],
                "image_url": image_url,
                "category": category,
                "specs": specs,
                "source": "PriceOye",
            }

            try:
                print(f"[PriceOye] save: {product['name']}", flush=True)
                result = _save_product(product, collection)
                total_seen += 1
                saved += int(result["saved"])
                updated += int(result["updated"])
                print(f"[PriceOye] saved={saved} updated={updated}", flush=True)
            except Exception as exc:
                errors += 1
                print(f"[SAVE ERR] {card['name']}: {exc}")

    return {
        "source": "PriceOye",
        "collection": collection,
        "category": category,
        "total_seen": total_seen,
        "saved": saved,
        "updated": updated,
        "errors": errors,
    }


def _shophive_listing_cards(html_text: str) -> List[Dict[str, str]]:
    cards: List[Dict[str, str]] = []
    for match in re.finditer(
        r'<div class="product-item-info".*?<a href="(?P<url>[^"]+)"[^>]*class="product photo product-item-photo".*?alt="(?P<name>[^"]+)".*?data-price-amount="(?P<amount>[0-9]+)"',
        html_text,
        re.IGNORECASE | re.DOTALL,
    ):
        cards.append(
            {
                "url": html.unescape(match.group("url")).strip(),
                "name": _clean_text(match.group("name")),
                "price": f"Rs {int(match.group('amount')):,}",
            }
        )
    return cards


def _shophive_detail_specs(html_text: str) -> Dict[str, str]:
    specs: Dict[str, str] = {}
    description = _extract_meta(html_text, "og:description")
    title = _extract_meta(html_text, "og:title") or _clean_text(re.search(r"<title>(.*?)</title>", html_text, re.IGNORECASE | re.DOTALL).group(1) if re.search(r"<title>(.*?)</title>", html_text, re.IGNORECASE | re.DOTALL) else "")

    if title:
        specs["brand"] = title.split(" ", 1)[0]

    if description:
        specs["processor"] = _extract_first(
            [
                r"(Intel Core[^,\.]+Processor)",
                r"(AMD Ryzen[^,\.]+Processor)",
                r"(Intel Core[^,\.]+)",
                r"(AMD Ryzen[^,\.]+)",
            ],
            description,
        )
        specs["gpu"] = _extract_first(
            [
                r"(Nvidia RTX[^,\.]+Graphics)",
                r"(NVIDIA GeForce[^,\.]+Graphics)",
                r"(Intel UHD Graphics[^,\.]*)",
                r"(AMD Radeon Graphics[^,\.]*)",
                r"(Nvidia RTX[^,\.]+)",
                r"(NVIDIA GeForce[^,\.]+)",
                r"(Intel UHD Graphics[^,\.]*)",
                r"(AMD Radeon Graphics[^,\.]*)",
            ],
            description,
        )
        specs["ram"] = _extract_first([r"(\d+\s*GB)\s*RAM"], description)
        specs["storage"] = _extract_first([r"(\d+\s*(?:TB|GB)\s*(?:SSD|HDD|M2 SSD))"], description)

    return specs


def scrape_shophive_laptops(
    base_url: str,
    collection: str,
    max_pages: int = 100,
    max_products: int = 0,
) -> Dict[str, Any]:
    session = requests.Session()
    total_seen = saved = updated = errors = 0
    seen_urls: set[str] = set()

    for page in range(1, max_pages + 1):
        page_url = base_url if page == 1 else f"{base_url}?p={page}"
        print(f"[Shophive] page {page}: fetching listing", flush=True)
        page_html = _request(page_url, session)
        if not page_html:
            break

        cards = _shophive_listing_cards(page_html)
        print(f"[Shophive] page {page}: {len(cards)} cards", flush=True)
        if not cards:
            break

        for card in cards:
            if max_products > 0 and total_seen >= max_products:
                break
            if card["url"] in seen_urls:
                continue
            seen_urls.add(card["url"])

            print(f"[Shophive] detail fetch: {card['name']}", flush=True)
            detail_html = _request(card["url"], session)
            if not detail_html:
                errors += 1
                continue

            specs = _shophive_detail_specs(detail_html)
            image_url = _extract_meta(detail_html, "og:image")
            price_text = _extract_meta(detail_html, "product:price:amount")
            price = f"Rs {int(float(price_text)):,}" if price_text else card["price"]
            name = _extract_meta(detail_html, "og:title") or card["name"]

            product = {
                "name": name,
                "raw_name": card["name"],
                "price": price,
                "url": card["url"],
                "image_url": image_url,
                "category": "Laptops",
                "specs": specs,
                "source": "Shophive",
            }

            try:
                print(f"[Shophive] save: {product['name']}", flush=True)
                result = _save_product(product, collection)
                total_seen += 1
                saved += int(result["saved"])
                updated += int(result["updated"])
                print(f"[Shophive] saved={saved} updated={updated}", flush=True)
            except Exception as exc:
                errors += 1
                print(f"[SAVE ERR] {card['name']}: {exc}")

    return {
        "source": "Shophive",
        "collection": collection,
        "category": "Laptops",
        "total_seen": total_seen,
        "saved": saved,
        "updated": updated,
        "errors": errors,
    }


def main() -> None:
    runs = []
    runs.append(scrape_priceoye("Phones", "https://priceoye.pk/mobiles", "phones"))
    runs.append(scrape_priceoye("Laptops", "https://priceoye.pk/laptops", "laptops"))
    runs.append(scrape_shophive_laptops("https://www.shophive.com/laptops-computers/laptops", "laptops"))

    print("\nSUMMARY")
    for run in runs:
        print(run)

    print(
        {
            "phones_total": sum(r["total_seen"] for r in runs if r["collection"] == "phones"),
            "laptops_total": sum(r["total_seen"] for r in runs if r["collection"] == "laptops"),
            "saved": sum(r["saved"] for r in runs),
            "updated": sum(r["updated"] for r in runs),
            "errors": sum(r["errors"] for r in runs),
        }
    )


if __name__ == "__main__":
    main()
