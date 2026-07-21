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


async def test_safe_image_upload_passes(client):
    # 기본(mock) 모더레이션은 통과 — 정상 업로드 경로 유지
    headers = await _signup(client, "mod-pass@test.dev")
    res = await client.post(
        "/photos", headers=headers,
        files={"file": ("ok.jpg", _image(), "image/jpeg")},
        data={"consent_image_processing": "true"},
    )
    assert res.status_code == 201, res.text
