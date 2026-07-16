import re
import time
from threading import RLock
from typing import Dict, List, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.recommendation.firestore import fetch_products
from app.recommendation.engine import recommend_products
from app.recommendation.query_language import normalize_user_query, prefers_roman_urdu
from app.services.llm_service import generate_explanation
from app.services.web_verifier import build_verification_context

router = APIRouter(prefix="/chat", tags=["Chat"])


class ChatMessage(BaseModel):
    message: str
    product_id: Optional[str] = None
    session_id: Optional[str] = None


class ChatResponse(BaseModel):
    reply: str
    products: list


GREETING_PATTERN = re.compile(
    r"\b(hi|hello|hey|salam|assalam\s*o\s*alaikum|aoa|aslam\s*o\s*alaikum|kia\s*haal|kese\s*ho)\b",
    re.IGNORECASE,
)

PHONE_KEYWORDS = ("phone", "phones", "mobile", "mobiles", "smartphone")
LAPTOP_KEYWORDS = ("laptop", "laptops", "notebook")

_SESSION_TTL_SECONDS = 2 * 60 * 60
_MAX_SESSIONS = 500
_SESSION_CONTEXT: Dict[str, Dict] = {}
_SESSION_LOCK = RLock()

FOLLOW_UP_PATTERN = re.compile(
    r"\b(it|its|this|that|these|those|them|they|one|ones|first|second|third|"
    r"which|compare|comparison|difference|better|best among|tell me more|what about|"
    r"how about|does|is it|are they|specs?|details?|worth it)\b",
    re.IGNORECASE,
)
REFINEMENT_PATTERN = re.compile(
    r"\b(cheap|cheaper|affordable|more expensive|another|other options?|more options?|instead|"
    r"under|below|less than|up to|upto|within|above|over|at least|budget)\b",
    re.IGNORECASE,
)


def _normalize_text(text: str) -> str:
    return (text or "").strip().lower()


def _contains_keyword(text: str, keywords: tuple[str, ...]) -> bool:
    normalized = _normalize_text(text)
    for keyword in keywords:
        if re.search(rf"\b{re.escape(keyword)}\b", normalized):
            return True
    return False


def _is_greeting(text: str) -> bool:
    normalized = _normalize_text(text)
    if not GREETING_PATTERN.search(normalized):
        return False
    remainder = GREETING_PATTERN.sub(" ", normalized)
    remainder = re.sub(r"[^a-z0-9]+", " ", remainder).strip()
    return remainder in ("", "there", "everyone", "how are you")


def _detect_scope(text: str) -> str:
    normalized = _normalize_text(text)
    is_phone_query = _contains_keyword(normalized, PHONE_KEYWORDS)
    is_laptop_query = _contains_keyword(normalized, LAPTOP_KEYWORDS)

    if is_phone_query and not is_laptop_query:
        return "phones"
    if is_laptop_query and not is_phone_query:
        return "laptops"
    if is_phone_query and is_laptop_query:
        return "both"

    # If query is generic or outside the known phone/laptop keywords,
    # search the full catalog instead of refusing the request.
    return "both"


def _explicit_scope(text: str) -> Optional[str]:
    scope = _detect_scope(text)
    if scope == "both" and not (
        _contains_keyword(text, PHONE_KEYWORDS) and _contains_keyword(text, LAPTOP_KEYWORDS)
    ):
        return None
    return scope


def _get_session_context(session_id: Optional[str]) -> Optional[Dict]:
    if not session_id:
        return None
    now = time.time()
    with _SESSION_LOCK:
        stale = [key for key, value in _SESSION_CONTEXT.items() if now - value["updated_at"] > _SESSION_TTL_SECONDS]
        for key in stale:
            _SESSION_CONTEXT.pop(key, None)
        context = _SESSION_CONTEXT.get(session_id)
        return context.copy() if context else None


def _remember_session(
    session_id: Optional[str],
    query: str,
    scope: str,
    products: List[Dict],
    *,
    preference_query: Optional[str] = None,
    context_products: Optional[List[Dict]] = None,
    focused_products: Optional[List[Dict]] = None,
) -> None:
    if not session_id or not products:
        return
    with _SESSION_LOCK:
        if len(_SESSION_CONTEXT) >= _MAX_SESSIONS and session_id not in _SESSION_CONTEXT:
            oldest = min(_SESSION_CONTEXT, key=lambda key: _SESSION_CONTEXT[key]["updated_at"])
            _SESSION_CONTEXT.pop(oldest, None)
        _SESSION_CONTEXT[session_id] = {
            "query": query,
            "preference_query": preference_query or query,
            "scope": scope,
            "products": [
                product.copy() for product in (context_products or products)[:5]
            ],
            "focused_products": [
                product.copy() for product in (focused_products or products[:1])[:1]
            ],
            "updated_at": time.time(),
        }


def _is_contextual_follow_up(query: str, context: Optional[Dict]) -> bool:
    return bool(context and _explicit_scope(query) is None and FOLLOW_UP_PATTERN.search(query))


def _is_refinement(query: str, context: Optional[Dict]) -> bool:
    return bool(context and _explicit_scope(query) is None and REFINEMENT_PATTERN.search(query))


def _focus_from_query(query: str, products: List[Dict]) -> List[Dict]:
    normalized_query = _normalize_text(query)
    ordinal_indexes = {"first": 0, "second": 1, "third": 2}
    for word, index in ordinal_indexes.items():
        if re.search(rf"\b{word}\b", normalized_query) and index < len(products):
            return [products[index]]
    matches = []
    for product in products:
        name = _normalize_text(product.get("normalized_name") or product.get("name", ""))
        if name and name in normalized_query:
            matches.append(product)
    return matches


def _numeric_price(value) -> float:
    raw = str(value or "").lower().replace(",", "")
    match = re.search(r"(\d+(?:\.\d+)?)\s*(lakh|lac|million|m|k)?", raw)
    if not match:
        return 0.0
    amount = float(match.group(1))
    unit = match.group(2) or ""
    if unit == "k":
        amount *= 1_000
    elif unit in ("lakh", "lac"):
        amount *= 100_000
    elif unit in ("million", "m"):
        amount *= 1_000_000
    return amount


def _no_matches_reply(user_query: str) -> str:
    if prefers_roman_urdu(user_query):
        return (
            "Aap ke budget aur requirements ke andar catalog mein matching laptop ya phone nahi mila. "
            "Budget barhane se pehle RAM, GPU, brand ya doosri requirement thori relax karke dekhein."
        )
    return (
        "I couldn't find a catalog product within all of those requirements. "
        "Before increasing the budget, try relaxing a RAM, GPU, brand, or other specification."
    )


def _detect_scope_from_products(products: List[Dict]) -> str:
    categories = " ".join(str(product.get("category", "")) for product in products).lower()
    has_phones = "phone" in categories or "mobile" in categories
    has_laptops = "laptop" in categories or "notebook" in categories
    if has_phones and not has_laptops:
        return "phones"
    if has_laptops and not has_phones:
        return "laptops"
    return "both"


def _normalize_product(product: Dict, default_category: str = "") -> Dict:
    normalized = product.copy()
    normalized["image_url"] = (
        normalized.get("image_url")
        or normalized.get("image")
        or normalized.get("imageLink")
        or normalized.get("image_link")
        or ""
    )
    if default_category and not normalized.get("category"):
        normalized["category"] = default_category
    return normalized


def _merge_products(*product_lists: List[Dict]) -> List[Dict]:
    merged = []
    seen = set()
    for products in product_lists:
        for product in products:
            key = product.get("product_id") or product.get("id") or product.get("url") or product.get("name")
            if not key or key in seen:
                continue
            seen.add(key)
            merged.append(product)
    return merged


def _load_products(scope: str) -> List[Dict]:
    phones = []
    laptops = []
    fallback = []

    if scope in ("phones", "both"):
        phones = [_normalize_product(p, "Phones") for p in fetch_products("phones")]
    if scope in ("laptops", "both"):
        laptops = [_normalize_product(p, "Laptops") for p in fetch_products("laptops")]
    if scope == "both":
        fallback = [_normalize_product(p) for p in fetch_products("products")]

    return _merge_products(phones, laptops, fallback)


@router.post("/send-message")
async def send_chat_message(chat_message: ChatMessage):
    """
    Process chat message and return AI response with product recommendations.
    
    This endpoint:
    1. Takes user query about products
    2. Uses recommendation engine to find matching products
    3. Generates contextual AI response
    4. Returns both response and recommended products
    """
    try:
        request_started_at = time.perf_counter()
        user_query = chat_message.message or ""
        normalized_query = normalize_user_query(user_query)

        if _is_greeting(user_query):
            return {
                "reply": "Hello! Main mobile aur laptop recommendations mein madad kar sakta hoon. Aap apni requirement batain.",
                "products": [],
            }

        scope = _detect_scope(normalized_query)
        product_id = chat_message.product_id
        session_context = _get_session_context(chat_message.session_id)

        if session_context and _explicit_scope(normalized_query) is None:
            scope = session_context.get("scope", scope)

        products = _load_products(scope)
        if product_id:
            all_products = _load_products('both')
            normalized_id = str(product_id).strip().lower()
            matched = [
                p for p in all_products
                if normalized_id in {
                    str(p.get('product_id') or '').strip().lower(),
                    str(p.get('id') or '').strip().lower(),
                    str(p.get('name') or '').strip().lower(),
                    str(p.get('normalized_name') or '').strip().lower(),
                }
            ]
            if matched:
                recommended_products = matched[:1]
                # Short-circuit explanation for single product focus
                ai_response = generate_explanation(
                    user_query=user_query,
                    products=recommended_products,
                    conversation_context=session_context,
                )
                _remember_session(chat_message.session_id, user_query, _detect_scope_from_products(recommended_products), recommended_products)
                return {
                    "reply": ai_response,
                    "products": recommended_products,
                }
            else:
                return {
                    "reply": "I couldn't find that product in the catalog. Please try asking about another recommended item.",
                    "products": [],
                }
        ranking_query = normalized_query
        preference_query = (
            session_context.get("preference_query")
            if session_context
            else normalized_query
        ) or normalized_query
        context_products_for_memory = None
        focused_products_for_memory = None
        contextual_follow_up = False
        if _is_refinement(normalized_query, session_context):
            ranking_query = f"Follow-up requirement: {normalized_query}"
            if re.search(r"\b(?:cheap|cheaper|less expensive)\b", normalized_query):
                focused = session_context.get("focused_products") or session_context.get("products") or []
                current_price = _numeric_price(focused[0].get("price")) if focused else 0
                if current_price > 1:
                    ranking_query += f". Must be under {int(current_price - 1)}"
            ranking_query += f". Previous preference: {preference_query}"
        elif _is_contextual_follow_up(normalized_query, session_context):
            contextual_follow_up = True
            recent_products = session_context.get("products", [])
            named_products = _focus_from_query(normalized_query, recent_products)
            current_focus = session_context.get("focused_products", [])
            asks_to_choose = bool(
                re.search(
                    r"\b(?:which|best|better|most|least|highest|lowest)\b",
                    normalized_query,
                )
            )
            if asks_to_choose and not named_products:
                products = recent_products
            elif (
                named_products
                and current_focus
                and re.search(r"\b(?:compare|comparison|difference)\b", normalized_query)
            ):
                products = _merge_products(current_focus, named_products)
            else:
                products = named_products or current_focus or recent_products
            context_products_for_memory = recent_products
            focused_products_for_memory = products[:1]

        products_loaded_at = time.perf_counter()
        print(
            f"[CHAT_PERF] load_products scope={scope} count={len(products)} "
            f"elapsed_ms={(products_loaded_at - request_started_at) * 1000:.1f}"
        )
        
        if not products:
            return {
                "reply": _no_matches_reply(user_query),
                "products": []
            }
        
        # Get product recommendations from BERT similarity ranking.
        recommended_products = recommend_products(
            ranking_query,
            products,
            top_n=5
        )
        if not recommended_products:
            return {
                "reply": _no_matches_reply(user_query),
                "products": [],
            }
        ranked_at = time.perf_counter()
        print(
            f"[CHAT_PERF] recommend_products count={len(recommended_products)} "
            f"elapsed_ms={(ranked_at - products_loaded_at) * 1000:.1f}"
        )

        verification_context = build_verification_context(user_query, recommended_products)

        # Ask LLM to explain why these products match the user intent.
        ai_response = generate_explanation(
            user_query=user_query,
            products=recommended_products,
            verification_context=verification_context,
            conversation_context=session_context,
        )
        explained_at = time.perf_counter()
        print(
            f"[CHAT_PERF] generate_explanation elapsed_ms={(explained_at - ranked_at) * 1000:.1f} "
            f"total_ms={(explained_at - request_started_at) * 1000:.1f}"
        )
        
        _remember_session(
            chat_message.session_id,
            ranking_query,
            scope,
            recommended_products,
            preference_query=preference_query,
            context_products=context_products_for_memory,
            focused_products=(
                focused_products_for_memory
                if contextual_follow_up
                else recommended_products[:1]
            ),
        )
        return {
            "reply": ai_response,
            "products": recommended_products
        }
    
    except Exception as e:
        print(f"Chat error: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Error processing message: {str(e)}"
        )


@router.post("/send")
async def send_chat_message_legacy(chat_message: ChatMessage):
    """
    Backward-compatible endpoint alias.
    """
    return await send_chat_message(chat_message)


@router.get("/history")
async def get_chat_history():
    """
    Get chat history for the current user.
    Note: This is a placeholder. Implement user-specific history with authentication.
    """
    return {
        "messages": [],
        "message": "Chat history feature coming soon"
    }


@router.post("/save")
async def save_chat_message(message: dict):
    """
    Save a chat message to history.
    Note: This is a placeholder. Implement with database storage.
    """
    return {
        "success": True,
        "message": "Message saved successfully"
    }
