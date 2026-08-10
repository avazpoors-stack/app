"""جستجوی سراسری (P3) — endpoint عمومی، سبک، rate-limit شده و بدون SQL خام.

در فازهای P4/P5/P6 جدول‌های واقعی مکان/محصول/مربی اضافه می‌شوند؛ تا آن زمان
این endpoint مثل اپ، نتیجه‌های نمونه/Mock امن برمی‌گرداند تا قرارداد UI ثابت بماند.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

from fastapi import APIRouter, HTTPException, Query, Request

from .models import utcnow
from .ratelimit import limiter
from .schemas import SearchCategory, SearchOut, SearchResultOut

router = APIRouter(prefix="/search", tags=["search"])


@dataclass(frozen=True)
class _SearchDocument:
    id: str
    title: str
    subtitle: str
    category: SearchCategory
    keywords: str
    source: str = "server"
    coming_soon: bool = False


_DOCUMENTS = [
    _SearchDocument(
        id="exercise_squat",
        title="اسکوات",
        subtitle="حرکت پا · بدون وسیله",
        category=SearchCategory.exercise,
        keywords="اسکوات پا پایین تنه تمرین خانه بدنسازی squat",
    ),
    _SearchDocument(
        id="exercise_plank",
        title="پلانک",
        subtitle="حرکت میان‌تنه · بدون وسیله",
        category=SearchCategory.exercise,
        keywords="پلانک میان تنه شکم core تمرین خانه plank",
    ),
    _SearchDocument(
        id="program_starter",
        title="آغاز",
        subtitle="برنامه مبتدی خانه · عادت‌سازی",
        category=SearchCategory.program,
        keywords="آغاز مبتدی خانه برنامه تمرین عادت سازی starter",
    ),
    _SearchDocument(
        id="program_quick_start",
        title="شروع کوتاه",
        subtitle="برنامه ۱۰ دقیقه‌ای · همه سطوح",
        category=SearchCategory.program,
        keywords="شروع کوتاه سریع ده دقیقه انرژی کم quick start",
    ),
    _SearchDocument(
        id="product_resistance_band",
        title="کش تمرینی",
        subtitle="محصول نمونه فروشگاه · تجهیزات تمرین خانه · فاز P5",
        category=SearchCategory.product,
        keywords="کش تمرینی کش ورزشی تجهیزات بدنسازی خانه فروشگاه محصول",
        coming_soon=True,
    ),
    _SearchDocument(
        id="product_running_shoes",
        title="کفش دویدن",
        subtitle="محصول نمونه فروشگاه · کفش ورزشی · فاز P5",
        category=SearchCategory.product,
        keywords="کفش دویدن رانینگ فروشگاه محصول ورزشی",
        coming_soon=True,
    ),
    _SearchDocument(
        id="venue_pool_sample",
        title="استخر نمونه بدنه",
        subtitle="مکان نمونه · دسته استخر · نقشه نشان در فاز P4",
        category=SearchCategory.venue,
        keywords="استخر شنا مکان ورزشی نشان باشگاه",
        coming_soon=True,
    ),
    _SearchDocument(
        id="venue_gym_sample",
        title="باشگاه بدنسازی نمونه",
        subtitle="مکان نمونه · دسته بدنسازی · فاز P4",
        category=SearchCategory.venue,
        keywords="باشگاه بدنسازی مکان ورزشی وزنه تمرین",
        coming_soon=True,
    ),
    _SearchDocument(
        id="coach_corrective_sample",
        title="مربی حرکت اصلاحی",
        subtitle="پروفایل نمونه مربی · برنامه‌دهی در فاز P6",
        category=SearchCategory.coach,
        keywords="مربی حرکت اصلاحی پاسچر برنامه تمرین مربی‌هاب",
        coming_soon=True,
    ),
    _SearchDocument(
        id="coach_strength_sample",
        title="مربی قدرت و عضله‌سازی",
        subtitle="پروفایل نمونه مربی · رزرو در فاز P6",
        category=SearchCategory.coach,
        keywords="مربی قدرت عضله سازی بدنسازی برنامه مربی‌هاب",
        coming_soon=True,
    ),
]

_REPLACEMENTS = str.maketrans(
    {
        "ي": "ی",
        "ى": "ی",
        "ئ": "ی",
        "ك": "ک",
        "ۀ": "ه",
        "ة": "ه",
        "ؤ": "و",
        "أ": "ا",
        "إ": "ا",
        "آ": "ا",
        "۰": "0",
        "۱": "1",
        "۲": "2",
        "۳": "3",
        "۴": "4",
        "۵": "5",
        "۶": "6",
        "۷": "7",
        "۸": "8",
        "۹": "9",
        "٠": "0",
        "١": "1",
        "٢": "2",
        "٣": "3",
        "٤": "4",
        "٥": "5",
        "٦": "6",
        "٧": "7",
        "٨": "8",
        "٩": "9",
    }
)


def _client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def _normalize(value: str) -> str:
    text = value.strip().lower().translate(_REPLACEMENTS)
    text = re.sub(r"[\u064B-\u065F\u0670]", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def _score(query: str, doc: _SearchDocument) -> int:
    title = _normalize(doc.title)
    subtitle = _normalize(doc.subtitle)
    text = _normalize(f"{doc.title} {doc.subtitle} {doc.keywords}")
    if title == query:
        return 120
    if title.startswith(query):
        return 100
    if title.find(query) >= 0:
        return 85
    if subtitle.find(query) >= 0:
        return 65
    if text.find(query) >= 0:
        return 45
    terms = [t for t in query.split(" ") if t]
    if len(terms) > 1 and all(t in text for t in terms):
        return 35
    return 0


@router.get("", response_model=SearchOut)
def search(
    request: Request,
    q: str = Query(min_length=2, max_length=40, description="عبارت جستجو"),
    category: SearchCategory | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=50),
) -> SearchOut:
    """جستجوی عمومی؛ هیچ دادهٔ شخصی نمی‌گیرد و query در audit ذخیره نمی‌شود."""
    limiter.check(f"search-ip:{_client_ip(request)}", 60, 60)
    query = _normalize(q)
    if len(query) < 2:
        raise HTTPException(status_code=422, detail="عبارت جستجو باید حداقل ۲ کاراکتر باشد")

    scored: list[tuple[int, _SearchDocument]] = []
    for doc in _DOCUMENTS:
        if category is not None and doc.category != category:
            continue
        score = _score(query, doc)
        if score > 0:
            scored.append((score, doc))

    scored.sort(key=lambda item: (-item[0], item[1].title))
    results = [
        SearchResultOut(
            id=doc.id,
            title=doc.title,
            subtitle=doc.subtitle,
            category=doc.category,
            source=doc.source,
            coming_soon=doc.coming_soon,
        )
        for _, doc in scored[:limit]
    ]
    return SearchOut(results=results, total=len(results), server_time=utcnow())
