"""GDPR 권리 행사 테스트 — 데이터 내보내기(Art.15/20) + 계정 삭제(Art.17)."""
import io

from PIL import Image


def _image(width=800, height=1000) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (width, height), (150, 140, 120)).save(buf, format="JPEG")
    return buf.getvalue()


async def test_export_and_delete_account(client):
    res = await client.post(
        "/auth/register",
        json={"email": "gdpr@test.dev", "password": "password1", "nickname": "지디피알"},
    )
    assert res.status_code == 201
    headers = {"Authorization": f"Bearer {res.json()['access_token']}"}

    # 데이터 생성: 사진 업로드 + 게시물 + 투표
    res = await client.post(
        "/photos", headers=headers,
        files={"file": ("me.jpg", _image(), "image/jpeg")},
        data={"consent_image_processing": "true"},
    )
    assert res.status_code == 201
    res = await client.post(
        "/posts", headers=headers,
        json={"caption": "삭제 테스트", "after_url": "https://cdn.example/x.png"},
    )
    assert res.status_code == 201
    post_id = res.json()["id"]
    await client.post(f"/posts/{post_id}/vote", headers=headers, json={"choice": "buy"})

    # ── 내보내기 (Art.15/20): 모든 데이터 카테고리가 구조화되어 반환 ──
    res = await client.get("/me/export", headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["profile"]["email"] == "gdpr@test.dev"
    assert len(data["consents"]) >= 1          # 업로드 시 기록된 동의
    assert len(data["photos"]) == 1
    assert len(data["posts"]) == 1
    assert len(data["votes"]) == 1
    assert any(t["reason"] == "signup_bonus" for t in data["credit_transactions"])

    # ── 계정 삭제 (Art.17) ──
    res = await client.delete("/me", headers=headers)
    assert res.status_code == 204

    # 토큰은 더 이상 유효한 사용자에 연결되지 않음
    res = await client.get("/me", headers=headers)
    assert res.status_code == 401

    # 재로그인 불가 (계정 소멸)
    res = await client.post("/auth/login", json={"email": "gdpr@test.dev", "password": "password1"})
    assert res.status_code == 401

    # 게시물도 함께 소멸 (다른 사용자 피드에서 안 보임)
    res = await client.post(
        "/auth/register",
        json={"email": "viewer@test.dev", "password": "password1", "nickname": "뷰어"},
    )
    viewer = {"Authorization": f"Bearer {res.json()['access_token']}"}
    res = await client.get("/feed?sort=new&limit=50", headers=viewer)
    assert all(p["id"] != post_id for p in res.json()["items"])
