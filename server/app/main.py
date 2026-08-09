"""بک‌اند «بدنه» — پلتفرم ورزشی.

فاز P0: اسکلت سرویس با endpoint سلامتی.
"""
from fastapi import FastAPI

APP_VERSION = "0.1.0"

app = FastAPI(
    title="Badane API",
    description="بک‌اند پلتفرم ورزشی «بدنه»",
    version=APP_VERSION,
)


@app.get("/health")
def health() -> dict:
    """سلامتی سرویس — برای پایش و تست اسکلت."""
    return {"status": "ok", "version": APP_VERSION}
