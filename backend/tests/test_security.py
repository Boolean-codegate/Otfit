"""보안 하드닝 테스트 — 보안 헤더, 레이트리밋 로직, 업로드 제한/EXIF 제거."""
import io

from PIL import Image

from app.core.hardening import SlidingWindowLimiter


def _image_with_exif(width=800, height=1000) -> bytes:
    image = Image.new("RGB", (width, height), (170, 150, 130))
    exif = Image.Exif()
    exif[0x0110] = "TestPhone 15 Pro"  # Model (기기 정보 — 제거 대상 메타데이터)
    exif[0x010F] = "TestMaker"  # Make
    buf = io.BytesIO()
    image.save(buf, format="JPEG", exif=exif)
    return buf.getvalue()


def test_sliding_window_limiter():
    limiter = SlidingWindowLimiter(limit=3, window_seconds=60)
    assert all(limiter.allow("k", now=t) for t in (0.0, 1.0, 2.0))
    assert limiter.allow("k", now=3.0) is False          # 한도 초과
    assert limiter.allow("other", now=3.0) is True       # 키 분리
    assert limiter.allow("k", now=61.5) is True          # 윈도우 경과 후 회복


async def test_security_headers_present(client):
    res = await client.get("/health")
    assert res.headers["x-content-type-options"] == "nosniff"
    assert res.headers["x-frame-options"] == "DENY"
    assert res.headers["cache-control"] == "no-store"


async def test_upload_strips_exif_and_limits_size(client):
    res = await client.post(
        "/auth/register",
        json={"email": "sec@test.dev", "password": "password1", "nickname": "보안"},
    )
    headers = {"Authorization": f"Bearer {res.json()['access_token']}"}

    # EXIF 있는 사진 업로드 → 저장본에서 EXIF 제거 확인
    res = await client.post(
        "/photos", headers=headers,
        files={"file": ("me.jpg", _image_with_exif(), "image/jpeg")},
        data={"consent_image_processing": "true"},
    )
    assert res.status_code == 201, res.text
    from urllib.parse import urlparse

    stored = await client.get(urlparse(res.json()["storage_url"]).path)
    with Image.open(io.BytesIO(stored.content)) as im:
        assert dict(im.getexif()) == {}, "EXIF가 제거되어야 한다"

    # 크기 제한 초과 → 413
    big = b"\xff\xd8" + b"0" * (11 * 1024 * 1024)
    res = await client.post(
        "/photos", headers=headers,
        files={"file": ("big.jpg", big, "image/jpeg")},
        data={"consent_image_processing": "true"},
    )
    assert res.status_code == 413
