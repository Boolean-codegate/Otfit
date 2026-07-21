"""SNS 피드 통합 테스트 (계약 §10).

게시 → 피드 → 투표(보상/변경/멱등) → 플랫폼 목록.
"""


async def _signup(client, email: str, nickname: str) -> dict:
    res = await client.post(
        "/auth/register",
        json={"email": email, "password": "password1", "nickname": nickname},
    )
    assert res.status_code == 201, res.text
    body = res.json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]


async def test_sns_full_flow(client):
    author_h, author = await _signup(client, "author@sns.dev", "작성자")
    voter_h, voter = await _signup(client, "voter@sns.dev", "투표자")

    # ── 게시 (URL 직접 지정 — 데모/외부 이미지) ──
    res = await client.post(
        "/posts",
        headers=author_h,
        json={"caption": "이거 어때요?", "after_url": "https://cdn.example/after.png"},
    )
    assert res.status_code == 201, res.text
    post = res.json()
    assert post["author"]["nickname"] == "작성자"
    assert post["buy_votes"] == 0 and post["my_vote"] is None
    post_id = post["id"]

    # ── 피드에 노출 ──
    res = await client.get("/feed?sort=new", headers=voter_h)
    assert res.status_code == 200, res.text
    feed = res.json()
    assert any(p["id"] == post_id for p in feed["items"])

    # ── 타인 게시물 신규 투표 → 집계 + 보상 1크레딧 ──
    res = await client.post(f"/posts/{post_id}/vote", headers=voter_h, json={"choice": "buy"})
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["post"]["buy_votes"] == 1
    assert body["post"]["my_vote"] == "buy"
    assert body["reward_credits"] == 1

    res = await client.get("/me", headers=voter_h)
    assert res.json()["credit_balance"] == voter["credit_balance"] + 1

    # ── 같은 선택 재투표 = 멱등 (보상 없음) ──
    res = await client.post(f"/posts/{post_id}/vote", headers=voter_h, json={"choice": "buy"})
    assert res.json()["post"]["buy_votes"] == 1
    assert res.json()["reward_credits"] == 0

    # ── 선택 변경 → 집계 이동 ──
    res = await client.post(f"/posts/{post_id}/vote", headers=voter_h, json={"choice": "skip"})
    body = res.json()
    assert body["post"]["buy_votes"] == 0 and body["post"]["skip_votes"] == 1
    assert body["post"]["my_vote"] == "skip"

    # ── 본인 게시물 투표는 보상 없음 ──
    res = await client.post(f"/posts/{post_id}/vote", headers=author_h, json={"choice": "buy"})
    assert res.json()["reward_credits"] == 0

    # ── 피드 hot 정렬 + my_vote 포함 ──
    res = await client.get("/feed?sort=hot", headers=voter_h)
    mine = next(p for p in res.json()["items"] if p["id"] == post_id)
    assert mine["my_vote"] == "skip"

    # ── 플랫폼 목록 (시드 협력사) ──
    res = await client.get("/platforms", headers=voter_h)
    assert res.status_code == 200
    assert isinstance(res.json(), list)


async def test_post_requires_after_url_or_result(client):
    h, _ = await _signup(client, "empty@sns.dev", "빈손")
    res = await client.post("/posts", headers=h, json={"caption": "이미지 없음"})
    assert res.status_code == 422


async def test_vote_on_missing_post_404(client):
    h, _ = await _signup(client, "ghost@sns.dev", "유령")
    res = await client.post(
        "/posts/00000000-0000-0000-0000-000000000000/vote", headers=h, json={"choice": "buy"}
    )
    assert res.status_code == 404
