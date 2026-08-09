# بک‌اند «بدنه» — FastAPI

بک‌اند پلتفرم ورزشی «بدنه». فاز P0: فقط اسکلت + endpoint سلامتی.

## اجرای محلی

```bash
cd server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

سپس: http://127.0.0.1:8000/health

## تست

```bash
pytest -q
```
