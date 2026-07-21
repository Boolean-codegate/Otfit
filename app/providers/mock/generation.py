"""목 의상 교체 생성.

원본 사진 위 의상 영역에 상품별 결정적 색상 오버레이 + 상품명 라벨을 그려서
"어떤 상품이 어느 영역에 적용됐는지" 눈으로 확인 가능한 결과 이미지를 만든다.
얼굴/배경 영역은 그대로 두어 '인물성·배경 보존' 계약을 흉내낸다.
"""
import hashlib
import io

from PIL import Image, ImageDraw

from app.providers.base import GarmentSpec, GenerationProvider, VisionAnalysis


def _product_color(product_id: str, style: str | None, variation_seed: int) -> tuple[int, int, int]:
    digest = hashlib.sha256(f"{product_id}:{style}:{variation_seed}".encode()).digest()
    return (digest[0], digest[1], digest[2])


def _top_bbox(analysis: VisionAnalysis, width: int, height: int) -> list[int]:
    for region in analysis.garment_regions:
        if region.get("type") == "top" and region.get("bbox"):
            return region["bbox"]
    return [width // 4, height // 3, width // 2, height // 2]


class MockGenerationProvider(GenerationProvider):
    async def swap_garment(
        self,
        photo_bytes: bytes,
        garment: GarmentSpec,
        analysis: VisionAnalysis,
        style: str | None = None,
        variation_seed: int = 0,
    ) -> bytes:
        with Image.open(io.BytesIO(photo_bytes)) as im:
            image = im.convert("RGB")

        overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(overlay)

        x, y, w, h = _top_bbox(analysis, image.width, image.height)
        box = (x, y, x + w, y + h)
        color = _product_color(garment.product_id, style, variation_seed)
        draw.rectangle(box, fill=color + (140,), outline=color + (255,), width=3)

        label = f"{garment.brand} {garment.title}"[:40]
        if style:
            label += f" ({style})"
        draw.text((box[0] + 8, box[1] + 8), label, fill=(255, 255, 255, 255))

        composed = Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")
        buf = io.BytesIO()
        composed.save(buf, format="JPEG", quality=92)
        return buf.getvalue()
