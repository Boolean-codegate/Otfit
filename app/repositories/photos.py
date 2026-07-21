import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Photo, PhotoAnalysis


class PhotoRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get(self, photo_id: uuid.UUID) -> Photo | None:
        return await self.session.get(Photo, photo_id)

    async def create(self, **kwargs) -> Photo:
        photo = Photo(**kwargs)
        self.session.add(photo)
        await self.session.flush()
        return photo

    async def get_analysis(self, photo_id: uuid.UUID) -> PhotoAnalysis | None:
        result = await self.session.execute(
            select(PhotoAnalysis).where(PhotoAnalysis.photo_id == photo_id)
        )
        return result.scalar_one_or_none()

    async def upsert_analysis(self, photo_id: uuid.UUID, **fields) -> PhotoAnalysis:
        analysis = await self.get_analysis(photo_id)
        if analysis is None:
            analysis = PhotoAnalysis(photo_id=photo_id, **fields)
            self.session.add(analysis)
        else:
            for key, value in fields.items():
                setattr(analysis, key, value)
        await self.session.flush()
        return analysis

    async def list_expired(self, now: datetime | None = None) -> list[Photo]:
        now = now or datetime.now(timezone.utc)
        result = await self.session.execute(
            select(Photo).where(Photo.delete_after <= now, Photo.deleted_at.is_(None))
        )
        return list(result.scalars())
