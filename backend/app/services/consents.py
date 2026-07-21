import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Consent
from app.repositories.consents import ConsentRepository


class ConsentService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.consents = ConsentRepository(session)

    async def upsert(self, user_id: uuid.UUID, consent_type: str, granted: bool) -> Consent:
        consent = await self.consents.upsert(user_id, consent_type, granted)
        await self.session.commit()
        return consent

    async def list_for_user(self, user_id: uuid.UUID) -> list[Consent]:
        return await self.consents.list_for_user(user_id)

    async def require_image_processing(self, user_id: uuid.UUID) -> bool:
        return await self.consents.has_granted(user_id, "image_processing")
