"""개인정보 권리 행사 — GDPR 대응.

- 접근권/이동권 (Art. 15, 20): 내 데이터 전체 사본을 구조화된 JSON으로 내보내기
- 삭제권 (Art. 17): 계정과 모든 개인 데이터 즉시 삭제 (스토리지 파일 포함)
  DB 행은 users FK CASCADE로 일괄 삭제되고, 파일(원본 사진·생성 결과)은 명시적으로 지운다.
"""
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    Consent,
    CreditTransaction,
    Follow,
    GenerationJob,
    GenerationResult,
    Photo,
    Post,
    PostComment,
    PostVote,
    User,
)
from app.storage.base import get_storage


class PrivacyService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.storage = get_storage()

    async def _rows(self, model, *where):
        return list((await self.session.execute(select(model).where(*where))).scalars())

    async def export_user_data(self, user: User) -> dict:
        """GDPR Art.15/20 — 서비스가 보유한 내 데이터의 구조화된 사본."""
        consents = await self._rows(Consent, Consent.user_id == user.id)
        photos = await self._rows(Photo, Photo.user_id == user.id)
        jobs = await self._rows(GenerationJob, GenerationJob.user_id == user.id)
        job_ids = [j.id for j in jobs]
        results = (
            await self._rows(GenerationResult, GenerationResult.job_id.in_(job_ids)) if job_ids else []
        )
        posts = await self._rows(Post, Post.user_id == user.id)
        votes = await self._rows(PostVote, PostVote.user_id == user.id)
        comments = await self._rows(PostComment, PostComment.user_id == user.id)
        credits = await self._rows(CreditTransaction, CreditTransaction.user_id == user.id)
        follows = await self._rows(Follow, Follow.follower_id == user.id)

        iso = lambda dt: dt.isoformat() if dt else None  # noqa: E731
        return {
            "profile": {
                "id": str(user.id), "email": user.email, "nickname": user.nickname,
                "bio": user.bio, "provider": user.provider,
                "credit_balance": user.credit_balance, "created_at": iso(user.created_at),
            },
            "consents": [
                {"type": c.type, "granted": c.granted, "granted_at": iso(c.granted_at)} for c in consents
            ],
            "photos": [
                {"id": str(p.id), "status": p.status, "created_at": iso(p.created_at),
                 "delete_after": iso(p.delete_after), "deleted_at": iso(p.deleted_at)}
                for p in photos
            ],
            "generations": [
                {"job_id": str(j.id), "mode": j.mode, "status": j.status, "created_at": iso(j.created_at)}
                for j in jobs
            ],
            "posts": [
                {"id": str(p.id), "caption": p.caption, "buy_votes": p.buy_votes,
                 "skip_votes": p.skip_votes, "created_at": iso(p.created_at)}
                for p in posts
            ],
            "votes": [
                {"post_id": str(v.post_id), "choice": v.choice, "created_at": iso(v.created_at)} for v in votes
            ],
            "comments": [
                {"post_id": str(c.post_id), "content": c.content, "created_at": iso(c.created_at)}
                for c in comments
            ],
            "credit_transactions": [
                {"delta": t.delta, "reason": t.reason, "balance_after": t.balance_after,
                 "created_at": iso(t.created_at)}
                for t in credits
            ],
            "following": [str(f.followee_id) for f in follows],
        }

    async def delete_account(self, user_id: uuid.UUID) -> None:
        """GDPR Art.17 — 계정 + 전체 개인 데이터 즉시 삭제 (스토리지 파일 포함)."""
        # 1) 파일 삭제: 원본 사진 + 생성 결과 이미지
        photos = await self._rows(Photo, Photo.user_id == user_id)
        for photo in photos:
            try:
                self.storage.delete(photo.storage_key)
            except Exception:  # noqa: BLE001 — 파일이 이미 없어도 계정 삭제는 진행
                pass
        jobs = await self._rows(GenerationJob, GenerationJob.user_id == user_id)
        job_ids = [j.id for j in jobs]
        if job_ids:
            results = await self._rows(GenerationResult, GenerationResult.job_id.in_(job_ids))
            for result in results:
                try:
                    self.storage.delete(result.result_storage_key)
                except Exception:  # noqa: BLE001
                    pass

        # 2) DB 삭제: users 행 삭제 → 사진·게시물·투표·댓글·크레딧·팔로우 전부 FK CASCADE
        user = await self.session.get(User, user_id)
        if user is not None:
            await self.session.delete(user)
        await self.session.commit()
