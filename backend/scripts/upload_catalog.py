"""카탈로그 이미지 R2 업로드 유틸.

backend/seeds/catalog_images/{top|jacket|shirt|dress}/* 이미지를
R2 `catalog/{category}/{filename}` 키로 업로드한다 (이미 있으면 스킵).

- S3_PUBLIC_BASE_URL(r2.dev 등)이 설정돼 있으면 → 공개 URL 방식
- 없으면 → DB에는 key만 저장되고 응답 시점에 presigned URL 생성 (app/services/catalog.py)

Flutter 웹(CanvasKit)은 이미지를 fetch로 가져오므로 버킷에 CORS(GET 허용)도 설정한다.

실행: docker-compose exec api python -m scripts.upload_catalog
"""
from pathlib import Path

from app.core.config import get_settings
from app.storage.base import build_s3_storage

CATEGORIES = ("top", "jacket", "shirt", "dress", "pants", "accessory", "shoes")
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}
IMAGES_DIR = Path(__file__).resolve().parent.parent / "seeds" / "catalog_images"


def ensure_cors(storage) -> None:
    """브라우저(Flutter 웹 CanvasKit fetch)에서 이미지 로딩 가능하도록 GET CORS 허용."""
    try:
        storage.client.put_bucket_cors(
            Bucket=storage.bucket,
            CORSConfiguration={
                "CORSRules": [
                    {
                        "AllowedOrigins": ["*"],
                        "AllowedMethods": ["GET", "HEAD"],
                        "AllowedHeaders": ["*"],
                        "MaxAgeSeconds": 3600,
                    }
                ]
            },
        )
        print("R2 CORS 설정 완료 (GET/HEAD, 모든 origin)")
    except Exception as exc:  # noqa: BLE001 — CORS 실패는 업로드를 막지 않음
        print(f"⚠ CORS 설정 실패 (수동 설정 필요할 수 있음): {exc}")


def main() -> None:
    storage = build_s3_storage()
    ensure_cors(storage)

    uploaded = skipped = 0
    for category in CATEGORIES:
        folder = IMAGES_DIR / category
        if not folder.is_dir():
            continue
        for path in sorted(folder.iterdir()):
            if path.suffix.lower() not in IMAGE_SUFFIXES:
                continue
            key = f"catalog/{category}/{path.name}"
            if storage.exists(key):
                skipped += 1
                continue
            storage.save(key, path.read_bytes())
            uploaded += 1
            print(f"  ↑ {key}")

    settings = get_settings()
    mode = "공개 URL(R2_PUBLIC_URL)" if settings.r2_public_url else "presigned(응답 시점 서명)"
    print(f"\n업로드 {uploaded}건, 스킵(기존) {skipped}건 — 이미지 서빙 방식: {mode}")
    if uploaded + skipped == 0:
        print(f"⚠ 이미지가 없습니다: {IMAGES_DIR}/{{top,jacket,shirt,dress}}/ 에 넣어주세요.")


if __name__ == "__main__":
    main()
