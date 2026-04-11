from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field
from firebase_admin import auth


router = APIRouter(prefix="/auth", tags=["Authentication"])


class RegisterRequest(BaseModel):
    email: str
    password: str = Field(min_length=6)


@router.post("/register")
def register_user(payload: RegisterRequest):
    try:
        user = auth.create_user(email=payload.email, password=payload.password)
        return {"message": "User registered successfully", "uid": user.uid}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/login")
def login_user():
    return {
        "message": "Login is handled by Firebase in frontend. Send ID token for protected requests."
    }


@router.get("/verify-token")
def verify_token(authorization: str = Header(...)):
    try:
        token = authorization.split(" ")[1]
        decoded = auth.verify_id_token(token)
        return {"uid": decoded["uid"], "status": "Token is valid"}
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
