import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Product

MVP_CATEGORIES = ("top", "jacket", "shirt", "dress", "pants", "accessory", "shoes")


class ProductRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get(self, product_id: uuid.UUID) -> Product | None:
        return await self.session.get(Product, product_id)

    async def list_products(
        self,
        *,
        category: str | None = None,
        brand: str | None = None,
        min_price: int | None = None,
        max_price: int | None = None,
        limit: int = 20,
        offset: int = 0,
    ) -> list[Product]:
        stmt = select(Product).where(Product.category.in_(MVP_CATEGORIES))
        if category:
            stmt = stmt.where(Product.category == category)
        if brand:
            stmt = stmt.where(Product.brand == brand)
        if min_price is not None:
            stmt = stmt.where(Product.price >= min_price)
        if max_price is not None:
            stmt = stmt.where(Product.price <= max_price)
        stmt = stmt.order_by(Product.created_at.desc(), Product.id).limit(limit).offset(offset)
        result = await self.session.execute(stmt)
        return list(result.scalars())

    async def rank_by_text_embedding(
        self,
        query_vector: list[float],
        *,
        categories: tuple[str, ...] = MVP_CATEGORIES,
        exclude_ids: list[uuid.UUID] | None = None,
        limit: int = 12,
    ) -> list[tuple[Product, float]]:
        """규칙 필터(카테고리/재고) + pgvector 코사인 거리 랭킹."""
        distance = Product.text_embedding.cosine_distance(query_vector).label("distance")
        stmt = (
            select(Product, distance)
            .where(
                Product.category.in_(categories),
                Product.stock_status != "out_of_stock",
                Product.text_embedding.is_not(None),
            )
            .order_by(distance)
            .limit(limit)
        )
        if exclude_ids:
            stmt = stmt.where(Product.id.not_in(exclude_ids))
        result = await self.session.execute(stmt)
        return [(row[0], float(row[1])) for row in result.all()]

    async def similar_to(self, product: Product, limit: int = 5) -> list[Product]:
        if product.text_embedding is None:
            return []
        ranked = await self.rank_by_text_embedding(
            list(product.text_embedding), exclude_ids=[product.id], limit=limit
        )
        return [p for p, _ in ranked]
