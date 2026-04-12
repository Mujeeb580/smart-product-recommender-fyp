from datetime import datetime, timezone
from typing import Any, Dict, List

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.recommendation.engine import recommend_products
from app.recommendation.firestore import fetch_products, get_chat_history, save_chat_message


router = APIRouter(prefix="/chat", tags=["Chat"])


class ChatMessage(BaseModel):
    message: str


def generate_ai_response(user_message: str) -> str:
    message = user_message.lower()
    if any(word in message for word in ["budget", "cheap", "affordable", "inexpensive"]):
        return "I found budget-friendly options with good value."
    if any(word in message for word in ["flagship", "premium", "best", "high-end"]):
        return "I found premium and flagship options for you."
    if any(word in message for word in ["game", "gaming"]):
        return "Here are products suitable for gaming performance."
    if any(word in message for word in ["camera", "photo", "photography"]):
        return "I focused on products with stronger camera features."
    return "Here are product recommendations based on your request."


@router.post("/send-message")
async def send_chat_message(chat_message: ChatMessage):
    try:
        products = fetch_products(limit=600)
        recommended = recommend_products(chat_message.message, products, top_n=5)

        reply = generate_ai_response(chat_message.message)
        message_payload: Dict[str, Any] = {
            "message": chat_message.message,
            "reply": reply,
            "recommended_count": len(recommended),
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
