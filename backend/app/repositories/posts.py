import uuid
from datetime import datetime, time, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Post, PostVote


class PostRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get(self, post_id: uuid.UUID) -> Post | None:
        return await self.session.get(Post, post_id)

    async def create(self, **kwargs) -> Post:
        post = Post(**kwargs)
        self.session.add(post)
        await self.session.flush()
        return post

    async def list_feed(self, *, sort: str, limit: int, offset: int) -> list[Post]:
        query = select(Post)
        if sort == "hot":
            query = query.order_by((Post.buy_votes + Post.skip_votes).desc(), Post.created_at.desc())
        else:  # new
            query = query.order_by(Post.created_at.desc())
        result = await self.session.execute(query.offset(offset).limit(limit))
        return list(result.scalars().all())

    async def get_vote(self, post_id: uuid.UUID, user_id: uuid.UUID) -> PostVote | None:
        result = await self.session.execute(
            select(PostVote).where(PostVote.post_id == post_id, PostVote.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def votes_for_posts(
        self, post_ids: list[uuid.UUID], user_id: uuid.UUID
    ) -> dict[uuid.UUID, str]:
        """피드 응답용 — 사용자의 투표 여부를 한 번에 조회."""
        if not post_ids:
            return {}
        result = await self.session.execute(
            select(PostVote.post_id, PostVote.choice).where(
                PostVote.post_id.in_(post_ids), PostVote.user_id == user_id
            )
        )
        return dict(result.all())

    async def add_vote(self, post_id: uuid.UUID, user_id: uuid.UUID, choice: str) -> PostVote:
        vote = PostVote(post_id=post_id, user_id=user_id, choice=choice)
        self.session.add(vote)
        await self.session.flush()
        return vote

    async def count_votes_today(self, user_id: uuid.UUID) -> int:
        """오늘(UTC) 이 사용자가 새로 만든 투표 수 — 보상 일일 한도용."""
        today_start = datetime.combine(datetime.now(timezone.utc).date(), time.min, tzinfo=timezone.utc)
        result = await self.session.execute(
            select(func.count()).select_from(PostVote).where(
                PostVote.user_id == user_id, PostVote.created_at >= today_start
            )
        )
        return int(result.scalar_one())
