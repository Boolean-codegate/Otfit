from functools import lru_cache

from app.core.config import get_settings
from app.providers.base import EmbeddingProvider, GenerationProvider, VisionProvider

# 컴포넌트별 mock|live 분기. live 구현체:
#   vision/embedding = OpenAI, generation = Segmind IDM-VTON
# VISION_PROVIDER / EMBEDDING_PROVIDER / GENERATION_PROVIDER 로 개별 오버라이드,
# 비어 있으면 PROVIDER_MODE 를 따른다.


@lru_cache
def get_vision_provider() -> VisionProvider:
    if get_settings().resolved_provider("vision") == "live":
        from app.providers.openai.vision import OpenAIVisionProvider

        return OpenAIVisionProvider()
    from app.providers.mock.vision import MockVisionProvider

    return MockVisionProvider()


@lru_cache
def get_embedding_provider() -> EmbeddingProvider:
    if get_settings().resolved_provider("embedding") == "live":
        from app.providers.openai.embedding import OpenAIEmbeddingProvider

        return OpenAIEmbeddingProvider()
    from app.providers.mock.embedding import MockEmbeddingProvider

    return MockEmbeddingProvider()


@lru_cache
def get_generation_provider() -> GenerationProvider:
    if get_settings().resolved_provider("generation") == "live":
        from app.providers.segmind.generation import SegmindGenerationProvider

        return SegmindGenerationProvider()
    from app.providers.mock.generation import MockGenerationProvider

    return MockGenerationProvider()
