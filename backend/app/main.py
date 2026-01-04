from fastapi import FastAPI
from app.core import firebase  # initializes Firebase

app = FastAPI(title="Smart Product Recommendation API")

@app.get("/")
def root():
    return {"status": "Backend + Firebase connected"}
