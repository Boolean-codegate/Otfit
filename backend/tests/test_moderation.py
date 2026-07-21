"""이미지 모더레이션 테스트 — 유해 이미지(나체·폭력 등) 업로드 차단."""
import io

from PIL import Image

from app.providers.moderation import ModerationVerdict


def _image() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (800, 1000), (120, 110, 100)).save(buf, format="JPEG")
    return buf.getvalue()


class _FlaggingProvider:
    async def check(self, image_bytes: bytes) -> ModerationVerdict:
        return ModerationVerdict(flagged=True, categories=["sexual"])


async def _signup(client, email):
    res = await client.post(
        "/auth/register", json={"email": email, "password": "password1", "nickname": "모더"}
    )
    return {"Authorization": f"Bearer {res.json()['access_token']}"}


async def test_unsafe_image_upload_blocked(client, monkeypatch):
    monkeypatch.setattr("app.services.photos.get_moderation_provider", lambda: _FlaggingProvider())
    headers = await _signup(client, "mod-block@test.dev")

    res = await client.post(
        "/photos", headers=headers,
        files={"file": ("nsfw.jpg", _image(), "image/jpeg")},
        data={"consent_image_processing": "true"},
    )
    assert res.status_code == 400, res.text
    body = res.json()["error"]
    assert body["code"] == "INVALID_PHOTO"
    assert body["detail"]["reject_reason"] == "UNSAFE_CONTENT"
    assert "sexual" in body["detail"]["categories"]


async def test_repeated_unsafe_uploads_ban_account(client, monkeypatch):
    """유해 업로드 3회 누적 → 계정 제한(밴), 이후 모든 인증 요청 403."""
    monkeypatch.setattr("app.services.photos.get_moderation_provider", lambda: _FlaggingProvider())
    headers = await _signup(client, "mod-ban@test.dev")

    for attempt in range(3):
        res = await client.post(
            "/photos", headers=headers,
            files={"file": (f"bad{attempt}.jpg", _image(), "image/jpeg")},
            data={"consent_image_processing": "true"},
        )
        assert res.status_code == 400, res.text
    assert res.json()["error"]["detail"]["banned"] is True

    res = await client.get("/me", headers=headers)
    assert res.status_code == 403, res.text


class _DangerProvider:
    async def check(self, image_bytes: bytes) -> ModerationVerdict:
        return ModerationVerdict(flagged=True, categories=["knife"], severe=False)


async def test_dangerous_item_blocked_without_strike(client, monkeypatch):
    """위험 물품(칼 등)은 차단·경고만 — 스트라이크/밴 없음."""
    monkeypatch.setattr("app.services.photos.get_moderation_provider", lambda: _DangerProvider())
    headers = await _signup(client, "mod-danger@test.dev")

    res = await client.post(
        "/photos", headers=headers,
        files={"file": ("knife.jpg", _image(), "image/jpeg")},
        data={"consent_image_processing": "true"},
    )
    assert res.status_code == 400, res.text
    body = res.json()["error"]
    assert body["detail"]["reject_reason"] == "DANGEROUS_CONTENT"
    assert body["detail"]["banned"] is False

    # 스트라이크가 아니므로 계정은 정상
    res = await client.get("/me", headers=headers)
    assert res.status_code == 200, res.text


class _DisturbingProvider:
    async def check(self, image_bytes: bytes) -> ModerationVerdict:
        return ModerationVerdict(flagged=True, categories=["disturbing"], severe=False)


async def test_disturbing_image_blocked_without_strike(client, monkeypatch):
    """공포·혐오 이미지(귀신·호러 분장 등)는 DISTURBING_CONTENT로 차단 — 스트라이크 없음."""
    monkeypatch.setattr("app.services.photos.get_moderation_provider", lambda: _DisturbingProvider())
    headers = await _signup(client, "mod-ghost@test.dev")

    res = await client.post(
        "/photos", headers=headers,
        files={"file": ("ghost.jpg", _image(), "image/jpeg")},
        data={"consent_image_processing": "true"},
    )
    assert res.status_code == 400, res.text
    body = res.json()["error"]
    assert body["detail"]["reject_reason"] == "DISTURBING_CONTENT"
    assert body["detail"]["banned"] is False
    assert "공포감이나 혐오감" in body["message"]

    res = await client.get("/me", headers=headers)
    assert res.status_code == 200, res.text


async def test_safe_image_upload_passes(client):
    # 기본(mock) 모더레이션은 통과 — 정상 업로드 경로 유지
    headers = await _signup(client, "mod-pass@test.dev")
    res = await client.post(
        "/photos", headers=headers,
        files={"file": ("ok.jpg", _image(), "image/jpeg")},
        data={"consent_image_processing": "true"},
    )
    assert res.status_code == 201, res.text
