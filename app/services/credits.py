import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import InsufficientCreditsError, NotFoundError
from app.models import CreditTransaction, User
from app.repositories.credits import CreditRepository
from app.repositories.users import UserRepository


class CreditService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.users = UserRepository(session)
        self.credits = CreditRepository(session)

    async def _apply(self, user_id: uuid.UUID, delta: int, reason: str) -> tuple[User, CreditTransaction]:
        """유저 행 잠금 후 잔액 갱신 + 트랜잭션 기록. 커밋은 호출자 몫."""
        user = await self.users.get_for_update(user_id)
        if user is None:
            raise NotFoundError("사용자를 찾을 수 없습니다.")
        if user.credit_balance + delta < 0:
            raise InsufficientCreditsError("크레딧이 부족합니다.")
        user.credit_balance += delta
        tx = await self.credits.add_transaction(user_id, delta, reason, user.credit_balance)
        return user, tx

    async def grant(self, user_id: uuid.UUID, amount: int, reason: str) -> User:
        user, _ = await self._apply(user_id, amount, reason)
        return user

    async def charge(self, user_id: uuid.UUID, amount: int, reason: str) -> User:
        user, _ = await self._apply(user_id, -amount, reason)
        return user

    async def refund(self, user_id: uuid.UUID, amount: int, reason: str) -> User:
        user, _ = await self._apply(user_id, amount, reason)
        return user

    async def balance(self, user_id: uuid.UUID) -> int:
        user = await self.users.get(user_id)
        if user is None:
            raise NotFoundError("사용자를 찾을 수 없습니다.")
        return user.credit_balance

    async def purchase(self, user_id: uuid.UUID, amount: int) -> tuple[int, str]:
        """결제 목(mock): 실제 PG 연동 전까지 즉시 승인. amount = 충전 크레딧 수."""
        user, tx = await self._apply(user_id, amount, "purchase")
        await self.session.commit()
        return user.credit_balance, str(tx.id)
