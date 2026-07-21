"""결정적(deterministic) 목 임베딩.

- 텍스트: 토큰 단위 bag-of-words 해시 벡터의 합 → 정규화.
  토큰이 겹치는 텍스트끼리 실제로 코사인 유사도가 높아져, mock 모드에서도
  "화이트 셔츠" 사진 분석 ↔ "White Oxford Shirt" 상품이 상위 랭킹되는 식으로
  추천 플로우가 의미 있게 동작한다.
- 이미지: 바이트 해시 시드 벡터 (결정적).
"""
import hashlib
import math
import random
import re

from app.providers.base import EmbeddingProvider

DIM = 512


def _seeded_vector(seed: str) -> list[float]:
    rng = random.Random(int(hashlib.sha256(seed.encode()).hexdigest()[:16], 16))
    return [rng.gauss(0, 1) for _ in range(DIM)]


def _normalize(vec: list[float]) -> list[float]:
    norm = math.sqrt(sum(v * v for v in vec)) or 1.0
    return [v / norm for v in vec]


class MockEmbeddingProvider(EmbeddingProvider):
    async def embed_text(self, text: str) -> list[float]:
        tokens = re.findall(r"[\w가-힣]+", text.lower())
        if not tokens:
            return _normalize(_seeded_vector("empty"))
        acc = [0.0] * DIM
        for token in tokens:
            tv = _seeded_vector(f"token:{token}")
            acc = [a + b for a, b in zip(acc, tv)]
        return _normalize(acc)

    async def embed_image(self, image_bytes: bytes) -> list[float]:
        digest = hashlib.sha256(image_bytes).hexdigest()
        return _normalize(_seeded_vector(f"image:{digest}"))
