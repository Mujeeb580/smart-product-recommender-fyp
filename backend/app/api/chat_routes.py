from datetime import datetime, timezone
import json
import os
import re
from typing import Any, Dict, List
from urllib import error as url_error
from urllib import request as url_request

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.recommendation.engine import recommend_products
from app.recommendation.firestore import (
    fetch_products,
    get_chat_history,
    save_chat_message,
    update_product_fields,
)


router = APIRouter(prefix="/chat", tags=["Chat"])


class ChatMessage(BaseModel):
    message: str
    session_id: str | None = None


_SESSION_PREFS: Dict[str, Dict[str, str]] = {}
_SESSION_LAST_RECOMMENDED: Dict[str, List[Dict[str, Any]]] = {}


def _is_greeting(message: str) -> bool:
    greeting_words = {"hi", "hii", "hello", "hey", "salam", "assalam", "aslam"}
    tokens = re.findall(r"[a-zA-Z]+", message.lower())
    return any(token in greeting_words for token in tokens)


def _is_off_topic(message: str) -> bool:
    """Detect if query is not related to product recommendations."""
    text = message.lower().strip()
    
    # Off-topic patterns
    off_topic_patterns = [
        # Casual greetings/small talk
        r"kaisa\s+ho",  # how are you
        r"kaise\s+ho",  # how are you
        r"aap\s+kaisa\s+ho",  # how are you (formal)
        r"kya\s+hal\s+hai",  # what's up
        r"app\s+kaun\s+ho",  # who are you
        r"aapka\s+naam\s+kya",  # what's your name
        r"aap\s+kon",  # who are you
        r"tum\s+kaun",  # who are you (informal)
        # Personal/social chat
        r"joke|meme|mazak|hassi",  # jokes/memes
        r"weather|mausam|barish|dhoop",  # weather
        r"movie|film|drama|tv|sports",  # entertainment
        r"cricket|football|game\s+khel",  # sports (not gaming phones)
        r"politics|election|news",  # politics/news
        r"love|pyar|shadi|rishta",  # romance/relationships
    ]
    
    for pattern in off_topic_patterns:
        if re.search(pattern, text):
            return True
    
    return False


def _looks_like_greeting_reply(reply: str) -> bool:
    text = reply.lower()
    return any(phrase in text for phrase in ["assalam-o-alaikum", "main aap ka smart shopping assistant hoon"])


def _off_topic_reply() -> str:
    """Return response for off-topic queries."""
    return (
        "Yeh query product selection se related nahi hai. Mein sirf smartphones aur laptops recommend kar sakta hoon. "
        "Kripya apni shopping requirement batayein."
    )


def _normalize_spec_value(value: str | None) -> str | None:
    if not value:
        return None
    text = value.strip().replace("\n", " ")
    text = re.sub(r"\s+", " ", text)
    if not text:
        return None
    if text.lower() in {"n/a", "na", "none", "null", "unknown", "-", "--"}:
        return None
    return text[:120]


def _extract_specs_from_html(html: str) -> Dict[str, str]:
    extracted: Dict[str, str] = {}

    patterns = {
        "battery": [
            r"Battery(?:\s*Capacity)?[^<]{0,40}</[^>]+>\s*<[^>]+>([^<]{2,80})<",
            r'"battery[^"\\]*"\s*:\s*"([^"\\]{2,80})"',
            r"\b([3-9][0-9]{3}\s*mAh)\b",
        ],
        "camera": [
            r"Camera[^<]{0,40}</[^>]+>\s*<[^>]+>([^<]{2,120})<",
            r'"camera[^"\\]*"\s*:\s*"([^"\\]{2,120})"',
        ],
        "processor": [
            r"Processor[^<]{0,40}</[^>]+>\s*<[^>]+>([^<]{2,120})<",
            r"Chipset[^<]{0,40}</[^>]+>\s*<[^>]+>([^<]{2,120})<",
            r'"processor[^"\\]*"\s*:\s*"([^"\\]{2,120})"',
        ],
        "ram": [
            r"RAM[^<]{0,40}</[^>]+>\s*<[^>]+>([^<]{2,80})<",
            r'"ram[^"\\]*"\s*:\s*"([^"\\]{2,80})"',
        ],
        "storage": [
            r"Storage[^<]{0,40}</[^>]+>\s*<[^>]+>([^<]{2,80})<",
            r'"storage[^"\\]*"\s*:\s*"([^"\\]{2,80})"',
        ],
    }

    for key, key_patterns in patterns.items():
        for pattern in key_patterns:
            match = re.search(pattern, html, flags=re.IGNORECASE)
            if not match:
                continue
            value = _normalize_spec_value(match.group(1))
            if value:
                extracted[key] = value
                break

    return extracted


def _needs_enrichment(product: Dict[str, Any]) -> bool:
    for field in ["battery", "camera", "processor", "ram", "storage"]:
        value = str(product.get(field, "")).strip().lower()
        if not value or value in {"unknown", "n/a", "none", "-", "--"}:
            return True
    return False


def _enrich_product_realtime(product: Dict[str, Any]) -> Dict[str, Any]:
    if not _needs_enrichment(product):
        return product

    url = str(product.get("url", "")).strip()
    if not url:
        return product

    req = url_request.Request(
        url=url,
        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"},
        method="GET",
    )

    try:
        with url_request.urlopen(req, timeout=8) as resp:
            html = resp.read().decode("utf-8", errors="ignore")
    except Exception:
        return product

    found = _extract_specs_from_html(html)
    if not found:
        return product

    enriched = dict(product)
    for key, value in found.items():
        current = str(enriched.get(key, "")).strip().lower()
        if not current or current in {"unknown", "n/a", "none", "-", "--"}:
            enriched[key] = value

    # Keep combined specs readable in UI.
    specs_parts = []
    for key in ["ram", "storage", "processor", "battery", "camera"]:
        value = enriched.get(key)
        if value:
            specs_parts.append(f"{key}: {value}")
    if specs_parts:
        enriched["specs"] = " | ".join(specs_parts)

    try:
        update_product_fields(
            str(enriched.get("collection", "")),
            str(enriched.get("id", "") or enriched.get("product_id", "")),
            {k: enriched.get(k) for k in ["ram", "storage", "processor", "battery", "camera", "specs"]},
        )
    except Exception:
        # Realtime response should still succeed even if persistence fails.
        pass

    return enriched


def _enrich_recommendations_realtime(recommended: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    if not recommended:
        return recommended

    enriched: List[Dict[str, Any]] = []
    for idx, item in enumerate(recommended):
        # Realtime fetch only for top 3 to keep latency reasonable.
        if idx < 3:
            enriched.append(_enrich_product_realtime(item))
        else:
            enriched.append(item)
    return enriched


def _extract_preferences(message: str) -> Dict[str, str]:
    text = message.lower()
    prefs: Dict[str, str] = {}

    brand_candidates = [
        "samsung",
        "iphone",
        "apple",
        "xiaomi",
        "oppo",
        "vivo",
        "infinix",
        "tecno",
        "realme",
        "google",
        "pixel",
    ]
    for brand in brand_candidates:
        if brand in text:
            prefs["brand"] = brand
            break

    budget_match = re.search(
        r"(?:under|below|less than|up to|upto|max|maximum|within)\s*(?:rs\.?|pkr\s*)?\s*([0-9]+(?:\.[0-9]+)?)(k?)",
        text,
    )
    if budget_match:
        value = float(budget_match.group(1))
        if budget_match.group(2):
            value *= 1000
        prefs["budget_max"] = str(int(value))

    if any(word in text for word in ["camera", "photo", "photography"]):
        prefs["priority"] = "camera"
    elif any(word in text for word in ["battery", "backup", "charge"]):
        prefs["priority"] = "battery"
    elif any(word in text for word in ["gaming", "game", "fps"]):
        prefs["priority"] = "gaming"
    elif any(word in text for word in ["performance", "fast", "smooth", "processor"]):
        prefs["priority"] = "performance"

    return prefs


def _prefs_text(prefs: Dict[str, str]) -> str:
    if not prefs:
        return "none"

    parts: List[str] = []
    if "brand" in prefs:
        parts.append(f"brand={prefs['brand']}")
    if "budget_max" in prefs:
        parts.append(f"budget_max=Rs {prefs['budget_max']}")
    if "priority" in prefs:
        parts.append(f"priority={prefs['priority']}")
    return ", ".join(parts)


def _build_effective_query(message: str, prefs: Dict[str, str]) -> str:
    text = message.strip()
    lower = text.lower()

    if prefs.get("brand") and prefs["brand"] not in lower:
        text = f"{text} {prefs['brand']}"
    if prefs.get("priority") and prefs["priority"] not in lower:
        text = f"{text} {prefs['priority']}"
    if prefs.get("budget_max") and all(
        phrase not in lower for phrase in ["under", "below", "less than", "up to", "upto", "max", "maximum"]
    ):
        text = f"{text} under {prefs['budget_max']}"

    return text.strip()


def _is_shopping_intent_query(message: str) -> bool:
    text = message.lower().strip()
    intent_keywords = [
        "phone",
        "mobile",
        "smartphone",
        "laptop",
        "flagship",
        "budget",
        "under",
        "below",
        "camera",
        "battery",
        "gaming",
        "performance",
        "recommend",
        "suggest",
        "best",
    ]
    return any(word in text for word in intent_keywords)


def _is_followup_about_previous_phone(message: str) -> bool:
    text = message.lower().strip()
    followup_markers = [
        "is phone",
        "is mobile",
        "yeh phone",
        "ye phone",
        "us phone",
        "wo phone",
        "iss ka",
        "is ka",
        "battery",
        "camera",
        "ram",
        "storage",
        "processor",
        "kitni",
        "kitna",
        "kesa hai",
        "kaisa hai",
    ]
    return any(marker in text for marker in followup_markers)


def _estimate_battery_experience(product: Dict[str, Any]) -> str:
    battery_text = str(product.get("battery", "")).lower()
    m = re.search(r"([3-9][0-9]{3})\s*m?ah", battery_text)
    mah = int(m.group(1)) if m else None

    if mah is None:
        return "normal use mein lagbhag 1 din nikal jata hai"
    if mah >= 6000:
        return "normal use mein aram se 1.5 se 2 din chal jati hai"
    if mah >= 5000:
        return "normal use mein full day aur light use mein 1.5 din ke qareeb chal jati hai"
    if mah >= 4500:
        return "normal use mein takreeban full day ka backup de deti hai"
    return "normal use mein 1 din se thori kam chal sakti hai, heavy gaming par jaldi drain hoti hai"


def _estimate_camera_experience(product: Dict[str, Any], realtime_signals: str = "") -> str:
    camera_text = f"{product.get('camera', '')} {realtime_signals}".lower()
    mp_values = [int(v) for v in re.findall(r"([1-9][0-9]{1,2})\s*mp", camera_text)]
    max_mp = max(mp_values) if mp_values else None
    has_ois = "ois" in camera_text
    has_night = "night" in camera_text

    if max_mp is None:
        return "daylight photos generally achi aati hain, low light average rehti hai"
    if max_mp >= 64 or has_ois:
        return "camera overall acha hai, daylight mein crisp photos aati hain aur low light bhi decent rehti hai"
    if max_mp >= 50:
        if has_night:
            return "camera acha perform karta hai, daylight strong hai aur low light bhi theek-thak handle kar leta hai"
        return "camera daylight use ke liye acha hai, low light mein average-to-good result milte hain"
    return "camera basic to decent hai, social media aur normal photos ke liye theek hai"


def _estimate_gaming_experience(product: Dict[str, Any], realtime_signals: str = "") -> str:
    chip = f"{product.get('processor', '')} {realtime_signals}".lower()
    if any(k in chip for k in ["snapdragon 8", "dimensity 8", "apple a1", "apple a17", "apple a16", "apple a15"]):
        return "high settings gaming smooth chalti hai aur FPS stable rehta hai"
    if any(k in chip for k in ["snapdragon 7", "dimensity 7", "helio g9", "helio g8"]):
        return "casual se mid-heavy gaming comfortably chal jati hai, bohat heavy games mein settings balance rakhni parti hain"
    return "casual gaming ke liye theek hai, heavy gaming mein medium/low settings behtar rahengi"


def _fetch_realtime_signals(product: Dict[str, Any]) -> str:
    url = str(product.get("url", "")).strip()
    if not url:
        return ""

    req = url_request.Request(
        url=url,
        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"},
        method="GET",
    )

    try:
        with url_request.urlopen(req, timeout=8) as resp:
            html = resp.read().decode("utf-8", errors="ignore")
    except Exception:
        return ""

    snippets: List[str] = []
    title_match = re.search(r"<title>(.*?)</title>", html, flags=re.IGNORECASE | re.DOTALL)
    if title_match:
        snippets.append(_normalize_spec_value(title_match.group(1)) or "")

    desc_match = re.search(
        r'<meta[^>]*name=["\']description["\'][^>]*content=["\']([^"\']{20,300})["\']',
        html,
        flags=re.IGNORECASE,
    )
    if desc_match:
        snippets.append(_normalize_spec_value(desc_match.group(1)) or "")

    for kw in ["camera", "battery", "processor", "chipset", "gaming", "night", "ois", "mah"]:
        m = re.search(rf"(.{{0,80}}{kw}.{{0,80}})", html, flags=re.IGNORECASE)
        if m:
            cleaned = _normalize_spec_value(re.sub(r"<[^>]+>", " ", m.group(1)))
            if cleaned:
                snippets.append(cleaned)

    compact = " | ".join(s for s in snippets if s)
    return compact[:700]


def _reply_about_phone_details(message: str, product: Dict[str, Any], realtime_signals: str = "") -> str:
    text = message.lower().strip()
    name = str(product.get("name", "Yeh phone"))
    battery_exp = _estimate_battery_experience(product)
    camera_exp = _estimate_camera_experience(product, realtime_signals)
    gaming_exp = _estimate_gaming_experience(product, realtime_signals)

    if "battery" in text or "backup" in text or "charge" in text:
        return f"{name} ki battery practical use mein {battery_exp}. Heavy gaming par bhi yeh stable backup deti hai, lekin brightness high ho to drain barh sakta hai."
    if "camera" in text or "photo" in text:
        return f"{name} ka camera practical use mein {camera_exp}. Social media aur daily shots ke liye yeh reliable choice hai."
    if "gaming" in text or "game" in text or "fps" in text or "performance" in text:
        return f"{name} gaming side par {gaming_exp}. Agar aap competitive gaming karte hain to thermal aur FPS ke liye alternate bhi compare karwa deta hoon."

    return (
        f"{name} overall balanced phone lagta hai: camera side par {camera_exp}, battery side par {battery_exp}, "
        f"aur gaming side par {gaming_exp}."
    )


def _fallback_reply(
    user_message: str,
    recommended: List[Dict[str, Any]],
    prefs: Dict[str, str],
) -> str:
    message = user_message.lower().strip()

    if _is_greeting(message):
        return (
            "Assalam-o-Alaikum! Main aap ka smart shopping assistant hoon. "
            "Aap apni need simple alfaaz mein batayein, main best options short aur clear way mein suggest karunga."
        )

    if not recommended:
        remembered = _prefs_text(prefs)
        return (
            "Samajh gaya. Thori si detail aur share karein, jaise budget range, brand preference, camera ya battery priority. "
            f"Abhi tak meri remembered preferences: {remembered}."
        )

    top = recommended[0]
    name = str(top.get("name", "yeh option"))
    price = top.get("price")
    brand = str(top.get("brand", ""))
    budget_max = prefs.get("budget_max")

    if price is not None:
        if budget_max:
            return (
                f"Aap ke budget Rs {budget_max} ke qareeb {name} ({brand}) strong option lag raha hai, price taqreeban Rs {price} hai. "
                "Neeche maine aur near-budget options bhi diye hain taake aap best compare kar saken."
            )
        return (
            f"Aap ki requirement dekhte hue {name} ({brand}) sab se strong match lag raha hai, jiski price taqreeban Rs {price} hai. "
            "Neeche maine aur options bhi diye hain taake aap compare karke best decision le saken."
        )

    return (
        f"Aap ki requirement dekhte hue {name} sab se behtar match lag raha hai. "
        "Neeche maine aur related options bhi diye hain taake aap easily compare kar saken."
    )


def _llm_reply(
    user_message: str,
    recommended: List[Dict[str, Any]],
    prefs: Dict[str, str],
    context_product: Dict[str, Any] | None = None,
    realtime_signals: str = "",
) -> str | None:
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        return None

    model = os.getenv("OPENROUTER_MODEL", "openai/gpt-oss-120b:free")
    base_url = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")

    shortlist = []
    for p in recommended[:5]:
        shortlist.append(
            {
                "name": p.get("name"),
                "brand": p.get("brand"),
                "price": p.get("price"),
                "ram": p.get("ram"),
                "storage": p.get("storage"),
                "processor": p.get("processor"),
                "score": p.get("similarity_score"),
            }
        )

    context_text = "none"
    if context_product:
        context_text = json.dumps(
            {
                "name": context_product.get("name"),
                "brand": context_product.get("brand"),
                "price": context_product.get("price"),
                "ram": context_product.get("ram"),
                "storage": context_product.get("storage"),
                "processor": context_product.get("processor"),
                "camera": context_product.get("camera"),
                "battery": context_product.get("battery"),
            },
            ensure_ascii=True,
        )

    payload = {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are a smart shopping assistant. "
                    "Reply in natural Roman Urdu with friendly human tone, not robotic. "
                    "Use 2-4 concise sentences. "
                    "You can be a little proactive and suggest the next best step. "
                    "If products are present, mention top pick and one comparison hint. "
                    "If user asks follow-up about previously suggested phone, answer using that phone context directly. "
                    "Prefer practical usage judgment (daily use, battery day estimate, gaming behavior, camera real-life feel) over raw spec dumping. "
                    "Avoid listing mAh/MP unless user explicitly asks for exact numbers. "
                    "If user greeting or vague query, ask 1 focused follow-up question."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"User message: {user_message}\n"
                    f"Remembered preferences: {_prefs_text(prefs)}\n"
                    f"Previous top phone context: {context_text}\n"
                    f"Realtime page signals: {realtime_signals or 'none'}\n"
                    f"Recommended products JSON: {json.dumps(shortlist, ensure_ascii=True)}"
                ),
            },
        ],
        "temperature": 0.7,
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

    req = url_request.Request(
        url=f"{base_url}/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )

    try:
        with url_request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            text = data["choices"][0]["message"]["content"].strip()
            return text or None
    except (url_error.URLError, KeyError, json.JSONDecodeError, TimeoutError):
        return None


@router.post("/send-message")
async def send_chat_message(chat_message: ChatMessage):
    try:
        normalized = chat_message.message.lower().strip()
        session_id = chat_message.session_id or "default"

        # Check if query is off-topic
        if _is_off_topic(normalized):
            reply = _off_topic_reply()
            message_payload: Dict[str, Any] = {
                "message": chat_message.message,
                "reply": reply,
                "recommended_count": 0,
                "session_id": session_id,
                "preferences": _SESSION_PREFS.get(session_id, {}),
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
            save_chat_message(message_payload)
            return {"reply": reply, "products": []}

        is_greeting = _is_greeting(normalized)
        is_short_message = len(normalized.split()) <= 3

        previous_prefs = _SESSION_PREFS.get(session_id, {})
        previous_recommended = _SESSION_LAST_RECOMMENDED.get(session_id, [])
        new_prefs = _extract_preferences(chat_message.message)
        merged_prefs = {**previous_prefs, **new_prefs}
        _SESSION_PREFS[session_id] = merged_prefs

        if previous_recommended and _is_followup_about_previous_phone(normalized):
            top_prev = _enrich_product_realtime(previous_recommended[0])
            realtime_signals = _fetch_realtime_signals(top_prev)
            reply = _llm_reply(
                chat_message.message,
                [],
                merged_prefs,
                context_product=top_prev,
                realtime_signals=realtime_signals,
            )
            if not reply:
                reply = _reply_about_phone_details(chat_message.message, top_prev, realtime_signals)

            message_payload: Dict[str, Any] = {
                "message": chat_message.message,
                "reply": reply,
                "recommended_count": 0,
                "session_id": session_id,
                "preferences": merged_prefs,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
            save_chat_message(message_payload)
            return {"reply": reply, "products": []}

        if is_greeting or (is_short_message and not _is_shopping_intent_query(normalized)):
            recommended = []
        else:
            products = fetch_products(limit=600)
            effective_query = _build_effective_query(chat_message.message, merged_prefs)
            recommended = recommend_products(effective_query, products, top_n=5)

        recommended = _enrich_recommendations_realtime(recommended)

        _SESSION_LAST_RECOMMENDED[session_id] = recommended

        reply = _llm_reply(
            chat_message.message,
            recommended,
            merged_prefs,
            context_product=None,
            realtime_signals="",
        ) or _fallback_reply(chat_message.message, recommended, merged_prefs)

        if (not is_greeting) and _looks_like_greeting_reply(reply):
            reply = _fallback_reply(chat_message.message, recommended, merged_prefs)

        message_payload: Dict[str, Any] = {
            "message": chat_message.message,
            "reply": reply,
            "recommended_count": len(recommended),
            "session_id": session_id,
            "preferences": merged_prefs,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        save_chat_message(message_payload)

        return {"reply": reply, "products": recommended}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error processing message: {exc}")


@router.get("/history")
async def history(limit: int = 50):
    try:
        messages: List[Dict[str, Any]] = get_chat_history(limit=limit)
        return {"messages": messages, "count": len(messages)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error fetching chat history: {exc}")


@router.post("/save")
async def save_chat_message_route(message: Dict[str, Any]):
    try:
        payload = dict(message)
        payload.setdefault("timestamp", datetime.now(timezone.utc).isoformat())
        doc_id = save_chat_message(payload)
        return {"success": True, "id": doc_id}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error saving message: {exc}")
