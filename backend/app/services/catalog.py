"""상품 이미지 URL 해석.

products.image_url 컬럼은 두 형태를 허용한다:
- http(s) 전체 URL → 그대로 사용 (공개 CDN/R2 public dev URL)
- R2 object key (예: "catalog/shirt_01.jpg") → 응답 시점에 presigned URL 생성
  (만료되는 URL을 DB에 저장하지 않기 위함. S3_PUBLIC_BASE_URL이 설정되면 공개 URL 사용)

boto3의 generate_presigned_url은 네트워크 호출 없는 로컬 서명이라 응답 경로에서
호출해도 부담이 없다.
"""
from functools import lru_cache

from app.core.config import get_settings
from app.storage.base import S3Storage, build_s3_storage

CATALOG_PREFIX = "catalog/"
_PRESIGN_TTL_SECONDS = 86400  # 24h — 응답마다 새로 서명하므로 만료 걱정 없음


@lru_cache
def _catalog_storage() -> S3Storage:
    return build_s3_storage()


def resolve_product_image_url(value: str) -> str:
    """DB의 image_url 값(전체 URL 또는 R2 key) → 브라우저/Segmind이 접근 가능한 URL."""
    if not value or value.startswith("http://") or value.startswith("https://"):
        return value
    settings = get_settings()
    if settings.s3_public_base_url:
        return f"{settings.s3_public_base_url.rstrip('/')}/{value}"
    return _catalog_storage().presigned_url(value, _PRESIGN_TTL_SECONDS)
