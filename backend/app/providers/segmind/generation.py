"""Segmind IDM-VTON live 생성 프로바이더.

- POST https://api.segmind.com/v1/idm-vton (x-api-key 인증)
- human_img / garm_img 는 Segmind 서버가 직접 가져가는 "공개 접근 가능 URL"이어야 한다.
  → 사용자 사진 바이트를 S3(R2)에 올리고 presigned URL을 만들어 넘긴다.
  → garm_img 는 상품 카탈로그의 공개 image_url 을 그대로 사용.
- 응답은 이미지 바이너리. 인터페이스(swap_garment → bytes)는 mock과 동일하므로
  저장(result_storage_key)은 기존 파이프라인이 담당한다.
"""
import logging

import httpx

from app.core.config import get_settings
from app.providers.base import GarmentSpec, GenerationProvider, VisionAnalysis
from app.providers.publish import publish_photo_url

logger = logging.getLogger(__name__)

# 계약 카테고리 → IDM-VTON category
_CATEGORY_MAP = {
    "top": "upper_body",
    "jacket": "upper_body",
    "shirt": "upper_body",
    "dress": "dresses",
    "pants": "lower_body",
    # accessory는 IDM-VTON 미지원 — OpenAI 생성 경로에서만 처리 가능
}

_INPUT_URL_TTL_SECONDS = 3600
_RETRYABLE_STATUS = {429, 500, 502, 503, 504}


def _garment_description(garment: GarmentSpec) -> str:
    """예: 'ivory solid linen 린넨 오버셔츠'"""
    attrs = garment.attributes
    parts = [
        str(attrs[key])
        for key in ("color", "pattern", "length", "material")
        if attrs.get(key)
    ]
    parts.append(garment.title)
    return " ".join(parts)


class SegmindGenerationProvider(GenerationProvider):
    def __init__(self) -> None:
        settings = get_settings()
        if not settings.segmind_api_key:
            raise RuntimeError("SEGMIND_API_KEY is required in live mode")
        self.settings = settings

    async def _publish_human_image(self, photo_bytes: bytes) -> str:
        """사용자 사진 → R2 presigned URL (공용 헬퍼: app/providers/publish.py)."""
        return await publish_photo_url(photo_bytes, _INPUT_URL_TTL_SECONDS)

    async def generate_from_urls(
        self,
        *,
        human_url: str,
        garment_url: str,
        category: str,
        description: str,
        seed: int,
    ) -> bytes:
        """IDM-VTON 호출 (타임아웃 시 1회 재시도). 검증 스크립트에서도 사용."""
        payload = {
            "human_img": human_url,
            "garm_img": garment_url,
            "category": category,
            "garment_des": description,
            "crop": True,  # 3:4가 아닌 사진 자동 크롭
            "steps": self.settings.segmind_steps,
            "seed": seed,
        }
        timeout = httpx.Timeout(self.settings.segmind_timeout_seconds)
        last_error: Exception | None = None
        async with httpx.AsyncClient(timeout=timeout) as client:
            for attempt in range(2):  # 원호출 + 재시도 1회
                try:
                    response = await client.post(
                        self.settings.segmind_api_url,
                        json=payload,
                        headers={"x-api-key": self.settings.segmind_api_key},
                    )
                    if response.status_code == 200:
                        content_type = response.headers.get("content-type", "")
                        if not content_type.startswith("image/"):
                            raise RuntimeError(
                                f"Segmind이 이미지가 아닌 응답을 반환: {content_type} {response.text[:200]}"
                            )
                        return response.content
                    if response.status_code in _RETRYABLE_STATUS:
                        last_error = RuntimeError(
                            f"Segmind {response.status_code}: {response.text[:300]}"
                        )
                        logger.warning("segmind retryable error (attempt %s): %s", attempt, last_error)
                        continue
                    raise RuntimeError(
                        f"Segmind {response.status_code}: {response.text[:300]}"
                    )
                except httpx.TimeoutException as exc:
                    last_error = exc
                    logger.warning("segmind timeout (attempt %s)", attempt)
        raise RuntimeError(f"Segmind IDM-VTON 호출 실패: {last_error!r}")

    async def swap_garment(
        self,
        photo_bytes: bytes,
        garment: GarmentSpec,
        analysis: VisionAnalysis,
        style: str | None = None,
        variation_seed: int = 0,
    ) -> bytes:
        category = _CATEGORY_MAP.get(garment.category)
        if category is None:
            raise RuntimeError(f"IDM-VTON 미지원 카테고리: {garment.category}")
        if not garment.image_url.startswith("http"):
            raise RuntimeError(f"상품 이미지 URL이 유효하지 않습니다: {garment.image_url!r}")

        human_url = await self._publish_human_image(photo_bytes)
        return await self.generate_from_urls(
            human_url=human_url,
            garment_url=garment.image_url,
            category=category,
            description=_garment_description(garment),
            seed=42 + variation_seed,
        )
