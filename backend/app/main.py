from fastapi import FastAPI
from app.core import firebase
from app.api.auth.auth_routes import router as auth_router

app = FastAPI(title="Smart Product Recommendation API")

app.include_router(auth_router)

@app.get("/")
def root():
    return {"status": "Backend running with Auth"}
