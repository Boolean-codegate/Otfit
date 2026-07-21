"""이미지 콘텐츠 모더레이션 — 나체·성적·폭력·혐오 이미지 업로드 차단.

업로드 파이프라인의 가장 상류(저장 전)에서 실행되어, 유해 이미지가
스토리지·피드·외부 AI(Segmind 등)에 도달하기 전에 거부한다.

- mock: 항상 통과 (키 없이 전체 플로우 동작 — 기존 프로바이더 규칙과 동일)
- live(openai): omni-moderation-latest 멀티모달 모더레이션.
  성적(sexual, sexual/minors), 폭력(violence, violence/graphic),
  자해(self-harm 계열) 카테고리를 이미지 입력으로 판별한다.
"""
import base64
from dataclasses import dataclass, field
from functools import lru_cache

from app.core.config import get_settings


@dataclass
class ModerationVerdict:
    flagged: bool
    categories: list[str] = field(default_factory=list)


class MockModerationProvider:
    async def check(self, image_bytes: bytes) -> ModerationVerdict:
        return ModerationVerdict(flagged=False)


class OpenAIModerationProvider:
    def __init__(self):
        from openai import AsyncOpenAI

        self.client = AsyncOpenAI(api_key=get_settings().openai_api_key)

    async def check(self, image_bytes: bytes) -> ModerationVerdict:
        data_url = "data:image/jpeg;base64," + base64.b64encode(image_bytes).decode()
        res = await self.client.moderations.create(
            model="omni-moderation-latest",
            input=[{"type": "image_url", "image_url": {"url": data_url}}],
        )
        result = res.results[0]
        flagged_categories = [
            name for name, is_flagged in result.categories.model_dump().items() if is_flagged
        ]
        return ModerationVerdict(flagged=result.flagged, categories=flagged_categories)


@lru_cache
def get_moderation_provider():
    if get_settings().resolved_provider("moderation") in ("live", "openai"):
        return OpenAIModerationProvider()
    return MockModerationProvider()
