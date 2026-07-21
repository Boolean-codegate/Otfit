"""보관기간(delete_after) 만료 사진 자동 삭제 — Celery beat 주기 태스크."""
import asyncio
import logging
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import get_settings
from app.repositories.photos import PhotoRepository
from app.storage.base import get_storage
from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.workers.tasks.cleanup.cleanup_expired_photos")
def cleanup_expired_photos() -> int:
    return asyncio.run(_cleanup())


async def _cleanup() -> int:
    engine = create_async_engine(get_settings().database_url, pool_pre_ping=True)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    storage = get_storage()
    deleted = 0
    try:
        async with factory() as session:
            photos = PhotoRepository(session)
            for photo in await photos.list_expired():
                storage.delete(photo.storage_key)
                photo.deleted_at = datetime.now(timezone.utc)
                photo.status = "deleted"
                deleted += 1
            await session.commit()
    finally:
        await engine.dispose()
    if deleted:
        logger.info("expired photos deleted: %d", deleted)
    return deleted
