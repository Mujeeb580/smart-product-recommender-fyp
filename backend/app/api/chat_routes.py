import re
from typing import Dict, List

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.recommendation.firestore import fetch_products
from app.recommendation.engine import recommend_products
from app.services.llm_service import generate_explanation

router = APIRouter(prefix="/chat", tags=["Chat"])


class ChatMessage(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str
    products: list


GREETING_PATTERN = re.compile(
    r"\b(hi|hello|hey|salam|assalam\s*o\s*alaikum|aoa|aslam\s*o\s*alaikum|kia\s*haal|kese\s*ho)\b",
    re.IGNORECASE,
)

PHONE_KEYWORDS = ("phone", "phones", "mobile", "mobiles", "smartphone")
LAPTOP_KEYWORDS = ("laptop", "laptops", "notebook")
UNSUPPORTED_KEYWORDS = (
    "tablet",
    "earbuds",
    "earbud",
    "watch",
    "smart watch",
    "headphone",
    "tv",
    "fridge",
    "refrigerator",
)


def _normalize_text(text: str) -> str:
    return (text or "").strip().lower()


def _is_greeting(text: str) -> bool:
    return bool(GREETING_PATTERN.search(_normalize_text(text)))


def _detect_scope(text: str) -> str:
    normalized = _normalize_text(text)
    is_phone_query = any(k in normalized for k in PHONE_KEYWORDS)
    is_laptop_query = any(k in normalized for k in LAPTOP_KEYWORDS)

    if is_phone_query and not is_laptop_query:
        return "phones"
    if is_laptop_query and not is_phone_query:
        return "laptops"
    if is_phone_query and is_laptop_query:
        return "both"

    if any(k in normalized for k in UNSUPPORTED_KEYWORDS):
        return "unsupported"

    # If query is generic, search both available categories.
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
        user_query = chat_message.message or ""

        if _is_greeting(user_query):
            return {
                "reply": "Hello! Main mobile aur laptop recommendations mein madad kar sakta hoon. Aap apni requirement batain.",
                "products": [],
            }

        scope = _detect_scope(user_query)
        if scope == "unsupported":
            return {
                "reply": "I am only restricted to answer mobile and laptop questions only. Main sirf mobile aur laptop se related sawalon ka jawab de sakta hoon.",
                "products": [],
            }

        products = _load_products(scope)
        
        if not products:
            return {
                "reply": "I'm sorry, but I couldn't find any products at the moment. Please try again later.",
                "products": []
            }
        
        # Get product recommendations from BERT similarity ranking.
        recommended_products = recommend_products(
            user_query,
            products,
            top_n=5
        )

        # Ask LLM to explain why these products match the user intent.
        ai_response = generate_explanation(
            user_query=user_query,
            products=recommended_products,
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
