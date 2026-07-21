import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import CreditTransaction


class CreditRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def add_transaction(
        self, user_id: uuid.UUID, delta: int, reason: str, balance_after: int
    ) -> CreditTransaction:
        tx = CreditTransaction(
            user_id=user_id, delta=delta, reason=reason, balance_after=balance_after
        )
        self.session.add(tx)
        await self.session.flush()
        return tx

    async def list_for_user(self, user_id: uuid.UUID, limit: int = 50) -> list[CreditTransaction]:
        result = await self.session.execute(
            select(CreditTransaction)
            .where(CreditTransaction.user_id == user_id)
            .order_by(CreditTransaction.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars())
