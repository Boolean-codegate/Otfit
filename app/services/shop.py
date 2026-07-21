import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFoundError
from app.repositories.products import ProductRepository
from app.services.generations import GenerationService


class ShopService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.products = ProductRepository(session)

    async def shop_for_result(self, user_id: uuid.UUID, result_id: uuid.UUID) -> dict:
        """적용 상품 + 유사 상품(MODE C). 쇼퍼블 진입점 — 계약 §6."""
        result = await GenerationService(self.session).get_owned_result(user_id, result_id)
        applied = await self.products.get(result.product_id)
        if applied is None:
            raise NotFoundError("적용된 상품을 찾을 수 없습니다.")
        similar = await self.products.similar_to(applied, limit=4)
        return {"applied_product": applied, "similar_products": similar}
