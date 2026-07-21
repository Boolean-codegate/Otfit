"""OpenAI 생성 프로바이더 (손) — gpt-image-1 edit 인페인팅.

VisionProvider(Sol)가 지시한 garment_regions로 마스크를 만들어 의상 영역만 편집한다.
투명 = 편집 대상, 불투명 = 보존 (얼굴/헤어/배경은 반드시 보존 영역).
"""
import base64
import io

from openai import AsyncOpenAI
from PIL import Image

from app.core.config import get_settings
from app.providers.base import GarmentSpec, GenerationProvider, VisionAnalysis

# gpt-image-1이 지원하는 크기 (정사각/세로/가로)
_SIZES = {(1, 1): "1024x1024", (2, 3): "1024x1536", (3, 2): "1536x1024"}


def _pick_size(width: int, height: int) -> tuple[str, int, int]:
    ratio = width / height
    if ratio < 0.85:
        return "1024x1536", 1024, 1536
    if ratio > 1.15:
        return "1536x1024", 1536, 1024
    return "1024x1024", 1024, 1024


def _build_mask(analysis: VisionAnalysis, src_w: int, src_h: int, dst_w: int, dst_h: int) -> bytes:
    """의상 bbox만 투명(편집), 나머지 전부 불투명(보존)인 마스크 PNG.

    ⚠️ 정체성 보존 1차 안전장치: 마스크를 의상 영역으로 타이트하게 제한한다.
    """
    mask = Image.new("RGBA", (dst_w, dst_h), (0, 0, 0, 255))  # 불투명 = 보존
    scale_x, scale_y = dst_w / src_w, dst_h / src_h
    for region in analysis.garment_regions:
        bbox = region.get("bbox")
        if not bbox:
            continue
        x, y, w, h = bbox
        box = (
            int(x * scale_x),
            int(y * scale_y),
            int((x + w) * scale_x),
            int((y + h) * scale_y),
        )
        transparent = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), (0, 0, 0, 0))
        mask.paste(transparent, (box[0], box[1]))
    buf = io.BytesIO()
    mask.save(buf, format="PNG")
    return buf.getvalue()


def _build_prompt(garment: GarmentSpec, style: str | None) -> str:
    attrs = garment.attributes
    desc = ", ".join(
        f"{key}: {attrs[key]}" for key in ("color", "pattern", "length", "material") if attrs.get(key)
    )
    prompt = (
        f"Replace ONLY the garment in the masked area with this product: "
        f"{garment.brand} {garment.title} ({garment.category}; {desc}). "
        "Keep the person's face, hair, body shape, pose, and background completely unchanged. "
        "Photorealistic, natural garment drape and boundaries."
    )
    if style:
        prompt += f" Overall styling mood: {style}."
    return prompt


class OpenAIGenerationProvider(GenerationProvider):
    def __init__(self) -> None:
        settings = get_settings()
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY is required in live mode")
        self.client = AsyncOpenAI(api_key=settings.openai_api_key)
        self.model = settings.image_model

    async def swap_garment(
        self,
        photo_bytes: bytes,
        garment: GarmentSpec,
        analysis: VisionAnalysis,
        style: str | None = None,
        variation_seed: int = 0,
    ) -> bytes:
        with Image.open(io.BytesIO(photo_bytes)) as im:
            src_w, src_h = im.size
            size, dst_w, dst_h = _pick_size(src_w, src_h)
            resized = im.convert("RGBA").resize((dst_w, dst_h))
        photo_buf = io.BytesIO()
        resized.save(photo_buf, format="PNG")
        photo_buf.seek(0)
        photo_buf.name = "photo.png"

        mask_buf = io.BytesIO(_build_mask(analysis, src_w, src_h, dst_w, dst_h))
        mask_buf.name = "mask.png"

        prompt = _build_prompt(garment, style)
        if variation_seed:
            prompt += f" Variation {variation_seed}: slightly different fit and drape."

        response = await self.client.images.edit(
            model=self.model,
            image=photo_buf,
            mask=mask_buf,
            prompt=prompt,
            size=size,
        )
        return base64.b64decode(response.data[0].b64_json)
