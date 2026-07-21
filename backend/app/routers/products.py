from fastapi import APIRouter, Query

from app.core.deps import CurrentUser, DbSession
from app.core.errors import AppError
from app.repositories.products import ProductRepository
from app.schemas.product import ProductListResponse

router = APIRouter(tags=["products"])


@router.get("/products", response_model=ProductListResponse)
async def list_products(
    user: CurrentUser,
    session: DbSession,
    category: str | None = None,
    brand: str | None = None,
    min_price: int | None = None,
    max_price: int | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = None,
):
    try:
        offset = int(cursor) if cursor else 0
    except ValueError:
        raise AppError("cursor가 올바르지 않습니다.", code="VALIDATION_ERROR", status_code=422)

    items = await ProductRepository(session).list_products(
        category=category,
        brand=brand,
        min_price=min_price,
        max_price=max_price,
        limit=limit,
        offset=offset,
    )
    next_cursor = str(offset + limit) if len(items) == limit else None
    return {"items": items, "next_cursor": next_cursor}
