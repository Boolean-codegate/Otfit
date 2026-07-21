import uuid

import jwt
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import ConflictError, UnauthorizedError
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models import User
from app.repositories.users import UserRepository
from app.services.credits import CreditService
from app.services.social import verify_social_token


class AuthService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.users = UserRepository(session)

    def _token_pair(self, user: User) -> dict:
        return {
            "access_token": create_access_token(str(user.id)),
            "refresh_token": create_refresh_token(str(user.id)),
        }

    async def register(self, *, email: str, password: str, nickname: str) -> tuple[User, dict]:
        if await self.users.get_by_email(email):
            raise ConflictError("이미 가입된 이메일입니다.")
        user = await self.users.create(
            email=email, hashed_password=hash_password(password), nickname=nickname
        )
        bonus = get_settings().signup_bonus_credits
        if bonus > 0:
            await CreditService(self.session).grant(user.id, bonus, "signup_bonus")
        await self.session.commit()
        return user, self._token_pair(user)

    async def login(self, *, email: str, password: str) -> tuple[User, dict]:
        user = await self.users.get_by_email(email)
        if user is not None and user.hashed_password is None:
            raise UnauthorizedError(f"{user.provider} 소셜 로그인으로 가입된 계정입니다.")
        if user is None or not verify_password(password, user.hashed_password):
            raise UnauthorizedError("이메일 또는 비밀번호가 올바르지 않습니다.")
        return user, self._token_pair(user)

    async def social_login(self, *, provider: str, token: str) -> tuple[User, dict, bool]:
        """소셜 토큰 검증 후 로그인. 미가입이면 가입 처리. (user, tokens, is_new) 반환."""
        profile = await verify_social_token(provider, token)

        user = await self.users.get_by_provider(profile.provider, profile.provider_id)
        if user is not None:
            return user, self._token_pair(user), False

        # 같은 이메일의 기존 계정이 있으면 소셜 계정을 연결한다
        if profile.email:
            existing = await self.users.get_by_email(profile.email)
            if existing is not None:
                if existing.provider_id is None:
                    existing.provider = profile.provider
                    existing.provider_id = profile.provider_id
                    await self.session.commit()
                    return existing, self._token_pair(existing), False
                raise ConflictError("이미 다른 소셜 계정과 연결된 이메일입니다.")

        # 신규 가입 (카카오는 이메일 미제공 동의가 가능 → 플레이스홀더 이메일)
        email = profile.email or f"{profile.provider}_{profile.provider_id}@social.otfit.app"
        nickname = (profile.nickname or f"{profile.provider} 유저")[:50]
        user = await self.users.create(
            email=email,
            hashed_password=None,
            nickname=nickname,
            provider=profile.provider,
            provider_id=profile.provider_id,
        )
        bonus = get_settings().signup_bonus_credits
        if bonus > 0:
            await CreditService(self.session).grant(user.id, bonus, "signup_bonus")
        await self.session.commit()
        return user, self._token_pair(user), True

    async def refresh(self, refresh_token: str) -> dict:
        try:
            user_id = decode_token(refresh_token, "refresh")
        except jwt.PyJWTError as exc:
            raise UnauthorizedError("리프레시 토큰이 유효하지 않습니다.") from exc
        user = await self.users.get(uuid.UUID(user_id))
        if user is None:
            raise UnauthorizedError("사용자를 찾을 수 없습니다.")
        return self._token_pair(user)
