from app.core.config import get_settings
"""소셜 로그인 통합 테스트 (계약 §1 POST /auth/social).

외부 API(카카오/구글) 호출부만 monkeypatch로 대체하고,
가입/로그인/계정연결/에러 흐름은 실제 서비스 경로를 그대로 태운다.
"""
import pytest

from app.core.errors import UnauthorizedError
from app.services.social import SocialProfile

# monkeypatch 대상: AuthService가 import한 이름
TARGET = "app.services.auth.verify_social_token"


def _fake_verify(profile: SocialProfile):
    async def verify(provider: str, token: str) -> SocialProfile:
        if token == "bad-token":
            raise UnauthorizedError(f"{provider} 토큰 검증에 실패했습니다.")
        return profile

    return verify


KAKAO_USER = SocialProfile(provider="kakao", provider_id="12345", email="social@test.dev", nickname="카카오철민")
KAKAO_NO_EMAIL = SocialProfile(provider="kakao", provider_id="99999", email=None, nickname=None)
GOOGLE_USER = SocialProfile(provider="google", provider_id="g-abc", email="social@test.dev", nickname="구글철민")


async def test_social_signup_and_relogin(client, monkeypatch):
    monkeypatch.setattr(TARGET, _fake_verify(KAKAO_USER))

    # 첫 로그인 = 자동 가입(201) + 보너스 크레딧
    res = await client.post("/auth/social", json={"provider": "kakao", "token": "good"})
    assert res.status_code == 201, res.text
    body = res.json()
    assert body["user"]["email"] == "social@test.dev"
    assert body["user"]["nickname"] == "카카오철민"
    assert body["user"]["credit_balance"] == get_settings().signup_bonus_credits
    assert body["access_token"] and body["refresh_token"]
    user_id = body["user"]["id"]

    # 발급된 토큰으로 인증 API 사용 가능
    res = await client.get("/me", headers={"Authorization": f"Bearer {body['access_token']}"})
    assert res.status_code == 200

    # 두 번째 로그인 = 기존 사용자(200), 중복 가입/중복 보너스 없음
    res = await client.post("/auth/social", json={"provider": "kakao", "token": "good"})
    assert res.status_code == 200, res.text
    body2 = res.json()
    assert body2["user"]["id"] == user_id
    assert body2["user"]["credit_balance"] == get_settings().signup_bonus_credits


async def test_social_login_no_email_uses_placeholder(client, monkeypatch):
    monkeypatch.setattr(TARGET, _fake_verify(KAKAO_NO_EMAIL))
    res = await client.post("/auth/social", json={"provider": "kakao", "token": "good"})
    assert res.status_code == 201, res.text
    user = res.json()["user"]
    assert user["email"] == "kakao_99999@social.otfit.app"
    assert user["nickname"] == "kakao 유저"


async def test_social_links_existing_email_account(client, monkeypatch):
    # 이메일로 먼저 가입
    res = await client.post(
        "/auth/register",
        json={"email": "link@test.dev", "password": "password1", "nickname": "링크"},
    )
    assert res.status_code == 201
    email_user_id = res.json()["user"]["id"]

    # 같은 이메일의 구글 로그인 → 새 계정이 아니라 기존 계정에 연결(200)
    profile = SocialProfile(provider="google", provider_id="g-link", email="link@test.dev", nickname="구글링크")
    monkeypatch.setattr(TARGET, _fake_verify(profile))
    res = await client.post("/auth/social", json={"provider": "google", "token": "good"})
    assert res.status_code == 200, res.text
    assert res.json()["user"]["id"] == email_user_id


async def test_social_invalid_token_returns_401(client, monkeypatch):
    monkeypatch.setattr(TARGET, _fake_verify(GOOGLE_USER))
    res = await client.post("/auth/social", json={"provider": "google", "token": "bad-token"})
    assert res.status_code == 401
    assert res.json()["error"]["code"] == "UNAUTHORIZED"


async def test_social_unsupported_provider_rejected_by_schema(client):
    res = await client.post("/auth/social", json={"provider": "naver", "token": "x"})
    assert res.status_code == 422


async def test_password_login_blocked_for_social_account(client, monkeypatch):
    monkeypatch.setattr(TARGET, _fake_verify(SocialProfile(
        provider="kakao", provider_id="55555", email="pwblock@test.dev", nickname="소셜만"
    )))
    res = await client.post("/auth/social", json={"provider": "kakao", "token": "good"})
    assert res.status_code == 201

    # 소셜 전용 계정은 비밀번호 로그인 불가 (500이 아니라 401이어야 함)
    res = await client.post("/auth/login", json={"email": "pwblock@test.dev", "password": "whatever1"})
    assert res.status_code == 401
