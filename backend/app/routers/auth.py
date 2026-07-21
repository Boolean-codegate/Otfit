from fastapi import APIRouter, Response, status

from app.core.deps import CurrentUser, DbSession
from app.schemas.auth import (
    AuthResponse,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    SocialLoginRequest,
    TokenPair,
    UserOut,
)
from app.services.auth import AuthService
from app.services.privacy import PrivacyService

router = APIRouter(tags=["auth"])


@router.post("/auth/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(body: RegisterRequest, session: DbSession):
    user, tokens = await AuthService(session).register(
        email=body.email, password=body.password, nickname=body.nickname
    )
    return {"user": user, **tokens}


@router.post("/auth/login", response_model=AuthResponse)
async def login(body: LoginRequest, session: DbSession):
    user, tokens = await AuthService(session).login(email=body.email, password=body.password)
    return {"user": user, **tokens}


@router.post("/auth/social", response_model=AuthResponse)
async def social_login(body: SocialLoginRequest, session: DbSession, response: Response):
    """카카오/구글 SDK 토큰으로 로그인. 미가입 사용자는 자동 가입(201)."""
    user, tokens, is_new = await AuthService(session).social_login(
        provider=body.provider, token=body.token
    )
    if is_new:
        response.status_code = status.HTTP_201_CREATED
    return {"user": user, **tokens}


@router.post("/auth/refresh", response_model=TokenPair)
async def refresh(body: RefreshRequest, session: DbSession):
    return await AuthService(session).refresh(body.refresh_token)


@router.get("/me/export")
async def export_my_data(user: CurrentUser, session: DbSession):
    """GDPR 접근권·이동권 (Art.15/20) — 내 데이터 전체를 구조화된 JSON으로."""
    return await PrivacyService(session).export_user_data(user)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_account(user: CurrentUser, session: DbSession):
    """GDPR 삭제권 (Art.17) — 계정과 모든 개인 데이터(스토리지 파일 포함) 즉시 삭제."""
    await PrivacyService(session).delete_account(user.id)


@router.get("/me", response_model=UserOut)
async def me(user: CurrentUser):
    return user
