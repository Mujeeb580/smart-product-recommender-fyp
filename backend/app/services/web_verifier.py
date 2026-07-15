"""Lightweight live-web verification for top-ranked products."""

from __future__ import annotations

import re
from typing import Any, Dict, List

import requests


USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
)


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


def verify_product_against_web(product: Dict[str, Any], timeout_seconds: float = 8.0) -> Dict[str, Any]:
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
        return result
    except Exception as exc:
        result["reason"] = f"fetch_failed:{exc.__class__.__name__}"
        return result


def build_verification_context(query: str, products: List[Dict[str, Any]], max_items: int = 3) -> Dict[str, Any]:
    checked = [verify_product_against_web(product) for product in products[:max_items]]
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