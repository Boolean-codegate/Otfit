from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.core.config import get_settings
from app.core.errors import register_error_handlers
from app.routers import auth, consents, credits, events, generations, photos, products, results


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        description="AI 쇼퍼블 패션 리터칭 플랫폼 백엔드 (계약: api_contract.md)",
        version="0.1.0",
    )
    register_error_handlers(app)

    app.include_router(auth.router)
    app.include_router(consents.router)
    app.include_router(photos.router)
    app.include_router(products.router)
    app.include_router(generations.router)
    app.include_router(results.router)
    app.include_router(credits.router)
    app.include_router(events.router)

    # 로컬 스토리지 정적 서빙 (S3 전환 시 제거)
    media_dir = Path(settings.storage_dir)
    media_dir.mkdir(parents=True, exist_ok=True)
    app.mount("/media", StaticFiles(directory=media_dir), name="media")

    @app.get("/health", tags=["health"])
    async def health():
        return {"status": "ok", "provider_mode": settings.provider_mode}

    return app


app = create_app()
