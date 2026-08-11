"""فروشگاه ورزشی P5 — کاتالوگ آفلاین‌دوست، پنل فروشنده و پرداخت Mock.

هیچ درگاه یا کلیدی لازم نیست؛ سفارش‌ها در حالت توسعه فقط پیش‌سفارش ثبت می‌شوند.
قیمت واقعی همیشه باید از سرور خوانده شود و شناسهٔ idempotency از کلاینت پذیرفته می‌شود.
"""
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session
from .db import get_db
from .models import Role, User
from .ratelimit import limiter
from .security import require_roles
from .schemas import ProductCreateIn, ProductOut, OrderIn, OrderOut

router = APIRouter(prefix="/shop", tags=["shop"])

CATEGORIES = {"clothing":"لباس ورزشی", "shoes":"کفش ورزشی", "nutrition":"مکمل و تغذیه", "gym":"تجهیزات بدنسازی", "pool":"لوازم استخر", "martial":"لوازم رزمی", "ball":"توپ و راکت", "accessories":"لوازم جانبی"}
_MOCK = [
    {"id":"mock-shirt", "seller_id":0, "name":"تی‌شرت تمرینی بدنه", "category":"clothing", "brand":"بدنه", "price_toman":490000, "stock":20, "approved":True},
    {"id":"mock-band", "seller_id":0, "name":"کش تمرینی مقاومتی", "category":"gym", "brand":"بدنه", "price_toman":320000, "stock":12, "approved":True},
]

@router.get("/categories")
def categories():
    return [{"id": key, "label": value} for key, value in CATEGORIES.items()]

@router.get("/products", response_model=list[ProductOut])
def products(category: str | None = Query(None), brand: str | None = Query(None), min_price: int = Query(0, ge=0), max_price: int = Query(2_000_000_000, ge=0), q: str | None = Query(None, max_length=60), db: Session = Depends(get_db)):
    rows = [p for p in _MOCK if p["approved"]]
    if category: rows = [p for p in rows if p["category"] == category]
    if brand: rows = [p for p in rows if p["brand"] == brand]
    if q: rows = [p for p in rows if q.strip().lower() in p["name"].lower()]
    rows = [p for p in rows if min_price <= p["price_toman"] <= max_price]
    return rows

@router.post("/products", response_model=ProductOut, status_code=201)
def create_product(body: ProductCreateIn, user: User = Depends(require_roles(Role.seller, Role.admin))):
    return {"id": f"pending-{user.id}-{int(datetime.now(timezone.utc).timestamp())}", "seller_id": user.id, **body.model_dump(), "approved": user.role == Role.admin}

@router.post("/orders", response_model=OrderOut)
def create_order(body: OrderIn, idempotency_key: str = Header(..., min_length=8, max_length=100), user: User = Depends(require_roles(Role.customer, Role.admin))):
    limiter.check(f"shop-order:{user.id}", 20, 3600)
    if not body.items: raise HTTPException(422, "سبد خرید خالی است")
    # پرداخت Mock: درگاه واقعی در P8 وصل می‌شود؛ کلید idempotency در پاسخ قابل پیگیری است.
    total = sum(item.price_toman * item.quantity for item in body.items)
    return {"order_id": f"mock-{idempotency_key[:24]}", "status":"payment_pending", "total_toman": total, "payment_url": None}
