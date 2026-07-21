from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import get_settings
from app.core.errors import register_error_handlers
from app.core.hardening import AuthRateLimitMiddleware, SecurityHeadersMiddleware
from app.routers import auth, consents, credits, events, generations, mypage, photos, posts, products, results


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        description="AI 쇼퍼블 패션 리터칭 플랫폼 백엔드 (계약: api_contract.md)",
        version="0.1.0",
    )
    register_error_handlers(app)

    if settings.secret_key == "change-me-in-production":
        import logging
        logging.getLogger("otfit").warning(
            "SECRET_KEY가 기본값입니다 — 배포 환경에서는 반드시 무작위 값으로 교체하세요."
        )

    # 보안 헤더 + 인증 레이트리밋 (CORS보다 바깥에서 적용)
    app.add_middleware(SecurityHeadersMiddleware)
    app.add_middleware(AuthRateLimitMiddleware, limit_per_minute=settings.auth_rate_limit_per_minute)

    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=settings.cors_allow_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(auth.router)
    app.include_router(consents.router)
    app.include_router(photos.router)
    app.include_router(products.router)
    app.include_router(posts.router)
    app.include_router(mypage.router)
    app.include_router(generations.router)
    app.include_router(results.router)
    app.include_router(credits.router)
    app.include_router(events.router)

    # 로컬 스토리지일 때만 /media 정적 서빙 (s3 모드는 R2가 직접 서빙 — 디스크 불필요)
    if settings.storage_backend == "local":
        media_dir = Path(settings.storage_dir)
        media_dir.mkdir(parents=True, exist_ok=True)
        app.mount("/media", StaticFiles(directory=media_dir), name="media")

    @app.get("/health", tags=["health"])
    async def health():
        return {"status": "ok", "provider_mode": settings.provider_mode}

    return app


app = create_app()
