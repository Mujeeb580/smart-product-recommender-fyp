import os
import secrets
import threading
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Literal, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, Header, HTTPException, Query, status
from firebase_admin import auth
from pydantic import BaseModel, Field

from app.core.firebase import firestore_db
from app.recommendation.firestore import fetch_products
from app.scraping.priceoye_scraper import scrape_laptops, scrape_phones


router = APIRouter(prefix="/admin", tags=["Admin"])
protected_router = APIRouter(dependencies=[Depends(lambda authorization=Header(None): _require_admin(authorization))])

_admin_sessions: set[str] = set()
_product_collections = {"products", "phones", "laptops"}
_scrape_jobs: Dict[str, Dict[str, Any]] = {}
_scrape_job_lock = threading.Lock()
_active_scrape_job_id: Optional[str] = None


class AdminLoginRequest(BaseModel):
    username: str
    password: str


class ScrapeRequest(BaseModel):
    mode: Literal[
        "phones",
        "laptops",
        "all",
        "new_phones",
        "new_laptops",
    ]
    max_pages: int = Field(default=100, ge=1, le=100)
    max_products: int = Field(default=0, ge=0, le=500)


def _admin_username() -> str:
    return os.getenv("ADMIN_USERNAME", "admin@fyndo.com").strip().lower()


def _admin_password() -> str:
    return os.getenv("ADMIN_PASSWORD", "Admin@123")


def _require_admin(authorization: Optional[str]) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Admin login required")

    token = authorization.removeprefix("Bearer ").strip()
    if not token or token not in _admin_sessions:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired admin session")
    return token


def _validate_collection(name: str) -> str:
    normalized = str(name or "products").strip().lower()
    if normalized not in _product_collections:
        raise HTTPException(status_code=400, detail="Collection must be products, phones, or laptops")
    return normalized


def _count_for(collection_name: str) -> int:
    return sum(1 for _ in firestore_db.collection(collection_name).stream())


def _product_response(document_id: str, collection: str, data: Dict[str, Any]) -> Dict[str, Any]:
    result = dict(data)
    result["id"] = document_id
    result["product_id"] = result.get("product_id") or document_id
    result["collection"] = collection
    result["image"] = result.get("image") or result.get("image_url") or ""
    return result


def _catalog_quality(rows_by_collection: Dict[str, List[Dict[str, Any]]]) -> Dict[str, Any]:
    """Build read-only catalog diagnostics for the admin dashboard."""
    totals = {
        "items": 0,
        "missing_price": 0,
        "missing_image": 0,
        "missing_details": 0,
        "duplicates": 0,
    }
    collection_stats: List[Dict[str, Any]] = []

    for collection, rows in sorted(rows_by_collection.items()):
        seen: set[str] = set()
        stats = {
            "name": collection,
            "items": len(rows),
            "missing_price": 0,
            "missing_image": 0,
            "missing_details": 0,
            "duplicates": 0,
        }
        for row in rows:
            try:
                price = float(row.get("price_numeric", row.get("price", 0)) or 0)
            except (TypeError, ValueError):
                price = 0
            if price <= 0:
                stats["missing_price"] += 1
            if not str(row.get("image_url") or row.get("image") or "").strip():
                stats["missing_image"] += 1
            if not any(
                str(row.get(field) or "").strip()
                for field in ("specs", "description", "processor", "ram", "storage")
            ):
                stats["missing_details"] += 1

            identity = "|".join(
                str(row.get(field) or "").strip().casefold()
                for field in ("brand", "name")
            )
            if identity != "|":
                if identity in seen:
                    stats["duplicates"] += 1
                seen.add(identity)

        for key in totals:
            if key == "items":
                totals[key] += stats[key]
            else:
                totals[key] += stats[key]
        collection_stats.append(stats)

    total_items = totals["items"]
    issue_count = sum(
        totals[key]
        for key in ("missing_price", "missing_image", "missing_details", "duplicates")
    )
    possible_checks = max(total_items * 4, 1)
    quality_score = max(0, round(100 * (1 - issue_count / possible_checks)))
    return {
        **totals,
        "quality_score": quality_score,
        "collections": collection_stats,
        "checked_at": datetime.now(timezone.utc).isoformat(),
    }


def _clean_product_payload(payload: Dict[str, Any]) -> tuple[str, Dict[str, Any]]:
    data = dict(payload)
    collection = _validate_collection(data.pop("collection", "products"))
    name = str(data.get("name") or "").strip()
    brand = str(data.get("brand") or "").strip()
    if not name or not brand:
        raise HTTPException(status_code=400, detail="Product name and brand are required")

    try:
        price = float(data.get("price", 0))
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="Price must be a number")
    if price < 0:
        raise HTTPException(status_code=400, detail="Price cannot be negative")

    data["name"] = name
    data["brand"] = brand
    data["price"] = price
    data["price_numeric"] = price
    data["image_url"] = str(data.get("image_url") or data.get("image") or "").strip()
    data["image"] = data["image_url"]
    data["category"] = str(data.get("category") or collection).strip()
    data["updated_at"] = datetime.now(timezone.utc).isoformat()
    return collection, data


@router.post("/login")
async def admin_login(payload: AdminLoginRequest):
    username_ok = secrets.compare_digest(payload.username.strip().lower(), _admin_username())
    password_ok = secrets.compare_digest(payload.password, _admin_password())
    if not (username_ok and password_ok):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin username or password")

    token = secrets.token_urlsafe(48)
    _admin_sessions.add(token)
    return {"ok": True, "token": token, "username": _admin_username()}


@protected_router.post("/logout")
async def admin_logout(authorization: Optional[str] = Header(None)):
    token = _require_admin(authorization)
    _admin_sessions.discard(token)
    return {"ok": True}


@protected_router.get("/session")
async def admin_session():
    return {"ok": True, "username": _admin_username()}


@protected_router.get("/overview")
async def admin_overview():
    try:
        counts = {
            "products": _count_for("products"),
            "phones": _count_for("phones"),
            "laptops": _count_for("laptops"),
            "chat_history": _count_for("chat_history"),
        }
        counts["users"] = sum(1 for _ in auth.list_users().iterate_all())
        counts["total"] = counts["products"] + counts["phones"] + counts["laptops"]
        return counts
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error loading admin overview: {exc}")


@protected_router.get("/health")
async def admin_health():
    try:
        rows_by_collection = {
            name: fetch_products(name, limit=5000)
            for name in sorted(_product_collections)
        }
        return {
            "ok": True,
            "firestore": "connected",
            **_catalog_quality(rows_by_collection),
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error checking catalog health: {exc}")


@protected_router.get("/products")
async def admin_products(
    collection: str = Query("products", description="products/phones/laptops"),
    limit: int = Query(200, ge=1, le=5000),
    q: Optional[str] = Query(None),
):
    try:
        collection = _validate_collection(collection)
        rows: List[Dict] = fetch_products(collection, limit=limit)
        if q:
            needle = q.lower()
            rows = [
                item
                for item in rows
                if needle in str(item.get("name", "")).lower()
                or needle in str(item.get("brand", "")).lower()
                or needle in str(item.get("category", "")).lower()
            ]
        return {"products": rows[:limit], "count": len(rows[:limit]), "collection": collection, "query": q}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error loading admin products: {exc}")


@protected_router.post("/products", status_code=status.HTTP_201_CREATED)
async def create_product(payload: Dict[str, Any]):
    collection, data = _clean_product_payload(payload)
    document = firestore_db.collection(collection).document()
    data["product_id"] = document.id
    data["created_at"] = datetime.now(timezone.utc).isoformat()
    document.set(data)
    return {"product": _product_response(document.id, collection, data)}


@protected_router.put("/products/{collection}/{product_id}")
async def update_product(collection: str, product_id: str, payload: Dict[str, Any]):
    source_collection = _validate_collection(collection)
    source_document = firestore_db.collection(source_collection).document(product_id)
    snapshot = source_document.get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Product not found")

    target_collection, changes = _clean_product_payload(payload)
    merged = dict(snapshot.to_dict() or {})
    merged.update(changes)
    merged["product_id"] = product_id

    target_document = firestore_db.collection(target_collection).document(product_id)
    target_document.set(merged)
    if target_collection != source_collection:
        source_document.delete()
    return {"product": _product_response(product_id, target_collection, merged)}


@protected_router.delete("/products/{collection}/{product_id}")
async def delete_product(collection: str, product_id: str):
    collection = _validate_collection(collection)
    document = firestore_db.collection(collection).document(product_id)
    if not document.get().exists:
        raise HTTPException(status_code=404, detail="Product not found")
    document.delete()
    return {"ok": True, "deleted_id": product_id}


@protected_router.get("/collections")
async def admin_collections():
    try:
        data = [{"name": name, "count": _count_for(name)} for name in sorted(_product_collections)]
        return {"collections": data}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error loading collections: {exc}")


@protected_router.get("/users")
async def admin_users(limit: int = Query(500, ge=1, le=1000)):
    try:
        users = []
        for user in auth.list_users(max_results=min(limit, 1000)).iterate_all():
            users.append(
                {
                    "uid": user.uid,
                    "email": user.email or "",
                    "display_name": user.display_name or "",
                    "disabled": user.disabled,
                    "email_verified": user.email_verified,
                    "created_at": user.user_metadata.creation_timestamp,
                    "last_sign_in": user.user_metadata.last_sign_in_timestamp,
                    "providers": [provider.provider_id for provider in user.provider_data],
                }
            )
            if len(users) >= limit:
                break
        return {"users": users, "count": len(users)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error loading users: {exc}")


@protected_router.delete("/users/{uid}")
async def delete_user(uid: str):
    try:
        auth.delete_user(uid)
        return {"ok": True, "deleted_uid": uid}
    except auth.UserNotFoundError:
        raise HTTPException(status_code=404, detail="User not found")
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Error deleting user: {exc}")


@protected_router.get("/scrape/verify-firestore")
async def verify_firestore_connection():
    try:
        docs = list(firestore_db.collection("phones").limit(1).stream())
        return {"ok": True, "sample_docs": len(docs)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Firestore connection failed: {exc}")


def _run_scraper_mode(
    mode: str,
    max_pages: int = 100,
    max_products: int = 0,
) -> Dict[str, Any]:
    results: List[Dict] = []
    list(firestore_db.collection("phones").limit(1).stream())

    if mode == "phones":
        results.append(scrape_phones(
            stop_on_existing=False,
            max_pages=max_pages,
            max_products=max_products,
        ))
    elif mode == "laptops":
        results.append(scrape_laptops(
            stop_on_existing=False,
            max_pages=max_pages,
            max_products=max_products,
        ))
    elif mode == "all":
        results.append(scrape_phones(
            stop_on_existing=False,
            max_pages=max_pages,
            max_products=max_products,
        ))
        results.append(scrape_laptops(
            stop_on_existing=False,
            max_pages=max_pages,
            max_products=max_products,
        ))
    elif mode == "new_phones":
        results.append(scrape_phones(
            stop_on_existing=True,
            max_pages=max_pages,
            max_products=max_products,
        ))
    elif mode == "new_laptops":
        results.append(scrape_laptops(
            stop_on_existing=True,
            max_pages=max_pages,
            max_products=max_products,
        ))

    return {
        "ok": True,
        "mode": mode,
        "saved": sum(int(item.get("saved", 0)) for item in results),
        "updated": sum(int(item.get("updated", 0)) for item in results),
        "errors": sum(int(item.get("errors", 0)) for item in results),
        "results": results,
    }


def _execute_scrape_job(
    job_id: str,
    mode: str,
    max_pages: int,
    max_products: int,
) -> None:
    global _active_scrape_job_id
    with _scrape_job_lock:
        _scrape_jobs[job_id]["status"] = "running"
        _scrape_jobs[job_id]["started_at"] = datetime.now(timezone.utc).isoformat()

    try:
        result = _run_scraper_mode(
            mode,
            max_pages=max_pages,
            max_products=max_products,
        )
        with _scrape_job_lock:
            _scrape_jobs[job_id].update(
                status="completed",
                result=result,
                finished_at=datetime.now(timezone.utc).isoformat(),
            )
    except Exception as exc:
        with _scrape_job_lock:
            _scrape_jobs[job_id].update(
                status="failed",
                error=str(exc),
                finished_at=datetime.now(timezone.utc).isoformat(),
            )
    finally:
        with _scrape_job_lock:
            if _active_scrape_job_id == job_id:
                _active_scrape_job_id = None


@protected_router.post("/scrape/run", status_code=status.HTTP_202_ACCEPTED)
async def run_scraper(payload: ScrapeRequest, background_tasks: BackgroundTasks):
    global _active_scrape_job_id
    with _scrape_job_lock:
        if _active_scrape_job_id:
            active = _scrape_jobs.get(_active_scrape_job_id, {})
            if active.get("status") in {"queued", "running"}:
                raise HTTPException(
                    status_code=409,
                    detail=f"A scraper job is already {active.get('status')}",
                )

        job_id = uuid.uuid4().hex
        _active_scrape_job_id = job_id
        _scrape_jobs[job_id] = {
            "job_id": job_id,
            "mode": payload.mode,
            "max_pages": payload.max_pages,
            "max_products": payload.max_products,
            "status": "queued",
            "created_at": datetime.now(timezone.utc).isoformat(),
        }

    background_tasks.add_task(
        _execute_scrape_job,
        job_id,
        payload.mode,
        payload.max_pages,
        payload.max_products,
    )
    return _scrape_jobs[job_id]


@protected_router.get("/scrape/status/{job_id}")
async def scraper_status(job_id: str):
    with _scrape_job_lock:
        job = _scrape_jobs.get(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Scraper job not found")
        return dict(job)


router.include_router(protected_router)
