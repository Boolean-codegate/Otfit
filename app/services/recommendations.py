import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import InvalidPhotoError
from app.models import PhotoAnalysis, Product
from app.providers.factory import get_embedding_provider
from app.repositories.photos import PhotoRepository
from app.repositories.products import ProductRepository

GROUP_SIZE = 4  # 스타일 그룹당 상품 수


def build_style_query(analysis: PhotoAnalysis) -> str:
    """분석 결과 → 임베딩 질의 텍스트. 사진 분위기(색/배경/조명/스타일)를 상품 텍스트 공간으로 사영."""
    parts: list[str] = []
    parts += [str(t) for t in analysis.color_palette]
    parts += [str(t) for t in analysis.background_tags]
    if isinstance(analysis.lighting, dict):
        parts.append(str(analysis.lighting.get("direction", "")))
    parts += [str(s.get("style", "")) for s in analysis.style_suggestions]
    return " ".join(p for p in parts if p)


class RecommendationService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.photos = PhotoRepository(session)
        self.products = ProductRepository(session)

    async def valid_analysis(self, photo_id: uuid.UUID) -> PhotoAnalysis:
        analysis = await self.photos.get_analysis(photo_id)
        if analysis is None:
            raise InvalidPhotoError("먼저 사진 분석(POST /photos/{id}/analyze)을 실행하세요.")
        if not analysis.is_valid:
            raise InvalidPhotoError(
                "이 사진은 생성 범위 밖입니다.", detail={"reject_reason": analysis.reject_reason}
            )
        return analysis

    async def ranked_products(self, analysis: PhotoAnalysis, limit: int = 24) -> list[Product]:
        """규칙 필터(카테고리/재고) + pgvector 임베딩 랭킹. 파이프라인 3단계에서도 재사용."""
        query_vec = await get_embedding_provider().embed_text(build_style_query(analysis))
        ranked = await self.products.rank_by_text_embedding(query_vec, limit=limit)
        return [p for p, _ in ranked]

    async def recommend(self, photo_id: uuid.UUID, mode: str, style_id: str | None) -> dict:
        analysis = await self.valid_analysis(photo_id)
        ranked = await self.ranked_products(analysis)

        if mode != "B_stylist":
            # A_direct/C_similar/D_variation: 평면 랭킹 리스트 (계약 §4 허용)
            return {"photo_id": photo_id, "mode": mode, "groups": [], "products": ranked[:12]}

        suggestions = list(analysis.style_suggestions)
        if style_id:
            suggestions = [s for s in suggestions if s.get("id") == style_id]

        groups = []
        for suggestion in suggestions:
            style = suggestion.get("style")
            matched = [p for p in ranked if p.attributes.get("style") == style][:GROUP_SIZE]
            if not matched:  # 스타일 매칭이 비면 랭킹 상위로 채워 데모 플로우 보장
                matched = ranked[:GROUP_SIZE]
            groups.append(
                {"style_id": suggestion["id"], "label": suggestion["label"], "products": matched}
            )
        return {"photo_id": photo_id, "mode": mode, "groups": groups, "products": None}
