"""Segmind IDM-VTON live 프로바이더 실호출 검증.

실행: docker-compose exec api python -m scripts.test_segmind
필요 env: SEGMIND_API_KEY + S3_*(R2)  — 사용자 사진 presigned URL 경로까지 실제로 검증한다.

1) 샘플 인물 사진 다운로드 → R2 업로드 → presigned URL 생성
2) Segmind IDM-VTON 호출 (샘플 상품 옷 이미지 URL)
3) 결과 바이너리를 StorageService에 저장 + PIL로 유효성 확인
"""
import asyncio
import io
import time

import httpx
from PIL import Image

from app.providers.base import GarmentSpec, VisionAnalysis
from app.providers.segmind.generation import SegmindGenerationProvider
from app.storage.base import get_storage

HUMAN_SAMPLE_URL = "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=768&q=80&fm=jpg"
GARMENT_SAMPLE_URL = "https://images.unsplash.com/photo-1576566588028-4147f3842f27?w=768&q=80&fm=jpg"


async def main() -> None:
    provider = SegmindGenerationProvider()
    storage = get_storage()

    print("1) 샘플 인물 사진 다운로드...")
    async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
        human_bytes = (await client.get(HUMAN_SAMPLE_URL)).content
    print(f"   {len(human_bytes):,} bytes")

    print("2) R2 업로드 + presigned URL 생성...")
    human_url = await provider._publish_human_image(human_bytes)
    print(f"   {human_url.split('?')[0]} (presigned, 1h)")

    garment = GarmentSpec(
        product_id="sample",
        title="화이트 코튼 티셔츠",
        brand="SAMPLE",
        category="top",
        attributes={"color": "white", "pattern": "solid", "material": "cotton"},
        image_url=GARMENT_SAMPLE_URL,
    )
    print(f"3) IDM-VTON 호출 (category=upper_body, des='white solid cotton 화이트 코튼 티셔츠')...")
    started = time.monotonic()
    result_bytes = await provider.generate_from_urls(
        human_url=human_url,
        garment_url=garment.image_url,
        category="upper_body",
        description="white solid cotton t-shirt",
        seed=42,
    )
    elapsed = time.monotonic() - started
    print(f"   응답 {len(result_bytes):,} bytes, {elapsed:.1f}s")

    print("4) 저장 + 유효성 검사...")
    with Image.open(io.BytesIO(result_bytes)) as im:
        print(f"   이미지 OK: {im.format} {im.width}x{im.height}")
    key = "results/segmind_smoke_test.jpg"
    storage.save(key, result_bytes)
    print(f"   저장 완료: {key} → {storage.url_for(key)}")
    print("\n✔ Segmind IDM-VTON live 경로 검증 성공")


if __name__ == "__main__":
    asyncio.run(main())
