"""SNS 피드 — 비포/애프터 '이거 어때요?' 투표."""
import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFoundError
from app.models import GenerationJob, GenerationResult, Partner, Photo, Post, PostComment, Product, User
from app.repositories.posts import PostRepository
from app.schemas.post import CommentOut, PostCreate, PostOut, PostUpdate

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
            # before(원본 사진)는 개인정보라 기본 비공개 — 사용자가 include_before로 동의할 때만.
            # URL이 아닌 스토리지 키를 저장해 presigned 만료와 무관하게 유지한다.
            if body.include_before and not before_url:
                job = await self.session.get(GenerationJob, result.job_id)
                photo = await self.session.get(Photo, job.photo_id) if job else None
                if photo is not None:
                    before_url = photo.storage_key
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

    # ── 수정 (비포 추가/제거) ─────────────────────────────
    async def update(self, user: User, post_id: uuid.UUID, body: PostUpdate) -> PostOut:
        post = await self.session.get(Post, post_id)
        if post is None:
            raise NotFoundError("게시물을 찾을 수 없습니다.")
        if post.user_id != user.id:
            raise AppError("본인 게시물만 수정할 수 있습니다.", code="FORBIDDEN", status_code=403)

        if body.caption is not None:
            post.caption = body.caption
        if body.remove_before:
            post.before_url = None
        elif body.before_url:
            post.before_url = body.before_url
        elif body.include_before:
            # 연결된 피팅 결과의 원본 업로드 사진을 비포로
            if post.result_id is None:
                raise AppError(
                    "연결된 피팅 결과가 없어 비포 사진을 찾을 수 없습니다.",
                    code="VALIDATION_ERROR",
                    status_code=422,
                )
            result = await self.session.get(GenerationResult, post.result_id)
            job = await self.session.get(GenerationJob, result.job_id) if result else None
            photo = await self.session.get(Photo, job.photo_id) if job else None
            if photo is None:
                raise AppError(
                    "원본 사진이 삭제되어 비포를 추가할 수 없습니다.",
                    code="VALIDATION_ERROR",
                    status_code=422,
                )
            post.before_url = photo.storage_key

        await self.session.commit()
        return await self._to_out(post, viewer_id=user.id)

    # ── 피드 ──────────────────────────────────────────────
    async def feed(self, user: User, *, sort: str, limit: int, offset: int) -> list[PostOut]:
        posts = await self.posts.list_feed(sort=sort, limit=limit, offset=offset, viewer_id=user.id)
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
        comment_counts = await self._comment_counts([p.id for p in posts])
        multi = await self._products_for_results([p.result_id for p in posts if p.result_id])
        return [
            self._build_out(
                p, authors.get(p.user_id), products.get(p.product_id), my_votes.get(p.id),
                comment_count=comment_counts.get(p.id, 0),
                products=multi.get(p.result_id) if p.result_id else None,
            )
            for p in posts
        ]

    # ── 투표 ──────────────────────────────────────────────
    async def vote(self, user: User, post_id: uuid.UUID, choice: str) -> tuple[PostOut, int]:
        post = await self.session.get(Post, post_id, with_for_update=True)
        if post is None:
            raise NotFoundError("게시물을 찾을 수 없습니다.")

        # 투표 크레딧 보상 제도는 폐지 — reward_credits는 호환을 위해 항상 0
        reward = 0
        existing = await self.posts.get_vote(post_id, user.id)
        if existing is None:
            await self.posts.add_vote(post_id, user.id, choice)
            self._bump(post, choice, +1)
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
    async def _products_for_results(
        self, result_ids: list[uuid.UUID]
    ) -> dict[uuid.UUID, list[Product]]:
        """게시물에 연결된 생성 결과 → 그 잡의 착용 아이템 전체 (멀티 피팅)."""
        if not result_ids:
            return {}
        rows = (
            await self.session.execute(
                select(GenerationResult.id, GenerationJob.options)
                .join(GenerationJob, GenerationResult.job_id == GenerationJob.id)
                .where(GenerationResult.id.in_(result_ids))
            )
        ).all()
        wanted: set[uuid.UUID] = set()
        per_result: dict[uuid.UUID, list[uuid.UUID]] = {}
        for result_id, options in rows:
            ids = [uuid.UUID(pid) for pid in (options or {}).get("product_ids") or []]
            per_result[result_id] = ids
            wanted.update(ids)
        if not wanted:
            return {}
        products = {
            p.id: p
            for p in (
                await self.session.execute(select(Product).where(Product.id.in_(wanted)))
            ).scalars()
        }
        return {
            rid: [products[i] for i in ids if i in products]
            for rid, ids in per_result.items()
            if ids
        }

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
        counts = await self._comment_counts([post.id])
        multi = (
            await self._products_for_results([post.result_id]) if post.result_id else {}
        )
        return self._build_out(
            post, author, product, vote.choice if vote else None,
            comment_count=counts.get(post.id, 0),
            products=multi.get(post.result_id),
        )

    @staticmethod
    def _build_out(
        post: Post, author: User | None, product: Product | None, my_vote: str | None,
        comment_count: int = 0, products: list[Product] | None = None,
    ) -> PostOut:
        return PostOut.model_validate(
            {
                "id": post.id,
                "author": author,
                "caption": post.caption,
                "before_url": post.before_url,
                "after_url": post.after_url,
                "product": product,
                "products": products or ([product] if product else []),
                "buy_votes": post.buy_votes,
                "skip_votes": post.skip_votes,
                "my_vote": my_vote,
                "comment_count": comment_count,
                "created_at": post.created_at,
            }
        )

    async def _comment_counts(self, post_ids: list[uuid.UUID]) -> dict[uuid.UUID, int]:
        rows = await self.session.execute(
            select(PostComment.post_id, func.count(PostComment.id))
            .where(PostComment.post_id.in_(post_ids))
            .group_by(PostComment.post_id)
        )
        return dict(rows.all())

    # ── 댓글 (계약 §10) ───────────────────────────────────
    async def comments(self, post_id: uuid.UUID) -> list[CommentOut]:
        post = await self.session.get(Post, post_id)
        if post is None:
            raise NotFoundError("게시물을 찾을 수 없습니다.")
        rows = await self.session.execute(
            select(PostComment, User)
            .join(User, PostComment.user_id == User.id)
            .where(PostComment.post_id == post_id)
            .order_by(PostComment.created_at)
        )
        return [
            CommentOut.model_validate(
                {"id": c.id, "author": u, "content": c.content, "created_at": c.created_at}
            )
            for c, u in rows.all()
        ]

    async def add_comment(self, user: User, post_id: uuid.UUID, content: str) -> CommentOut:
        post = await self.session.get(Post, post_id)
        if post is None:
            raise NotFoundError("게시물을 찾을 수 없습니다.")
        comment = PostComment(post_id=post_id, user_id=user.id, content=content)
        self.session.add(comment)
        await self.session.commit()
        return CommentOut.model_validate(
            {"id": comment.id, "author": user, "content": comment.content, "created_at": comment.created_at}
        )
