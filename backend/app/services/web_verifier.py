"""Lightweight live-web verification for top-ranked products."""

from __future__ import annotations

import os
import re
import time
from concurrent.futures import ThreadPoolExecutor
from threading import RLock
from typing import Any, Dict, List, Optional, Tuple

import requests


USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
)
_VERIFICATION_CACHE: Dict[str, Tuple[float, Dict[str, Any]]] = {}
_VERIFICATION_CACHE_LOCK = RLock()


def _env_float(name: str, default: float, minimum: float = 0.0) -> float:
    try:
        return max(minimum, float(os.getenv(name, str(default))))
    except ValueError:
        return default


def _copy_result(result: Dict[str, Any]) -> Dict[str, Any]:
    copied = dict(result)
    copied["signals"] = dict(result.get("signals") or {})
    return copied


def _verification_cache_key(product: Dict[str, Any]) -> str:
    return "|".join(
        _clean_text(product.get(field))
        for field in ("url", "normalized_name", "name", "brand")
    )


def _cached_verification(product: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    key = _verification_cache_key(product)
    with _VERIFICATION_CACHE_LOCK:
        cached = _VERIFICATION_CACHE.get(key)
        if not cached:
            return None
        timestamp, result = cached
        ttl = _env_float("WEB_VERIFICATION_CACHE_TTL_SECONDS", 600.0)
        if str(result.get("reason", "")).startswith("fetch_failed"):
            ttl = min(ttl, 30.0)
        if time.monotonic() - timestamp >= ttl:
            _VERIFICATION_CACHE.pop(key, None)
            return None
        return _copy_result(result)


def _cache_verification(product: Dict[str, Any], result: Dict[str, Any]) -> None:
    key = _verification_cache_key(product)
    with _VERIFICATION_CACHE_LOCK:
        if len(_VERIFICATION_CACHE) >= 512:
            oldest_key = min(_VERIFICATION_CACHE, key=lambda item: _VERIFICATION_CACHE[item][0])
            _VERIFICATION_CACHE.pop(oldest_key, None)
        _VERIFICATION_CACHE[key] = (time.monotonic(), _copy_result(result))


def _clean_text(value: Any) -> str:
    text = str(value or "")
    text = re.sub(r"\s+", " ", text)
    return text.strip().lower()


def _extract_tag_content(html: str, pattern: str) -> str:
    match = re.search(pattern, html, re.IGNORECASE | re.DOTALL)
    if not match:
        return ""
    return re.sub(r"\s+", " ", match.group(1)).strip()


def _extract_page_signals(html: str) -> Dict[str, str]:
    return {
        "title": _extract_tag_content(html, r"<title[^>]*>(.*?)</title>"),
        "og_title": _extract_tag_content(
            html,
            r'<meta[^>]+property=["\']og:title["\'][^>]+content=["\'](.*?)["\']',
        ),
        "description": _extract_tag_content(
            html,
            r'<meta[^>]+name=["\']description["\'][^>]+content=["\'](.*?)["\']',
        ),
    }


def verify_product_against_web(
    product: Dict[str, Any], timeout_seconds: Optional[float] = None
) -> Dict[str, Any]:
    cached = _cached_verification(product)
    if cached is not None:
        return cached

    if timeout_seconds is None:
        timeout_seconds = _env_float("WEB_VERIFICATION_TIMEOUT_SECONDS", 2.5, 0.1)
    url = str(product.get("url") or "").strip()
    normalized_name = _clean_text(product.get("normalized_name") or product.get("name") or "")
    brand = _clean_text(product.get("brand") or "")

    result: Dict[str, Any] = {
        "url": url,
        "name": product.get("name", ""),
        "normalized_name": product.get("normalized_name", product.get("name", "")),
        "verified": False,
        "confidence": 0.0,
        "signals": {},
        "reason": "",
    }

    if not url:
        result["reason"] = "missing_url"
        return result

    try:
        response = requests.get(
            url,
            timeout=timeout_seconds,
            headers={"User-Agent": USER_AGENT},
        )
        response.raise_for_status()
        html = response.text or ""
        signals = _extract_page_signals(html)
        title_text = _clean_text(signals.get("title") or signals.get("og_title"))
        description_text = _clean_text(signals.get("description"))
        page_text = f"{title_text} {description_text} {_clean_text(html[:15000])}"

        tokens = [token for token in normalized_name.split() if len(token) > 2]
        brand_hit = bool(brand and brand in page_text)
        name_hits = sum(1 for token in tokens if token in page_text)
        title_hits = sum(1 for token in tokens if token in title_text)

        confidence = 0.0
        if brand_hit:
            confidence += 0.25
        if tokens:
            confidence += min(0.45, name_hits / max(len(tokens), 1) * 0.35)
            confidence += min(0.2, title_hits / max(len(tokens), 1) * 0.2)
        if title_text:
            confidence += 0.1

        confidence = max(0.0, min(confidence, 1.0))
        result.update(
            {
                "verified": confidence >= 0.45,
                "confidence": round(confidence, 2),
                "signals": signals,
                "reason": "matched_live_page" if confidence >= 0.45 else "weak_live_match",
            }
        )
        _cache_verification(product, result)
        return result
    except Exception as exc:
        result["reason"] = f"fetch_failed:{exc.__class__.__name__}"
        _cache_verification(product, result)
        return result


def build_verification_context(query: str, products: List[Dict[str, Any]], max_items: int = 3) -> Dict[str, Any]:
    selected = products[:max_items]
    if len(selected) > 1:
        with ThreadPoolExecutor(max_workers=len(selected)) as executor:
            checked = list(executor.map(verify_product_against_web, selected))
    else:
        checked = [verify_product_against_web(product) for product in selected]
    verified = [item for item in checked if item.get("verified")]
    return {
        "query": query,
        "checked_count": len(checked),
        "verified_count": len(verified),
        "items": checked,
        "summary": (
            f"Live web verified {len(verified)} of {len(checked)} top picks."
            if checked
            else "No products were available for live web verification."
        ),
    }
