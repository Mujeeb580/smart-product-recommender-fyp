import json
import os
import re
from typing import List, Dict, Any

import requests
from app.recommendation.query_language import normalize_user_query, prefers_roman_urdu


def _build_product_payload(products: List[Dict[str, Any]]) -> str:
    trimmed = []
    for p in products[:5]:
        trimmed.append(
            {
                "name": p.get("name"),
                "normalized_name": p.get("normalized_name"),
                "brand": p.get("brand"),
                "category": p.get("category"),
                "price": p.get("price"),
                "ram": p.get("ram"),
                "storage": p.get("storage"),
                "processor": p.get("processor"),
                "gpu": p.get("gpu"),
                "battery": p.get("battery"),
                "camera": p.get("camera"),
                "display": p.get("display"),
                "description": p.get("description"),
                "specs": p.get("specs"),
                "normalized_processor": p.get("normalized_processor"),
                "device_score": p.get("device_score"),
                "device_tier": p.get("device_tier"),
                "similarity_score": p.get("similarity_score"),
                "boosted_score": p.get("boosted_score"),
                "intent_score": p.get("intent_score"),
            }
        )
    return json.dumps(trimmed, ensure_ascii=True)


def _build_verification_payload(verification_context: Dict[str, Any] | None) -> str:
    if not verification_context:
        return ""
    return json.dumps(verification_context, ensure_ascii=True)


def _build_conversation_payload(conversation_context: Dict[str, Any] | None) -> str:
    if not conversation_context:
        return ""
    recent_products = conversation_context.get("products") or []
    trimmed = {
        "previous_query": conversation_context.get("query"),
        "scope": conversation_context.get("scope"),
        "recent_product_names": [product.get("name") for product in recent_products[:5]],
    }
    return json.dumps(trimmed, ensure_ascii=True)


def _display_price(price: Any) -> str:
    text = str(price or "").strip()
    if not text:
        return ""
    text = re.sub(r"^(?:rs\.?|pkr|₨)\s*", "", text, flags=re.IGNORECASE)
    return f"PKR {text}"


def _normalize_currency_labels(text: str) -> str:
    """Ensure chat replies use Pakistan's PKR label, never INR/Rs symbols."""
    normalized = str(text or "")
    normalized = re.sub(r"(?:₹|₨)\s*", "PKR ", normalized)
    normalized = re.sub(r"\b(?:INR|Rs\.?)\s*", "PKR ", normalized, flags=re.IGNORECASE)
    normalized = re.sub(
        r"(?<![\w,])(\d[\d,]*(?:\.\d+)?)\s+(?:Indian\s+)?rupees?\b",
        r"PKR \1",
        normalized,
        flags=re.IGNORECASE,
    )
    normalized = re.sub(r"\bPKR\s+(?:PKR\s+)+", "PKR ", normalized, flags=re.IGNORECASE)
    return normalized


def _has_dedicated_laptop_gpu(product: Dict[str, Any]) -> bool:
    gpu = str(product.get("gpu") or "").lower()
    return bool(
        re.search(r"\b(?:rtx|gtx)\s*\d{3,4}\b|\bradeon\s+rx\s*\d{3,4}\b", gpu)
    )


def _fallback_explanation(user_query: str, products: List[Dict[str, Any]]) -> str:
    roman_urdu = prefers_roman_urdu(user_query)
    if not products:
        if roman_urdu:
            return "Abhi matching product nahi mila. Budget ya requirement thori change karke dobara poochain."
        return "I could not find matching products right now. Please try a different query."

    top = products[0]
    name = top.get("name", "the top result")
    price = top.get("price")
    display_price = _display_price(price)
    query = normalize_user_query(user_query)
    asks_for_gaming_laptop = "laptop" in query and bool(
        re.search(r"\b(?:gaming|game|gamer)\b", query)
    )
    if asks_for_gaming_laptop and not any(
        _has_dedicated_laptop_gpu(product) for product in products
    ):
        if roman_urdu:
            return (
                f"Is budget ke matching results mein dedicated-GPU gaming laptop nahi mila. "
                f"{name} available options mein strongest hai, lekin integrated graphics ki wajah se "
                "light ya esports gaming ke liye behtar hai; demanding AAA games ke liye ideal nahi."
            )
        return (
            f"No dedicated-GPU gaming laptop appears in the matching results for this budget. "
            f"{name} is the strongest available option, but its integrated graphics are better suited "
            "to light or esports gaming than demanding AAA games."
        )
    detail_fields = {
        "battery": ("battery", "battery"),
        "camera": ("camera", "camera"),
        "ram": ("RAM", "ram"),
        "storage": ("storage", "storage"),
        "processor": ("processor", "processor"),
        "chipset": ("processor", "processor"),
        "gpu": ("GPU", "gpu"),
        "graphics": ("GPU", "gpu"),
        "display": ("display", "display"),
        "screen": ("display", "display"),
    }
    requested_details = []
    for keyword, (label, field) in detail_fields.items():
        value = top.get(field)
        if keyword in query and value and (label, value) not in requested_details:
            requested_details.append((label, value))

    is_follow_up = bool(
        re.search(r"\b(it|this|that|which|compare|details?|specs?|first|second)\b|tell me", query)
    )
    is_refinement = bool(
        re.search(r"\b(?:cheap|cheaper|affordable|another|other option|more option|instead)\b", query)
    )
    is_follow_up = is_follow_up and not is_refinement
    asks_comparison = bool(
        len(products) >= 2
        and re.search(r"\b(?:compare|comparison|difference|better)\b", query)
    )
    if asks_comparison:
        other = products[1]

        def comparison_details(product: Dict[str, Any]) -> str:
            fields = []
            for label, field in (
                ("price", "price"),
                ("processor", "processor"),
                ("RAM", "ram"),
                ("battery", "battery"),
            ):
                value = product.get(field)
                if value:
                    fields.append(f"{label}: {value}")
            return ", ".join(fields) or "limited catalog details"

        other_name = other.get("name", "the other product")
        first_details = comparison_details(top)
        other_details = comparison_details(other)
        score_fields = ("intent_score", "similarity_score", "device_score")

        def comparison_score(product: Dict[str, Any]) -> tuple[float, ...]:
            return tuple(float(product.get(field) or 0) for field in score_fields)

        winner = max(products[:2], key=comparison_score)
        has_ranking_score = any(comparison_score(product) != (0.0, 0.0, 0.0) for product in products[:2])
        winner_name = winner.get("name", name)
        if roman_urdu:
            verdict = (
                f" Aap ki current requirement ke liye ranking mein {winner_name} upar hai."
                if has_ranking_score
                else ""
            )
            return f"{name}: {first_details}. {other_name}: {other_details}.{verdict}"
        verdict = (
            f" For your current requirement, {winner_name} ranks higher."
            if has_ranking_score
            else ""
        )
        return f"{name}: {first_details}. {other_name}: {other_details}.{verdict}"
    asks_gaming_suitability = bool(
        re.search(r"\b(?:worth|good|suitable|acha|behtar)\b", query)
        and re.search(r"\b(?:gaming|game|pubg|bgmi|fortnite|cod)\b", query)
    )
    if asks_gaming_suitability:
        device_score = float(top.get("device_score") or 0)
        processor = top.get("processor") or top.get("normalized_processor") or "listed processor"
        if device_score >= 0.65:
            verdict_en = "Yes, it is a strong choice"
            verdict_ur = "Haan, yeh strong choice hai"
        elif device_score >= 0.45:
            verdict_en = "It is suitable at moderate settings"
            verdict_ur = "Yeh moderate settings par theek rahega"
        else:
            verdict_en = "It is not an ideal choice for demanding gaming"
            verdict_ur = "Demanding gaming ke liye yeh ideal choice nahi hai"
        if roman_urdu:
            return f"{verdict_ur}. {name} mein {processor} hai; PUBG mein graphics aur frame-rate moderate rakhna behtar hoga."
        return f"{verdict_en}. {name} uses {processor}; for PUBG, adjust graphics and frame rate to match its performance."
    if requested_details:
        details = ", ".join(f"{label}: {value}" for label, value in requested_details)
        if len(products) > 1 and any(word in query for word in ("which", "best", "better", "compare")):
            if roman_urdu:
                return f"Dikhaye gaye options mein {name} sab se behtar hai ({details})."
            return f"Among the shown options, {name} ranks highest for this request ({details})."
        if roman_urdu:
            return f"{name} ki catalog details yeh hain: {details}."
        return f"{name} has {details}. This answer uses the specifications stored in the product catalog."

    if is_follow_up:
        available = []
        for label, field in (("processor", "processor"), ("RAM", "ram"), ("storage", "storage"), ("battery", "battery"), ("camera", "camera")):
            if top.get(field):
                available.append(f"{label}: {top[field]}")
        detail_text = ", ".join(available)
        price_text = f", price: {display_price}" if display_price else ""
        if detail_text:
            if roman_urdu:
                return f"{name} ki catalog details: {detail_text}{price_text}."
            return f"For {name}, the catalog lists {detail_text}{price_text}."
    if roman_urdu:
        price_text = f" Is ki price {display_price} hai." if display_price else ""
        return (
            f"Aap ki requirement ke liye {name} sab se behtar match hai.{price_text} "
            "Neeche milte-julte options bhi diye gaye hain taa-ke aap compare kar saken."
        )
    if display_price:
        return (
            f"Based on your request, {name} looks like the strongest match. "
            f"It appears to fit your needs and is currently listed around {display_price}. "
            "I also included a few similar options so you can compare value and features."
        )

    return (
        f"Based on your request, {name} looks like the strongest match. "
        "I also included similar options so you can compare features and choose confidently."
    )


def generate_explanation(
    user_query: str,
    products: List[Dict[str, Any]],
    verification_context: Dict[str, Any] | None = None,
    conversation_context: Dict[str, Any] | None = None,
) -> str:
    """
    Generate natural-language explanation using OpenRouter (OpenAI-compatible API).
    Falls back to deterministic text when API key is missing or request fails.
    """
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        return _normalize_currency_labels(_fallback_explanation(user_query, products))

    model = os.getenv("OPENROUTER_MODEL", "openai/gpt-oss-120b:free")
    base_url = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
    timeout_seconds = float(os.getenv("OPENROUTER_TIMEOUT_SECONDS", "10"))

    payload = {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are a concise shopping assistant. "
                    "Explain recommendations clearly in 3-5 short sentences. "
                    "Mention why top options match the user intent and suggest one best pick. "
                    "If the user asks a follow-up, comparison, or product-specific question, answer that exact question directly. "
                    "Use only facts present in the product or verification JSON; clearly say when a requested fact is unavailable. "
                    "Treat the user's stated maximum budget as a hard limit and never describe an over-budget product as matching it. "
                    "All prices are Pakistani rupees: always write the currency as PKR (for example, PKR 30,000). Never use ₹, INR, Rs, or Rs. "
                    "For basic work, office, or study requests without demanding performance needs, prefer practical affordable laptops and do not recommend premium gaming or workstation hardware. "
                    "For calls, messaging, social media, daily use, or student phone requests, prefer capable affordable phones and avoid unnecessary flagships unless the user requests flagship, camera, or gaming performance. "
                    "When ranked products are supplied, do not tell the user to increase the budget. "
                    "If a gaming-laptop query only has integrated-graphics results, clearly state that no dedicated-GPU option matched the budget and do not call those products ideal for demanding gaming. "
                    "Prefer the product ranking and scores shown in the input JSON when explaining the choice."
                    " Detect Roman Urdu written in Latin script and reply naturally in Roman Urdu; otherwise reply in the user's language."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"User query: {user_query}\n"
                    f"Previous conversation context: {_build_conversation_payload(conversation_context)}\n"
                    f"Ranked products JSON: {_build_product_payload(products)}\n"
                    f"Web verification JSON: {_build_verification_payload(verification_context)}\n"
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
            timeout=timeout_seconds,
        )
        response.raise_for_status()
        data = response.json()
        return _normalize_currency_labels(data["choices"][0]["message"]["content"].strip())
    except Exception:
        reply = _fallback_explanation(user_query, products)
        if verification_context and verification_context.get("verified_count") is not None:
            reply = f"{reply} Live web check: {verification_context.get('summary', '')}".strip()
        return _normalize_currency_labels(reply)
