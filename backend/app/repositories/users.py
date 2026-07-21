import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User


class UserRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get(self, user_id: uuid.UUID) -> User | None:
        return await self.session.get(User, user_id)

    async def get_for_update(self, user_id: uuid.UUID) -> User | None:
        result = await self.session.execute(select(User).where(User.id == user_id).with_for_update())
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        result = await self.session.execute(select(User).where(User.email == email))
        return result.scalar_one_or_none()

    async def get_by_provider(self, provider: str, provider_id: str) -> User | None:
        result = await self.session.execute(
            select(User).where(User.provider == provider, User.provider_id == provider_id)
        )
        return result.scalar_one_or_none()

    async def create(
        self,
        *,
        email: str,
        hashed_password: str | None,
        nickname: str,
        provider: str = "email",
        provider_id: str | None = None,
    ) -> User:
        user = User(
            email=email,
            hashed_password=hashed_password,
            nickname=nickname,
            provider=provider,
            provider_id=provider_id,
        )
        self.session.add(user)
        await self.session.flush()
        return user
