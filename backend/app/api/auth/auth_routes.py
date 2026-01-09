from fastapi import APIRouter, HTTPException, Header
from firebase_admin import auth

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register")
def register_user(email: str, password: str):
    try:
        user = auth.create_user(email=email, password=password)
        return {"message": "User registered successfully", "uid": user.uid}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/login")
def login_user():
    return {
        "message": "Login handled by Firebase on frontend. Token required for protected routes."
    }


@router.get("/verify-token")
def verify_token(authorization: str = Header(...)):
    try:
        token = authorization.split(" ")[1]
        decoded_token = auth.verify_id_token(token)
        return {"uid": decoded_token["uid"], "status": "Token is valid"}
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
