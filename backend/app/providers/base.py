"""외부 AI 의존성 추상화.

- VisionProvider(두뇌): 사진 분석·MVP 범위 판정·스타일 추론 + 품질 검사
- GenerationProvider(손): 의상 영역 인페인팅 (픽셀 생성)
- EmbeddingProvider: 상품 랭킹용 텍스트/이미지 임베딩

PROVIDER_MODE=mock 이면 키 없이 전체 플로우가 동작하고, live(OpenAI) 구현체로
갈아끼우면 상용 API로 전환된다. 인터페이스는 양쪽이 동일하다.
"""
from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class VisionAnalysis:
    person_count: int
    pose: str  # front | three_quarter | side | back
    garment_regions: list  # [{"type": "top", "bbox": [x, y, w, h]}, ...]
    occlusion_score: float  # 0(가림 없음) ~ 1(심한 가림)
    background_tags: list
    lighting: dict  # {"brightness": 0.7, "direction": "front"}
    color_palette: list
    style_suggestions: list  # [{"id": "st_1", "label": "...", "style": "casual"}, ...]
    is_valid: bool = True
    # MULTIPLE_PERSONS | HEAVY_OCCLUSION | UNSUPPORTED_POSE | LOW_RESOLUTION
    reject_reason: str | None = None


@dataclass
class QualityReport:
    quality_score: float  # 0~1
    identity_preserved: bool
    issues: list = field(default_factory=list)


@dataclass
class GarmentSpec:
    """생성 프로바이더에 넘기는 상품 정보 (ORM 비의존)."""

    product_id: str
    title: str
    brand: str
    category: str
    attributes: dict  # color / pattern / length / material
    image_url: str = ""  # 상품 옷 이미지 (Segmind garm_img — 공개 URL이어야 함)


class VisionProvider(ABC):
    @abstractmethod
    async def analyze(self, image_bytes: bytes) -> VisionAnalysis: ...

    @abstractmethod
    async def assess_quality(self, original_bytes: bytes, generated_bytes: bytes) -> QualityReport: ...


class EmbeddingProvider(ABC):
    @abstractmethod
    async def embed_text(self, text: str) -> list[float]: ...

    @abstractmethod
    async def embed_image(self, image_bytes: bytes) -> list[float]: ...


class GenerationProvider(ABC):
    @abstractmethod
    async def swap_garment(
        self,
        photo_bytes: bytes,
        garment: GarmentSpec,
        analysis: VisionAnalysis,
        style: str | None = None,
        variation_seed: int = 0,
    ) -> bytes:
        """얼굴·체형·배경을 유지한 채 의상만 교체한 이미지를 반환한다."""

    async def swap_garments(
        self,
        photo_bytes: bytes,
        garments: list[GarmentSpec],
        analysis: VisionAnalysis,
        style: str | None = None,
        variation_seed: int = 0,
    ) -> bytes:
        """멀티 아이템(옷/하의/액세서리 조합) 피팅.

        기본 구현은 아이템별 순차 적용(체이닝) — 앞 아이템의 결과 위에 다음 아이템을
        입힌다. 한 번의 호출로 처리 가능한 프로바이더(OpenAI)는 오버라이드한다.
        """
        result = photo_bytes
        for garment in garments:
            result = await self.swap_garment(
                result, garment, analysis, style=style, variation_seed=variation_seed
            )
        return result
