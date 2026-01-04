from fastapi import FastAPI

app = FastAPI(title="Smart Product Recommender API")

@app.get("/")
def root():
    return {"status": "Backend running"}
