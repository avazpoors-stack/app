"""محدودکنندهٔ نرخ درخواست (درون‌حافظه، پنجرهٔ کشویی) — برای OTP و ورود."""
import time
from collections import defaultdict, deque

from fastapi import HTTPException, status


class RateLimiter:
    def __init__(self, clock=time.time) -> None:
        self.clock = clock
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def _prune(self, key: str, now: float, window_sec: float) -> None:
        q = self._hits[key]
        while q and now - q[0] > window_sec:
            q.popleft()

    def hit(self, key: str, limit: int, window_sec: float) -> bool:
        now = self.clock()
        self._prune(key, now, window_sec)
        q = self._hits[key]
        if len(q) >= limit:
            return False
        q.append(now)
        return True

    def check(self, key: str, limit: int, window_sec: float) -> None:
        if not self.hit(key, limit, window_sec):
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کن",
            )

    def reset(self) -> None:
        self._hits.clear()


limiter = RateLimiter()
