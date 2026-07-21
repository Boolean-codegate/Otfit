"""OpenAI 생성 프로바이더 — GPT-5.6 Sol + Responses API image_generation 도구.

ChatGPT에서 "Sol이 옷을 입혀주는" 경로의 재현: raw images/edits가 아니라
Sol 모델이 이미지 생성 도구를 호출해 추론하며 생성한다 (인물·얼굴·배경 보존이
실측으로 우수했던 방식).

- 입력: 사용자 사진(R2 presigned URL) + 상품 옷 이미지(공개 URL) 두 장
- 이미지 모델: IMAGE_MODEL env(settings.image_model, 예: gpt-image-2) 우선,
  계정에서 막히면 gpt-image-1.5 → 도구 기본 모델 순으로 폴백
- 처리 시간이 길다(3분+): OPENAI_IMAGE_TIMEOUT_SECONDS(기본 300초)로 조정
- 정체성 게이트는 파이프라인에서 QUALITY_GATE_ENFORCE=false면 '기록만' 한다
- GENERATION_PROVIDER=openai 로 선택 (segmind/mock 공존)
"""
import base64
import logging

import openai
from openai import AsyncOpenAI

from app.core.config import get_settings
from app.providers.base import GarmentSpec, GenerationProvider, VisionAnalysis
from app.providers.publish import publish_photo_url

logger = logging.getLogger(__name__)

_FALLBACK_IMAGE_MODEL = "gpt-image-1.5"

# 계약 카테고리 → 지시문에 쓸 명칭
_CATEGORY_KO = {"top": "상의", "jacket": "재킷", "shirt": "셔츠", "dress": "원피스"}


def _instruction(garment: GarmentSpec, style: str | None, variation_seed: int) -> str:
    """ChatGPT에서 실제로 잘 됐던 지시문 그대로 (+상품 디테일 보강)."""
    category = _CATEGORY_KO.get(garment.category, "옷")
    attrs = garment.attributes
    desc = ", ".join(
        str(attrs[key]) for key in ("color", "pattern", "material") if attrs.get(key)
    )
    text = (
        f"첫 번째 사진의 인물, 얼굴, 헤어, 체형, 포즈, 배경을 그대로 유지하면서 "
        f"두 번째 사진의 옷({category})만 자연스럽게 입혀줘. 사실적인 패션 사진처럼."
    )
    if desc:
        text += f" (상품: {garment.title}, {desc})"
    if style:
        text += f" 스타일 무드: {style}."
    if variation_seed:
        text += f" 변형 {variation_seed}: 핏과 드레이프를 살짝 다르게."
    return text


class OpenAIGenerationProvider(GenerationProvider):
    def __init__(self) -> None:
        settings = get_settings()
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY is required for GENERATION_PROVIDER=openai")
        self.settings = settings
        self.client = AsyncOpenAI(
            api_key=settings.openai_api_key,
            timeout=settings.openai_image_timeout_seconds,
        )

    async def _generate(self, instruction: str, human_url: str, garment_url: str, tool: dict) -> bytes:
        response = await self.client.responses.create(
            model=self.settings.vision_model,  # gpt-5.6-sol (도구 호출 오케스트레이션)
            input=[{
                "role": "user",
                "content": [
                    {"type": "input_text", "text": instruction},
                    {"type": "input_image", "image_url": human_url},      # 1번째 = 인물
                    {"type": "input_image", "image_url": garment_url},    # 2번째 = 입힐 옷
                ],
            }],
            tools=[tool],
        )
        results = [
            item.result
            for item in response.output
            if getattr(item, "type", None) == "image_generation_call"
            and getattr(item, "result", None)
        ]
        if not results:
            raise RuntimeError(
                "image_generation 도구 결과가 없습니다: "
                + ((response.output_text or "")[:200] or "(출력 없음)")
            )
        return base64.b64decode(results[-1])

    async def swap_garment(
        self,
        photo_bytes: bytes,
        garment: GarmentSpec,
        analysis: VisionAnalysis,
        style: str | None = None,
        variation_seed: int = 0,
    ) -> bytes:
        if not garment.image_url.startswith("http"):
            raise RuntimeError(f"상품 이미지 URL이 유효하지 않습니다: {garment.image_url!r}")

        human_url = await publish_photo_url(photo_bytes)
        instruction = _instruction(garment, style, variation_seed)

        # 이미지 모델 폴백 체인: IMAGE_MODEL(gpt-image-2) → gpt-image-1.5 → 도구 기본값
        tool_candidates: list[dict] = [
            {"type": "image_generation", "model": self.settings.image_model},
        ]
        if self.settings.image_model != _FALLBACK_IMAGE_MODEL:
            tool_candidates.append({"type": "image_generation", "model": _FALLBACK_IMAGE_MODEL})
        tool_candidates.append({"type": "image_generation"})

        last_error: Exception | None = None
        for tool in tool_candidates:
            model_label = tool.get("model", "(도구 기본값)")
            try:
                image = await self._generate(instruction, human_url, garment.image_url, tool)
                logger.info("image_generation 성공 (image model=%s)", model_label)
                return image
            except (openai.BadRequestError, openai.NotFoundError) as exc:
                message = str(exc)
                # 모델명/권한 문제면 다음 후보로 폴백, 그 외는 즉시 실패
                if any(token in message.lower() for token in ("model", "not found", "unsupported", "invalid")):
                    logger.warning("image model %s 사용 불가 → 폴백: %s", model_label, message[:200])
                    last_error = exc
                    continue
                raise RuntimeError(f"image_generation 호출 실패: {message[:300]}") from exc
            except openai.APITimeoutError as exc:
                # 긴 작업 특성상 타임아웃은 1회 재시도 (같은 모델)
                logger.warning("image_generation timeout (model=%s) → 재시도", model_label)
                try:
                    return await self._generate(instruction, human_url, garment.image_url, tool)
                except Exception as retry_exc:  # noqa: BLE001
                    last_error = retry_exc
                    continue
        raise RuntimeError(
            f"모든 이미지 모델 후보 실패 (IMAGE_MODEL={self.settings.image_model}): {last_error!r}. "
            "계정 tier에서 해당 이미지 모델이 막혀 있을 수 있습니다."
        )
