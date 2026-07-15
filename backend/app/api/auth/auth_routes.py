from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel, EmailStr
from firebase_admin import auth

router = APIRouter(prefix="/auth", tags=["Authentication"])


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str | None = None
    display_name: str | None = None
    photo_url: str | None = None


def _clean_optional(value: str | None) -> str | None:
    if value is None:
        return None

    stripped = value.strip()
    return stripped or None


@router.post("/register")
def register_user(payload: RegisterRequest):
    try:
        user_kwargs = {"email": payload.email}

        password = _clean_optional(payload.password)
        display_name = _clean_optional(payload.display_name)
        photo_url = _clean_optional(payload.photo_url)

        if password:
            user_kwargs["password"] = password
        if display_name:
            user_kwargs["display_name"] = display_name
        if photo_url:
            user_kwargs["photo_url"] = photo_url

        try:
            user = auth.create_user(**user_kwargs)
            return {"message": "User registered successfully", "uid": user.uid}
        except Exception:
            existing_user = auth.get_user_by_email(payload.email)

            update_kwargs = {}
            if password:
                update_kwargs["password"] = password
            if display_name:
                update_kwargs["display_name"] = display_name
            if photo_url:
                update_kwargs["photo_url"] = photo_url

            if update_kwargs:
                user = auth.update_user(existing_user.uid, **update_kwargs)
            else:
                user = existing_user

            return {"message": "User profile synchronized successfully", "uid": user.uid}
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
