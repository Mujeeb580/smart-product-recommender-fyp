import re
import time
from typing import Dict, List, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.recommendation.firestore import fetch_products
from app.recommendation.engine import recommend_products
from app.services.llm_service import generate_explanation
from app.services.web_verifier import build_verification_context

router = APIRouter(prefix="/chat", tags=["Chat"])


class ChatMessage(BaseModel):
    message: str
    product_id: Optional[str] = None


class ChatResponse(BaseModel):
    reply: str
    products: list


GREETING_PATTERN = re.compile(
    r"\b(hi|hello|hey|salam|assalam\s*o\s*alaikum|aoa|aslam\s*o\s*alaikum|kia\s*haal|kese\s*ho)\b",
    re.IGNORECASE,
)

PHONE_KEYWORDS = ("phone", "phones", "mobile", "mobiles", "smartphone")
LAPTOP_KEYWORDS = ("laptop", "laptops", "notebook")


def _normalize_text(text: str) -> str:
    return (text or "").strip().lower()


def _contains_keyword(text: str, keywords: tuple[str, ...]) -> bool:
    normalized = _normalize_text(text)
    for keyword in keywords:
        if re.search(rf"\b{re.escape(keyword)}\b", normalized):
            return True
    return False


def _is_greeting(text: str) -> bool:
    return bool(GREETING_PATTERN.search(_normalize_text(text)))


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

        if _is_greeting(user_query):
            return {
                "reply": "Hello! Main mobile aur laptop recommendations mein madad kar sakta hoon. Aap apni requirement batain.",
                "products": [],
            }

        scope = _detect_scope(user_query)
        product_id = getattr(chat_message, 'product_id', None)

        products = _load_products(scope)
        if product_id:
            all_products = _load_products('both')
            matched = [p for p in all_products if (p.get('product_id') == product_id or str(p.get('product_id')) == str(product_id) or p.get('name') == product_id)]
            if matched:
                recommended_products = matched[:1]
                # Short-circuit explanation for single product focus
                ai_response = generate_explanation(user_query=user_query, products=recommended_products)
                return {
                    "reply": ai_response,
                    "products": recommended_products,
                }
            else:
                return {
                    "reply": "I couldn't find that product in the catalog. Please try asking about another recommended item.",
                    "products": [],
                }
        products_loaded_at = time.perf_counter()
        print(
            f"[CHAT_PERF] load_products scope={scope} count={len(products)} "
            f"elapsed_ms={(products_loaded_at - request_started_at) * 1000:.1f}"
        )
        
        if not products:
            return {
                "reply": "I couldn't find any catalog products right now. Please try again later.",
                "products": []
            }
        
        # Get product recommendations from BERT similarity ranking.
        recommended_products = recommend_products(
            user_query,
            products,
            top_n=5
        )
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
        )
        explained_at = time.perf_counter()
        print(
            f"[CHAT_PERF] generate_explanation elapsed_ms={(explained_at - ranked_at) * 1000:.1f} "
            f"total_ms={(explained_at - request_started_at) * 1000:.1f}"
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
