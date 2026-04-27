import json
import os
from typing import List, Dict, Any

import requests


def _build_product_payload(products: List[Dict[str, Any]]) -> str:
    trimmed = []
    for p in products[:5]:
        trimmed.append(
            {
                "name": p.get("name"),
                "brand": p.get("brand"),
                "price": p.get("price"),
                "ram": p.get("ram"),
                "storage": p.get("storage"),
                "processor": p.get("processor"),
                "similarity_score": p.get("similarity_score"),
            }
        )
    return json.dumps(trimmed, ensure_ascii=True)


def _fallback_explanation(user_query: str, products: List[Dict[str, Any]]) -> str:
    if not products:
        return "I could not find matching products right now. Please try a different query."

    top = products[0]
    name = top.get("name", "the top result")
    price = top.get("price")
    if price is not None:
        return (
            f"Based on your request, {name} looks like the strongest match. "
            f"It appears to fit your needs and is currently listed around Rs. {price}. "
            "I also included a few similar options so you can compare value and features."
        )

    return (
        f"Based on your request, {name} looks like the strongest match. "
        "I also included similar options so you can compare features and choose confidently."
    )


def generate_explanation(user_query: str, products: List[Dict[str, Any]]) -> str:
    """
    Generate natural-language explanation using OpenRouter (OpenAI-compatible API).
    Falls back to deterministic text when API key is missing or request fails.
    """
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        return _fallback_explanation(user_query, products)

    model = os.getenv("OPENROUTER_MODEL", "openai/gpt-oss-120b:free")
    base_url = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")

    payload = {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are a concise shopping assistant. "
                    "Explain recommendations clearly in 3-5 short sentences. "
                    "Mention why top options match the user intent and suggest one best pick."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"User query: {user_query}\n"
                    f"Ranked products JSON: {_build_product_payload(products)}\n"
                    "Write a helpful recommendation summary for the user."
                ),
            },
        ],
        "temperature": 0.4,
    }

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    site_url = os.getenv("OPENROUTER_SITE_URL")
    app_name = os.getenv("OPENROUTER_APP_NAME")
    if site_url:
        headers["HTTP-Referer"] = site_url
    if app_name:
        headers["X-Title"] = app_name

    try:
        response = requests.post(
            f"{base_url}/chat/completions",
            headers=headers,
            json=payload,
            timeout=30,
        )
        response.raise_for_status()
        data = response.json()
        return data["choices"][0]["message"]["content"].strip()
    except Exception:
        return _fallback_explanation(user_query, products)
