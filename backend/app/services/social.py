"""소셜 로그인 토큰 검증.

클라이언트(Flutter)가 카카오/구글 SDK로 받은 토큰을 서버가 각 플랫폼 API로 검증하고
표준화된 프로필(SocialProfile)로 변환한다. 서버는 소셜 토큰을 저장하지 않는다.

- kakao: access_token → GET kapi.kakao.com/v2/user/me
- google: id_token → GET oauth2.googleapis.com/tokeninfo (GOOGLE_CLIENT_ID 설정 시 aud 검증)
"""
from dataclasses import dataclass

import httpx

from app.core.config import get_settings
from app.core.errors import UnauthorizedError

KAKAO_USERINFO_URL = "https://kapi.kakao.com/v2/user/me"
GOOGLE_TOKENINFO_URL = "https://oauth2.googleapis.com/tokeninfo"

SUPPORTED_PROVIDERS = ("kakao", "google")


@dataclass
class SocialProfile:
    provider: str
    provider_id: str
    email: str | None
    nickname: str | None


async def _verify_kakao(token: str) -> SocialProfile:
    async with httpx.AsyncClient(timeout=10) as client:
        res = await client.get(KAKAO_USERINFO_URL, headers={"Authorization": f"Bearer {token}"})
    if res.status_code != 200:
        raise UnauthorizedError("카카오 토큰 검증에 실패했습니다.")
    data = res.json()
    account = data.get("kakao_account") or {}
    profile = account.get("profile") or {}
    return SocialProfile(
        provider="kakao",
        provider_id=str(data["id"]),
        email=account.get("email"),
        nickname=profile.get("nickname"),
    )


async def _verify_google(token: str) -> SocialProfile:
    async with httpx.AsyncClient(timeout=10) as client:
        res = await client.get(GOOGLE_TOKENINFO_URL, params={"id_token": token})
    if res.status_code != 200:
        raise UnauthorizedError("구글 토큰 검증에 실패했습니다.")
    data = res.json()
    expected_aud = get_settings().google_client_id
    if expected_aud and data.get("aud") != expected_aud:
        raise UnauthorizedError("구글 토큰의 대상(aud)이 올바르지 않습니다.")
    return SocialProfile(
        provider="google",
        provider_id=data["sub"],
        email=data.get("email"),
        nickname=data.get("name"),
    )


async def verify_social_token(provider: str, token: str) -> SocialProfile:
    if provider == "kakao":
        return await _verify_kakao(token)
    if provider == "google":
        return await _verify_google(token)
    raise UnauthorizedError(f"지원하지 않는 provider입니다: {provider}")
