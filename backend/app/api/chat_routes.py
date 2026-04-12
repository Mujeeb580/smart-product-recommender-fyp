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
        # Fetch products from Firestore
        products = fetch_products(collection_name="products")
        
        if not products:
            return {
                "reply": "I'm sorry, but I couldn't find any products at the moment. Please try again later.",
                "products": []
            }
        
        # Get product recommendations from BERT similarity ranking.
        recommended_products = recommend_products(
            chat_message.message,
            products,
            top_n=5
        )

        # Ask LLM to explain why these products match the user intent.
        ai_response = generate_explanation(
            user_query=chat_message.message,
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
