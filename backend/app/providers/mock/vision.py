"""목 비전 분석. 이미지 해시 기반으로 결정적 결과를 만든다.

MVP 데모 시나리오: 정상 업로드는 항상 1인/정면(또는 반측면)/낮은 가림으로 분석되어
플로우가 끝까지 진행된다. (해상도 등 하드 검증은 서비스 계층에서 수행)
"""
import hashlib
import io

from PIL import Image

from app.providers.base import QualityReport, VisionAnalysis, VisionProvider

_POSES = ("front", "front", "front", "three_quarter")
_BACKGROUNDS = (
    ["cafe", "indoor", "warm"],
    ["street", "outdoor", "daylight"],
    ["studio", "plain", "neutral"],
    ["beach", "outdoor", "daylight"],
)
_PALETTES = (
    ["#f2e8d5", "#8a6d4b", "#2e2a26", "white", "beige"],
    ["#dde5ed", "#3a6ea5", "#1f2933", "blue", "navy"],
    ["#efefef", "#b0b0b0", "#333333", "gray", "black"],
    ["#f3d9d1", "#c96f5e", "#4b2e2a", "coral", "brown"],
)
_LIGHTINGS = (
    {"brightness": 0.7, "direction": "front"},
    {"brightness": 0.8, "direction": "left"},
    {"brightness": 0.5, "direction": "top"},
)
# label ↔ 상품 attributes.style 매핑 (style은 내부 매칭용, API에는 id/label만 노출)
_STYLE_SETS = (
    [
        {"label": "청량한 휴양지룩", "style": "casual"},
        {"label": "미니멀 데이트룩", "style": "minimal"},
        {"label": "클래식 오피스룩", "style": "classic"},
    ],
    [
        {"label": "스트릿 무드", "style": "street"},
        {"label": "포근한 데일리룩", "style": "casual"},
        {"label": "로맨틱 브런치룩", "style": "romantic"},
    ],
    [
        {"label": "모던 미니멀", "style": "minimal"},
        {"label": "빈티지 클래식", "style": "classic"},
        {"label": "캐주얼 위켄드", "style": "casual"},
    ],
)


class MockVisionProvider(VisionProvider):
    async def analyze(self, image_bytes: bytes) -> VisionAnalysis:
        digest = int(hashlib.sha256(image_bytes).hexdigest()[:8], 16)
        with Image.open(io.BytesIO(image_bytes)) as im:
            width, height = im.size

        # 상반신 사진 전제: 상체 영역을 상의 bbox로 가정
        bbox = [
            round(width * 0.2),
            round(height * 0.3),
            round(width * 0.6),
            round(height * 0.45),
        ]
        styles = _STYLE_SETS[digest % len(_STYLE_SETS)]
        return VisionAnalysis(
            person_count=1,
            pose=_POSES[digest % len(_POSES)],
            garment_regions=[{"type": "top", "bbox": bbox}],
            occlusion_score=round((digest % 20) / 100, 2),  # 0.00 ~ 0.19
            background_tags=list(_BACKGROUNDS[digest % len(_BACKGROUNDS)]),
            lighting=dict(_LIGHTINGS[digest % len(_LIGHTINGS)]),
            color_palette=list(_PALETTES[digest % len(_PALETTES)]),
            style_suggestions=[
                {"id": f"st_{i + 1}", "label": s["label"], "style": s["style"]}
                for i, s in enumerate(styles)
            ],
            is_valid=True,
            reject_reason=None,
        )

    async def assess_quality(self, original_bytes: bytes, generated_bytes: bytes) -> QualityReport:
        digest = int(hashlib.sha256(generated_bytes).hexdigest()[:8], 16)
        # 0.70 ~ 0.99: 데모에서 임계값(0.6) 아래로 떨어지지 않게 하되 코드 경로는 유지
        score = round(0.70 + (digest % 30) / 100, 2)
        return QualityReport(quality_score=score, identity_preserved=True, issues=[])
