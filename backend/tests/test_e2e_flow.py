"""통합 테스트: 회원가입 → 업로드 → 분석 → 추천 → 생성 → 결과 → 쇼퍼블 → 크레딧.

Celery eager 모드라 생성 파이프라인이 요청 안에서 즉시 완료된다.
응답 shape은 api_contract.md(§10)를 그대로 검증한다.
"""
import io

from PIL import Image


def _test_image(width: int = 800, height: int = 1000) -> bytes:
    image = Image.new("RGB", (width, height), (180, 160, 140))
    buf = io.BytesIO()
    image.save(buf, format="JPEG")
    return buf.getvalue()


async def test_full_flow(client):
    # ── 회원가입 (보너스 10크레딧) ───────────────────────────────
    res = await client.post(
        "/auth/register",
        json={"email": "flow@test.dev", "password": "password1", "nickname": "플로우"},
    )
    assert res.status_code == 201, res.text
    body = res.json()
    assert body["user"]["email"] == "flow@test.dev"
    headers = {"Authorization": f"Bearer {body['access_token']}"}

    # ── 사진 업로드 (multipart + 동의 필드) ──────────────────────
    res = await client.post(
        "/photos",
        headers=headers,
        files={"file": ("me.jpg", _test_image(), "image/jpeg")},
        data={"consent_image_processing": "true"},
    )
    assert res.status_code == 201, res.text
    photo = res.json()
    assert photo["status"] == "uploaded"
    photo_id = photo["id"]

    # ── 분석 ─────────────────────────────────────────────────────
    res = await client.post(f"/photos/{photo_id}/analyze", headers=headers)
    assert res.status_code == 200, res.text
    analysis = res.json()
    assert analysis["is_valid"] is True
    assert analysis["reject_reason"] is None
    assert analysis["garment_regions"][0]["type"] == "top"
    assert len(analysis["style_suggestions"]) >= 2
    assert set(analysis["style_suggestions"][0]) == {"id", "label"}

    # ── 추천 (MODE B 스타일 그룹) ────────────────────────────────
    res = await client.post(
        f"/photos/{photo_id}/recommendations", headers=headers, json={"mode": "B_stylist"}
    )
    assert res.status_code == 200, res.text
    rec = res.json()
    assert rec["groups"] and rec["groups"][0]["products"]

    # ── 생성 job (202) → eager라 즉시 완료 ───────────────────────
    res = await client.post(
        "/generations",
        headers=headers,
        json={"photo_id": photo_id, "mode": "B_stylist", "options": {"styles": ["casual", "minimal"]}},
    )
    assert res.status_code == 202, res.text
    job = res.json()
    assert job["status"] == "queued"
    assert job["credits_charged"] == 1
    job_id = job["job_id"]

    # ── 폴링 ─────────────────────────────────────────────────────
    res = await client.get(f"/generations/{job_id}", headers=headers)
    assert res.status_code == 200
    poll = res.json()
    assert poll["status"] == "done", poll
    assert poll["progress"] == 1.0
    assert poll["error"] is None

    # ── 결과 (품질 통과만, disclaimer 포함) ──────────────────────
    res = await client.get(f"/generations/{job_id}/results", headers=headers)
    assert res.status_code == 200
    results = res.json()["results"]
    assert len(results) >= 1
    first = results[0]
    assert first["identity_preserved"] is True
    assert first["quality_score"] >= 0.6
    assert "스타일링 시각화" in first["disclaimer"]
    assert first["result_url"].startswith("http")

    # ── 결과 선택 ────────────────────────────────────────────────
    res = await client.post(
        f"/generations/{job_id}/results/{first['id']}/select", headers=headers
    )
    assert res.status_code == 200 and res.json() == {"ok": True}

    # ── 쇼퍼블 ───────────────────────────────────────────────────
    res = await client.get(f"/results/{first['id']}/shop", headers=headers)
    assert res.status_code == 200
    shop = res.json()
    assert shop["applied_product"]["id"] == first["product_id"]
    assert isinstance(shop["applied_product"]["price"], int)
    assert len(shop["similar_products"]) >= 1

    # ── 이벤트 ───────────────────────────────────────────────────
    res = await client.post(
        "/events",
        headers=headers,
        json={"type": "product_click", "session_id": "s_1", "payload": {"result_id": first["id"]}},
    )
    assert res.status_code == 202 and res.json() == {"ok": True}

    # ── 내보내기 (무료 유저 → 워터마크) ──────────────────────────
    res = await client.post(
        f"/results/{first['id']}/export",
        headers=headers,
        json={"ratio": "4:5", "hi_res": True, "remove_watermark": True},
    )
    assert res.status_code == 200
    export = res.json()
    assert export["watermark"] is True

    # ── 크레딧: 가입 보너스 - 생성 1 ────────────────────────────
    from app.core.config import get_settings

    bonus = get_settings().signup_bonus_credits
    res = await client.get("/credits", headers=headers)
    assert res.status_code == 200
    assert res.json()["balance"] == bonus - 1

    # ── 크레딧 충전 (결제 목) ────────────────────────────────────
    res = await client.post("/credits/purchase", headers=headers, json={"amount": 5})
    assert res.status_code == 200
    assert res.json()["balance"] == bonus - 1 + 5
