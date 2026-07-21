import io
import uuid

from PIL import Image, ImageDraw
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError
from app.repositories.users import UserRepository
from app.services.generations import GenerationService
from app.storage.base import get_storage

STANDARD_MAX_SIDE = 1080


def _parse_ratio(ratio: str) -> tuple[int, int]:
    try:
        w, h = ratio.split(":")
        w, h = int(w), int(h)
        if w <= 0 or h <= 0:
            raise ValueError
        return w, h
    except ValueError:
        raise AppError(f"ratio 형식이 올바르지 않습니다: {ratio} (예: 4:5)", code="VALIDATION_ERROR", status_code=422)


def _center_crop(image: Image.Image, ratio_w: int, ratio_h: int) -> Image.Image:
    width, height = image.size
    target = ratio_w / ratio_h
    if width / height > target:
        new_w = int(height * target)
        left = (width - new_w) // 2
        return image.crop((left, 0, left + new_w, height))
    new_h = int(width / target)
    top = (height - new_h) // 2
    return image.crop((0, top, width, top + new_h))


def _watermark(image: Image.Image) -> Image.Image:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.text((image.width - 90, image.height - 34), "OTFIT", fill=(255, 255, 255, 160))
    return Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")


class ExportService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.storage = get_storage()
        self.settings = get_settings()

    async def export(
        self,
        user_id: uuid.UUID,
        result_id: uuid.UUID,
        ratio: str | None,
        hi_res: bool,
        remove_watermark: bool,
    ) -> dict:
        """계약 §7: 유료/프리미엄이 아니면 hi_res 무시 + 워터마크 포함으로 반환."""
        result = await GenerationService(self.session).get_owned_result(user_id, result_id)
        user = await UserRepository(self.session).get(user_id)

        data = self.storage.load(result.result_storage_key)
        with Image.open(io.BytesIO(data)) as im:
            image = im.convert("RGB")

        if ratio:
            image = _center_crop(image, *_parse_ratio(ratio))

        allow_hi_res = hi_res and user.is_premium
        if not allow_hi_res and max(image.size) > STANDARD_MAX_SIDE:
            scale = STANDARD_MAX_SIDE / max(image.size)
            image = image.resize((int(image.width * scale), int(image.height * scale)))

        watermark = not (user.is_premium and remove_watermark)
        if watermark:
            image = _watermark(image)

        buf = io.BytesIO()
        image.save(buf, format="JPEG", quality=95 if allow_hi_res else 88)
        safe_ratio = (ratio or "orig").replace(":", "x")
        key = f"exports/{user_id}/{result_id}_{safe_ratio}_{'hi' if allow_hi_res else 'std'}.jpg"
        self.storage.save(key, buf.getvalue())

        # attachment URL — 브라우저가 바로 저장 (모바일=갤러리/다운로드, PC=다운로드 폴더)
        filename = f"OTFIT_{str(result_id)[:8]}.jpg"
        return {"export_url": self.storage.download_url(key, filename), "watermark": watermark}
