"""마이페이지 (계약 §11): 내 피팅 기록 / 내 사진 / 찜한 상품."""
import uuid

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import NotFoundError
from app.models import Favorite, GenerationJob, GenerationResult, Photo, Post, Product
from app.storage.base import get_storage


class MyPageService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.settings = get_settings()

    async def fittings(self, user_id: uuid.UUID, limit: int, offset: int) -> dict:
        """품질 통과 결과만, 최신순 (QUALITY_GATE_ENFORCE=false면 전부)."""
        stmt = (
            select(GenerationResult, Product, Photo, GenerationJob)
            .join(GenerationJob, GenerationResult.job_id == GenerationJob.id)
            .outerjoin(Product, GenerationResult.product_id == Product.id)
            .outerjoin(Photo, GenerationJob.photo_id == Photo.id)
            .where(GenerationJob.user_id == user_id)
            .order_by(GenerationResult.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        if self.settings.quality_gate_enforce:
            stmt = stmt.where(
                GenerationResult.identity_preserved.is_(True),
                GenerationResult.quality_score >= self.settings.quality_score_threshold,
            )
        rows = (await self.session.execute(stmt)).all()
        # 이미 피드에 게시한 결과면 post_id를 함께 내려준다 ('피드 보러 가기' 분기)
        result_ids = [result.id for result, _, _, _ in rows]
        posted: dict[uuid.UUID, uuid.UUID] = {}
        if result_ids:
            post_rows = await self.session.execute(
                select(Post.result_id, Post.id)
                .where(Post.user_id == user_id, Post.result_id.in_(result_ids))
                .order_by(Post.created_at)
            )
            posted = dict(post_rows.all())
        # 멀티 아이템 피팅: job.options.product_ids의 상품 전체를 함께 내려준다
        multi_ids: set[uuid.UUID] = set()
        for _, _, _, job in rows:
            for pid in (job.options or {}).get("product_ids") or []:
                multi_ids.add(uuid.UUID(pid))
        products_map: dict[uuid.UUID, Product] = {}
        if multi_ids:
            products_map = {
                p.id: p
                for p in (
                    await self.session.execute(
                        select(Product).where(Product.id.in_(multi_ids))
                    )
                ).scalars()
            }

        def _items_for(job: GenerationJob, primary: Product | None) -> list[Product]:
            ids = [uuid.UUID(pid) for pid in (job.options or {}).get("product_ids") or []]
            loaded = [products_map[i] for i in ids if i in products_map]
            if loaded:
                return loaded
            return [primary] if primary else []

        storage = get_storage()
        items = [
            {
                "result_id": result.id,
                "job_id": result.job_id,
                "result_url": storage.url_for(result.result_storage_key),
                # 원본 사진이 삭제됐으면 비포 제공 안 함 (깨진 이미지 방지)
                "source_photo_url": (
                    storage.url_for(photo.storage_key)
                    if photo is not None and photo.deleted_at is None
                    else None
                ),
                "post_id": posted.get(result.id),
                "style_label": result.style_label,
                "product": product,
                "products": _items_for(job, product),
                "created_at": result.created_at,
            }
            for result, product, photo, job in rows
        ]
        return {"items": items, "next_cursor": str(offset + limit) if len(rows) == limit else None}

    async def photos(self, user_id: uuid.UUID, limit: int, offset: int) -> dict:
        stmt = (
            select(Photo)
            .where(Photo.user_id == user_id, Photo.deleted_at.is_(None))
            .order_by(Photo.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        photos = list((await self.session.execute(stmt)).scalars())
        storage = get_storage()
        items = [
            {
                "id": photo.id,
                "storage_url": storage.url_for(photo.storage_key),
                "width": photo.width,
                "height": photo.height,
                "status": photo.status,
                "uploaded_at": photo.created_at,
            }
            for photo in photos
        ]
        return {"items": items, "next_cursor": str(offset + limit) if len(photos) == limit else None}

    async def favorites(self, user_id: uuid.UUID) -> list[Product]:
        stmt = (
            select(Product)
            .join(Favorite, Favorite.product_id == Product.id)
            .where(Favorite.user_id == user_id)
            .order_by(Favorite.created_at.desc())
        )
        return list((await self.session.execute(stmt)).scalars())

    async def add_favorite(self, user_id: uuid.UUID, product_id: uuid.UUID) -> None:
        product = await self.session.get(Product, product_id)
        if product is None:
            raise NotFoundError("상품을 찾을 수 없습니다.")
        exists = (
            await self.session.execute(
                select(Favorite).where(
                    Favorite.user_id == user_id, Favorite.product_id == product_id
                )
            )
        ).scalar_one_or_none()
        if exists is None:  # 멱등
            self.session.add(Favorite(user_id=user_id, product_id=product_id))
        await self.session.commit()

    async def remove_favorite(self, user_id: uuid.UUID, product_id: uuid.UUID) -> None:
        await self.session.execute(
            delete(Favorite).where(
                Favorite.user_id == user_id, Favorite.product_id == product_id
            )
        )
        await self.session.commit()
