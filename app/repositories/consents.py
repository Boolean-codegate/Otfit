import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Consent


class ConsentRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def list_for_user(self, user_id: uuid.UUID) -> list[Consent]:
        result = await self.session.execute(select(Consent).where(Consent.user_id == user_id))
        return list(result.scalars())

    async def get(self, user_id: uuid.UUID, consent_type: str) -> Consent | None:
        result = await self.session.execute(
            select(Consent).where(Consent.user_id == user_id, Consent.type == consent_type)
        )
        return result.scalar_one_or_none()

    async def upsert(self, user_id: uuid.UUID, consent_type: str, granted: bool) -> Consent:
        consent = await self.get(user_id, consent_type)
        if consent is None:
            consent = Consent(user_id=user_id, type=consent_type)
            self.session.add(consent)
        consent.granted = granted
        consent.granted_at = datetime.now(timezone.utc) if granted else None
        await self.session.flush()
        return consent

    async def has_granted(self, user_id: uuid.UUID, consent_type: str) -> bool:
        consent = await self.get(user_id, consent_type)
        return bool(consent and consent.granted)
