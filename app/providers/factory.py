from functools import lru_cache

from app.core.config import get_settings
from app.providers.base import EmbeddingProvider, GenerationProvider, VisionProvider


@lru_cache
def get_vision_provider() -> VisionProvider:
    if get_settings().provider_mode == "live":
        from app.providers.openai.vision import OpenAIVisionProvider

        return OpenAIVisionProvider()
    from app.providers.mock.vision import MockVisionProvider

    return MockVisionProvider()


@lru_cache
def get_embedding_provider() -> EmbeddingProvider:
    if get_settings().provider_mode == "live":
        from app.providers.openai.embedding import OpenAIEmbeddingProvider

        return OpenAIEmbeddingProvider()
    from app.providers.mock.embedding import MockEmbeddingProvider

    return MockEmbeddingProvider()


@lru_cache
def get_generation_provider() -> GenerationProvider:
    if get_settings().provider_mode == "live":
        from app.providers.openai.generation import OpenAIGenerationProvider

        return OpenAIGenerationProvider()
    from app.providers.mock.generation import MockGenerationProvider

    return MockGenerationProvider()
