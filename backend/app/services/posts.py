"""SNS 피드 — 비포/애프터 '이거 어때요?' 투표.

리텐션 루프: 투표 참여(타인 게시물, 하루 VOTE_REWARD_DAILY_LIMIT회)에 크레딧을 지급해
투표 → 크레딧 → 보정 → 게시 → 재방문의 순환을 만든다.
"""
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFoundError
from app.models import GenerationJob, GenerationResult, Partner, Post, Product, User
from app.repositories.posts import PostRepository
from app.schemas.post import PostCreate, PostOut
from app.services.credits import CreditService

VOTE_REWARD_CREDITS = 1
VOTE_REWARD_DAILY_LIMIT = 3


class PostService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.posts = PostRepository(session)

    # ── 게시 ──────────────────────────────────────────────
    async def create(self, user: User, body: PostCreate) -> PostOut:
        before_url = body.before_url
        after_url = body.after_url
        product_id = body.product_id

        if body.result_id is not None:
            result = await self.session.get(GenerationResult, body.result_id)
            if result is None:
                raise NotFoundError("생성 결과를 찾을 수 없습니다.")
            job = await self.session.get(GenerationJob, result.job_id)
            if job is None or job.user_id != user.id:
                raise AppError("본인의 생성 결과만 게시할 수 있습니다.", code="FORBIDDEN", status_code=403)
            after_url = after_url or result.result_storage_key
            product_id = product_id or result.product_id
            # before(원본 사진)는 개인정보라 기본 비공개 — 사용자가 before_url을 명시할 때만 게시
        if not after_url:
            raise AppError("after_url 또는 result_id 중 하나는 필요합니다.", code="VALIDATION_ERROR", status_code=422)

        post = await self.posts.create(
            user_id=user.id,
            result_id=body.result_id,
            product_id=product_id,
            caption=body.caption,
            before_url=before_url,
            after_url=after_url,
        )
        await self.session.commit()
        return await self._to_out(post, viewer_id=user.id)

    # ── 피드 ──────────────────────────────────────────────
    async def feed(self, user: User, *, sort: str, limit: int, offset: int) -> list[PostOut]:
        posts = await self.posts.list_feed(sort=sort, limit=limit, offset=offset)
        if not posts:
            return []
        author_ids = {p.user_id for p in posts}
        product_ids = {p.product_id for p in posts if p.product_id}
        authors = {
            u.id: u
            for u in (await self.session.execute(select(User).where(User.id.in_(author_ids)))).scalars()
        }
        products = {}
        if product_ids:
            products = {
                p.id: p
                for p in (await self.session.execute(select(Product).where(Product.id.in_(product_ids)))).scalars()
            }
        my_votes = await self.posts.votes_for_posts([p.id for p in posts], user.id)
        return [
            self._build_out(p, authors.get(p.user_id), products.get(p.product_id), my_votes.get(p.id))
            for p in posts
        ]

    # ── 투표 ──────────────────────────────────────────────
    async def vote(self, user: User, post_id: uuid.UUID, choice: str) -> tuple[PostOut, int]:
        post = await self.session.get(Post, post_id, with_for_update=True)
        if post is None:
            raise NotFoundError("게시물을 찾을 수 없습니다.")

        reward = 0
        existing = await self.posts.get_vote(post_id, user.id)
        if existing is None:
            # 신규 투표 — 보상은 '타인 게시물 + 일일 한도 내'일 때만
            votes_today = await self.posts.count_votes_today(user.id)
            await self.posts.add_vote(post_id, user.id, choice)
            self._bump(post, choice, +1)
            if post.user_id != user.id and votes_today < VOTE_REWARD_DAILY_LIMIT:
                reward = VOTE_REWARD_CREDITS
                await CreditService(self.session).grant(user.id, reward, "vote_reward")
        elif existing.choice != choice:
            # 재투표 = 선택 변경 (보상 없음)
            self._bump(post, existing.choice, -1)
            self._bump(post, choice, +1)
            existing.choice = choice
        # 같은 선택으로 재투표 → 멱등 no-op

        await self.session.commit()
        return await self._to_out(post, viewer_id=user.id), reward

    # ── 플랫폼 (홈 상단 쇼핑몰 스토리바) ──────────────────
    async def platforms(self) -> list[Partner]:
        result = await self.session.execute(select(Partner).order_by(Partner.created_at))
        return list(result.scalars().all())

    # ── 내부 ──────────────────────────────────────────────
    @staticmethod
    def _bump(post: Post, choice: str, delta: int) -> None:
        if choice == "buy":
            post.buy_votes = max(0, post.buy_votes + delta)
        else:
            post.skip_votes = max(0, post.skip_votes + delta)

    async def _to_out(self, post: Post, viewer_id: uuid.UUID) -> PostOut:
        author = await self.session.get(User, post.user_id)
        product = await self.session.get(Product, post.product_id) if post.product_id else None
        vote = await self.posts.get_vote(post.id, viewer_id)
        return self._build_out(post, author, product, vote.choice if vote else None)

    @staticmethod
    def _build_out(post: Post, author: User | None, product: Product | None, my_vote: str | None) -> PostOut:
        return PostOut.model_validate(
            {
                "id": post.id,
                "author": author,
                "caption": post.caption,
                "before_url": post.before_url,
                "after_url": post.after_url,
                "product": product,
                "buy_votes": post.buy_votes,
                "skip_votes": post.skip_votes,
                "my_vote": my_vote,
                "created_at": post.created_at,
            }
        )
