"""이미지 콘텐츠 모더레이션 — 나체·성적·폭력·혐오 이미지 업로드 차단.

업로드 파이프라인의 가장 상류(저장 전)에서 실행되어, 유해 이미지가
스토리지·피드·외부 AI(Segmind 등)에 도달하기 전에 거부한다.

- mock: 항상 통과 (키 없이 전체 플로우 동작 — 기존 프로바이더 규칙과 동일)
- live(openai): omni-moderation-latest 멀티모달 모더레이션.
  성적(sexual, sexual/minors), 폭력(violence, violence/graphic),
  자해(self-harm 계열) 카테고리를 이미지 입력으로 판별한다.
"""
import base64
import json
import logging
from dataclasses import dataclass, field
from functools import lru_cache

from app.core.config import get_settings

logger = logging.getLogger(__name__)


@dataclass
class ModerationVerdict:
    flagged: bool
    categories: list[str] = field(default_factory=list)
    # True(기본) = 성적·폭력 등 중대 위반 → 스트라이크/밴 대상.
    # False = 위험 물품(칼·총 등) 감지 → 차단·경고만 (제재 없음).
    severe: bool = True


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
        if result.flagged:
            flagged_categories = [
                name for name, is_flagged in result.categories.model_dump().items() if is_flagged
            ]
            return ModerationVerdict(flagged=True, categories=flagged_categories, severe=True)
        # omni는 '웃으며 칼 든 사진' 같은 위험 물품을 잡지 못한다(실측 violence 0.016)
        # → 비전 모델로 무기/흉기 여부를 추가 스캔
        return await self._danger_scan(data_url)

    async def _danger_scan(self, data_url: str) -> ModerationVerdict:
        """무기·위험 물품 + 공포·혐오 이미지 감지. 실패 시 통과(fail-open)."""
        prompt = (
            "패션 피팅 서비스에 올라온 인물 사진이야. 다음 두 가지를 판단해:\n"
            "1) dangerous: 무기나 위험한 물건(칼, 총, 흉기, 폭발물 등)이 보이는가? "
            "요리 재료 속 식칼처럼 명백히 무해한 맥락이 아니라, 사람이 들고 있거나 "
            "부각되어 위협적으로 보이면 true.\n"
            "2) disturbing: 보는 사람에게 공포감·혐오감을 줄 수 있는가? "
            "(귀신·심령사진 풍의 연출, 호러·좀비 분장, 유혈·상처 표현, 그로테스크한 연출, 기괴하게 변형된 얼굴 등)\n"
            'JSON만 출력: {"dangerous": true|false, "items": ["knife", ...], "disturbing": true|false}'
        )
        try:
            res = await self.client.with_options(timeout=20.0).responses.create(
                model=get_settings().vision_model,
                input=[{
                    "role": "user",
                    "content": [
                        {"type": "input_text", "text": prompt},
                        {"type": "input_image", "image_url": data_url},
                    ],
                }],
            )
            text = (res.output_text or "").strip()
            if text.startswith("```"):
                text = text.strip("`").removeprefix("json").strip()
            verdict = json.loads(text)
            categories: list[str] = []
            if verdict.get("dangerous"):
                categories += [str(i) for i in (verdict.get("items") or [])] or ["weapon"]
            if verdict.get("disturbing"):
                categories.append("disturbing")
            if categories:
                return ModerationVerdict(flagged=True, categories=categories, severe=False)
        except Exception:  # noqa: BLE001 — 스캔 실패가 정상 업로드를 막으면 안 됨
            logger.exception("위험 물품/공포 이미지 스캔 실패 (통과 처리)")
        return ModerationVerdict(flagged=False)


@lru_cache
def get_moderation_provider():
    if get_settings().resolved_provider("moderation") in ("live", "openai"):
        return OpenAIModerationProvider()
    return MockModerationProvider()
