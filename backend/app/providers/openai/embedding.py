"""OpenAI 임베딩 — text-embedding-3-small (dimensions=512로 DB 스키마와 일치).

이미지 임베딩은 초기엔 텍스트(캡션/속성) 랭킹만으로 충분하므로 미구현.
TODO: open_clip 도입 또는 상품 캡션 → 텍스트 임베딩 대체.
"""
from openai import AsyncOpenAI

from app.core.config import get_settings
from app.providers.base import EmbeddingProvider


class OpenAIEmbeddingProvider(EmbeddingProvider):
    def __init__(self) -> None:
        settings = get_settings()
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY is required in live mode")
        self.client = AsyncOpenAI(api_key=settings.openai_api_key)
        self.model = settings.embedding_model
        self.dim = settings.embedding_dim

    async def embed_text(self, text: str) -> list[float]:
        response = await self.client.embeddings.create(
            model=self.model, input=text, dimensions=self.dim
        )
        return response.data[0].embedding

    async def embed_image(self, image_bytes: bytes) -> list[float]:
        raise NotImplementedError("초기 버전은 텍스트 임베딩 랭킹만 사용 (open_clip 도입 예정)")
