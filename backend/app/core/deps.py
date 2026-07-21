import uuid
from typing import Annotated

import jwt
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import UnauthorizedError
from app.core.security import decode_token
from app.db.session import get_db
from app.models import User
from app.repositories.users import UserRepository

bearer_scheme = HTTPBearer(auto_error=False)

DbSession = Annotated[AsyncSession, Depends(get_db)]


async def get_current_user(
    session: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> User:
    if credentials is None:
        raise UnauthorizedError("인증 토큰이 필요합니다.")
    try:
        user_id = decode_token(credentials.credentials, "access")
    except jwt.PyJWTError as exc:
        raise UnauthorizedError("토큰이 유효하지 않거나 만료되었습니다.") from exc
    user = await UserRepository(session).get(uuid.UUID(user_id))
    if user is None:
        raise UnauthorizedError("사용자를 찾을 수 없습니다.")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
