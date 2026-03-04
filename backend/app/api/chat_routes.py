from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.recommendation.firestore import fetch_products
from app.recommendation.engine import recommend_products

router = APIRouter(prefix="/chat", tags=["Chat"])


class ChatMessage(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str
    products: list


@router.post("/send")
async def send_chat_message(chat_message: ChatMessage):
    """
    Process chat message and return AI response with product recommendations.
    """
    try:
        user_message = chat_message.message.lower()
        
        # Fetch products from Firestore
        products = fetch_products(collection_name="products")
        
        if not products:
            return {
                "reply": "I'm sorry, but I couldn't find any products at the moment. Please try again later.",
                "products": []
            }
        
        # Generate AI response based on intent
        ai_response = generate_ai_response(user_message)
        
        # Get product recommendations based on the message
        recommended_products = recommend_products(
            chat_message.message,
            products,
            top_n=5
        )
        
        return {
            "reply": ai_response,
            "products": recommended_products
        }
    
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error processing message: {str(e)}"
        )


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


def generate_ai_response(user_message: str) -> str:
    """
    Generate contextual AI responses based on user intent.
    """
    message = user_message.lower()
    
    # Budget/Affordable intent
    if any(word in message for word in ['budget', 'cheap', 'affordable', 'inexpensive']):
        return "I found some great budget-friendly options for you! These products offer excellent value for money."
    
    # Premium/Flagship intent
    elif any(word in message for word in ['flagship', 'premium', 'best', 'high-end', 'expensive']):
        return "Here are our top premium products! These flagship devices offer cutting-edge features and performance."
    
    # Gaming intent
    elif any(word in message for word in ['game', 'gaming', 'gamer']):
        return "Perfect for gaming! I've found products with excellent performance for your gaming needs."
    
    # Camera/Photography intent
    elif any(word in message for word in ['camera', 'photo', 'photography', 'picture']):
        return "Great choice for photography! Here are products with excellent camera capabilities."
    
    # Battery intent
    elif any(word in message for word in ['battery', 'long-lasting', 'charge']):
        return "Battery life is important! These products offer excellent battery performance."
    
    # Performance intent
    elif any(word in message for word in ['fast', 'powerful', 'performance', 'speed']):
        return "Speed matters! Here are high-performance products that won't slow you down."
    
    # Brand specific
    elif any(word in message for word in ['samsung', 'apple', 'iphone', 'xiaomi', 'oppo', 'vivo']):
        return "I found products from your preferred brand! Here are the best matches."
    
    # General recommendation
    else:
        return "Based on your query, I've found these recommended products for you. Let me know if you need more specific suggestions!"
