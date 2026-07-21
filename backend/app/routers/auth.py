from fastapi import APIRouter, status

from app.core.deps import CurrentUser, DbSession
from app.schemas.auth import (
    AuthResponse,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenPair,
    UserOut,
)
from app.services.auth import AuthService

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


@router.post("/auth/refresh", response_model=TokenPair)
async def refresh(body: RefreshRequest, session: DbSession):
    return await AuthService(session).refresh(body.refresh_token)


@router.get("/me", response_model=UserOut)
async def me(user: CurrentUser):
    return user
