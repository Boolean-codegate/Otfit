"""사용자 사진을 외부 AI 서비스가 가져갈 수 있는 공개(presigned) URL로 게시.

Segmind(human_img)·OpenAI(input_image) 생성 경로가 공용으로 사용한다.
해시 키(vton-inputs/{sha256}.jpg)로 중복 업로드를 방지한다.
"""
import asyncio
import hashlib
import io

from PIL import Image

from app.storage.base import S3Storage, build_s3_storage, get_storage

_INPUT_URL_TTL_SECONDS = 3600


def _input_storage() -> S3Storage:
    storage = get_storage()
    return storage if isinstance(storage, S3Storage) else build_s3_storage()


def _to_jpeg(photo_bytes: bytes) -> bytes:
    """생성 API들이 못 받는 포맷(BMP 등) 대비 JPEG로 통일해 게시한다."""
    with Image.open(io.BytesIO(photo_bytes)) as im:
        if (im.format or "").upper() == "JPEG":
            return photo_bytes
        buf = io.BytesIO()
        im.convert("RGB").save(buf, format="JPEG", quality=92)
        return buf.getvalue()


async def publish_photo_url(photo_bytes: bytes, ttl_seconds: int = _INPUT_URL_TTL_SECONDS) -> str:
    jpeg_bytes = await asyncio.to_thread(_to_jpeg, photo_bytes)
    storage = _input_storage()
    digest = hashlib.sha256(jpeg_bytes).hexdigest()[:32]
    key = f"vton-inputs/{digest}.jpg"
    if not await asyncio.to_thread(storage.exists, key):
        await asyncio.to_thread(storage.save, key, jpeg_bytes)
    return storage.presigned_url(key, ttl_seconds)
