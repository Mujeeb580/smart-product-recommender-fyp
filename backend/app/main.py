from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from app.api.auth.auth_routes import router as auth_router
from app.api.product_routes import router as product_router
from app.api.chat_routes import router as chat_router
from app.api.admin_routes import router as admin_router

load_dotenv()

app = FastAPI(title="Smart Product Recommendation API")

# Configure CORS for Flutter frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:*",
        "http://127.0.0.1:*",
        "http://10.0.2.2:*",  # Android emulator
        "*"  # Allow all origins in development (restrict in production)
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth_router)
app.include_router(product_router)
app.include_router(chat_router)
app.include_router(admin_router)

@app.get("/")
def root():
    return {
        "status": "Smart Product Recommender API is running",
        "version": "1.0.0",
        "endpoints": {
            "auth": "/auth",
            "products": "/products",
            "chat": "/chat",
            "admin": "/admin",
        }
    }
