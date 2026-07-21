"""소셜 프로필 (계약 §12): 유저 검색·프로필·게시물 그리드·팔로우."""
import uuid

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, ForbiddenError, NotFoundError
from app.models import Follow, Post, User
from app.services.posts import PostService


class ProfileService:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def _get_user(self, user_id: uuid.UUID) -> User:
        user = await self.session.get(User, user_id)
        if user is None:
            raise NotFoundError("사용자를 찾을 수 없습니다.")
        return user

    async def search(self, query: str, limit: int = 20) -> list[User]:
        if not query.strip():
            return []
        result = await self.session.execute(
            select(User)
            .where(User.nickname.ilike(f"%{query.strip()}%"))
            .order_by(User.nickname)
            .limit(limit)
        )
        return list(result.scalars())

    async def profile(self, viewer: User, user_id: uuid.UUID) -> dict:
        user = await self._get_user(user_id)
        post_count = (
            await self.session.execute(
                select(func.count(Post.id)).where(Post.user_id == user_id)
            )
        ).scalar_one()
        follower_count = (
            await self.session.execute(
                select(func.count(Follow.id)).where(Follow.followee_id == user_id)
            )
        ).scalar_one()
        following_count = (
            await self.session.execute(
                select(func.count(Follow.id)).where(Follow.follower_id == user_id)
            )
        ).scalar_one()
        is_following = (
            await self.session.execute(
                select(Follow).where(
                    Follow.follower_id == viewer.id, Follow.followee_id == user_id
                )
            )
        ).scalar_one_or_none() is not None
        return {
            "id": user.id,
            "nickname": user.nickname,
            "bio": user.bio,
            "post_count": post_count,
            "follower_count": follower_count,
            "following_count": following_count,
            "is_following": is_following,
            "is_me": viewer.id == user_id,
        }

    async def user_posts(self, viewer: User, user_id: uuid.UUID, limit: int, offset: int) -> dict:
        await self._get_user(user_id)
        posts = list(
            (
                await self.session.execute(
                    select(Post)
                    .where(Post.user_id == user_id)
                    .order_by(Post.created_at.desc())
                    .offset(offset)
                    .limit(limit)
                )
            ).scalars()
        )
        post_service = PostService(self.session)
        items = [await post_service._to_out(post, viewer_id=viewer.id) for post in posts]
        return {
            "items": items,
            "next_cursor": str(offset + limit) if len(posts) == limit else None,
        }

    async def followers(self, user_id: uuid.UUID) -> list[User]:
        await self._get_user(user_id)
        rows = await self.session.execute(
            select(User)
            .join(Follow, Follow.follower_id == User.id)
            .where(Follow.followee_id == user_id)
            .order_by(Follow.created_at.desc())
        )
        return list(rows.scalars())

    async def following(self, user_id: uuid.UUID) -> list[User]:
        await self._get_user(user_id)
        rows = await self.session.execute(
            select(User)
            .join(Follow, Follow.followee_id == User.id)
            .where(Follow.follower_id == user_id)
            .order_by(Follow.created_at.desc())
        )
        return list(rows.scalars())

    async def update_me(self, viewer: User, *, nickname: str | None, bio: str | None) -> User:
        if nickname is not None:
            viewer.nickname = nickname.strip()
        if bio is not None:
            viewer.bio = bio.strip()
        await self.session.commit()
        return viewer

    async def follow(self, viewer: User, user_id: uuid.UUID) -> None:
        if viewer.id == user_id:
            raise AppError("자기 자신은 팔로우할 수 없습니다.", code="VALIDATION_ERROR", status_code=422)
        await self._get_user(user_id)
        exists = (
            await self.session.execute(
                select(Follow).where(
                    Follow.follower_id == viewer.id, Follow.followee_id == user_id
                )
            )
        ).scalar_one_or_none()
        if exists is None:  # 멱등
            self.session.add(Follow(follower_id=viewer.id, followee_id=user_id))
        await self.session.commit()

    async def unfollow(self, viewer: User, user_id: uuid.UUID) -> None:
        await self.session.execute(
            delete(Follow).where(
                Follow.follower_id == viewer.id, Follow.followee_id == user_id
            )
        )
        await self.session.commit()

    async def delete_post(self, viewer: User, post_id: uuid.UUID) -> None:
        post = await self.session.get(Post, post_id)
        if post is None:
            raise NotFoundError("게시물을 찾을 수 없습니다.")
        if post.user_id != viewer.id:
            raise ForbiddenError("본인 게시물만 삭제할 수 있습니다.")
        await self.session.delete(post)
        await self.session.commit()
