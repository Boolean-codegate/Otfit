"""보안 하드닝 — 보안 응답 헤더 + 인증 엔드포인트 레이트리밋.

- SecurityHeadersMiddleware: MIME 스니핑·클릭재킹 방지, 리퍼러 최소화, API 응답 캐시 금지
- AuthRateLimitMiddleware: /auth/* POST를 IP+경로별 슬라이딩 윈도우로 제한 (크리덴셜 스터핑·무차별 대입 방어)
  단일 프로세스 인메모리 구현 — 수평 확장 시 Redis 기반으로 교체 (해커톤 MVP 범위)
"""
import time
from collections import defaultdict, deque

from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Cache-Control": "no-store",
}

RATE_LIMITED_PATHS = {"/auth/login", "/auth/register", "/auth/social", "/auth/refresh"}


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        for name, value in SECURITY_HEADERS.items():
            # 미디어(이미지)는 캐시 허용
            if name == "Cache-Control" and request.url.path.startswith("/media"):
                continue
            response.headers.setdefault(name, value)
        return response


class SlidingWindowLimiter:
    """IP+경로별 슬라이딩 윈도우 카운터."""

    def __init__(self, limit: int, window_seconds: int = 60):
        self.limit = limit
        self.window = window_seconds
        self._hits: dict[str, deque] = defaultdict(deque)

    def allow(self, key: str, now: float | None = None) -> bool:
        now = now if now is not None else time.monotonic()
        hits = self._hits[key]
        while hits and now - hits[0] > self.window:
            hits.popleft()
        if len(hits) >= self.limit:
            return False
        hits.append(now)
        return True


class AuthRateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, limit_per_minute: int = 20):
        super().__init__(app)
        self.limiter = SlidingWindowLimiter(limit_per_minute)

    async def dispatch(self, request: Request, call_next):
        if request.method == "POST" and request.url.path in RATE_LIMITED_PATHS:
            client_ip = request.client.host if request.client else "unknown"
            if not self.limiter.allow(f"{client_ip}:{request.url.path}"):
                return JSONResponse(
                    status_code=429,
                    content={
                        "error": {
                            "code": "RATE_LIMITED",
                            "message": "요청이 너무 잦습니다. 잠시 후 다시 시도해주세요.",
                            "detail": {},
                        }
                    },
                )
        return await call_next(request)
