import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field

from app.schemas.common import ORMModel


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)
    nickname: str = Field(min_length=1, max_length=50)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class UserOut(ORMModel):
    id: uuid.UUID
    email: EmailStr
    nickname: str
    credit_balance: int
    is_premium: bool
    created_at: datetime


class AuthResponse(BaseModel):
    """POST /auth/register (201) / POST /auth/login (200)"""

    user: UserOut
    access_token: str
    refresh_token: str


class TokenPair(BaseModel):
    """POST /auth/refresh (200)"""

    access_token: str
    refresh_token: str
