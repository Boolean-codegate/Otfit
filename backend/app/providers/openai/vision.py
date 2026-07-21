"""OpenAI 비전 프로바이더 (두뇌) — gpt-5.6-sol, Responses API + structured output.

분석·MVP 범위 판정·마스크 영역 지시·스타일 추론을 담당한다.
실제 픽셀 생성은 generation.py(gpt-image-1 edit, 손)가 담당 — Sol은 이미지 생성 불가.
"""
import base64
import io
import json

from openai import AsyncOpenAI
from PIL import Image

from app.core.config import get_settings
from app.providers.base import QualityReport, VisionAnalysis, VisionProvider

_ANALYSIS_SCHEMA = {
    "type": "object",
    "properties": {
        "person_count": {"type": "integer"},
        "pose": {"type": "string", "enum": ["front", "three_quarter", "side", "back"]},
        "garment_regions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "type": {"type": "string", "enum": ["top", "jacket", "shirt", "dress"]},
                    "bbox": {"type": "array", "items": {"type": "integer"}, "minItems": 4, "maxItems": 4},
                },
                "required": ["type", "bbox"],
                "additionalProperties": False,
            },
        },
        "occlusion_score": {"type": "number"},
        "background_tags": {"type": "array", "items": {"type": "string"}},
        "lighting": {
            "type": "object",
            "properties": {
                "brightness": {"type": "number"},
                "direction": {"type": "string"},
            },
            "required": ["brightness", "direction"],
            "additionalProperties": False,
        },
        "color_palette": {"type": "array", "items": {"type": "string"}},
        "style_suggestions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "label": {"type": "string"},
                    "style": {
                        "type": "string",
                        "enum": ["casual", "minimal", "street", "classic", "romantic", "formal"],
                    },
                },
                "required": ["label", "style"],
                "additionalProperties": False,
            },
        },
        "is_valid": {"type": "boolean"},
        "reject_reason": {
            "type": ["string", "null"],
            "enum": ["MULTIPLE_PERSONS", "HEAVY_OCCLUSION", "UNSUPPORTED_POSE", "LOW_RESOLUTION", None],
        },
    },
    "required": [
        "person_count", "pose", "garment_regions", "occlusion_score", "background_tags",
        "lighting", "color_palette", "style_suggestions", "is_valid", "reject_reason",
    ],
    "additionalProperties": False,
}

_ANALYSIS_PROMPT = """You are a fashion photo analyst for a garment-swap app (MVP scope below).
Analyze the photo and return JSON only.

MVP scope (mark is_valid=false with the matching reject_reason if violated):
- Exactly ONE person, upper-body/thigh-up shot → else MULTIPLE_PERSONS
- Pose must be front or three_quarter → else UNSUPPORTED_POSE
- The top garment (top/jacket/shirt/dress) must be clearly visible; occlusion_score is 0~1,
  above 0.4 means HEAVY_OCCLUSION

garment_regions: pixel bbox [x, y, w, h] for each replaceable garment (top/jacket/shirt/dress
only — never bottoms/shoes/accessories). These boxes will be used to build an inpainting mask,
so keep them tight around the garment and NEVER include the face or hair.
style_suggestions: 2-3 outfit style directions matching the photo's mood, Korean labels
(e.g. "청량한 휴양지룩"), each mapped to one style keyword.
"""

_QUALITY_SCHEMA = {
    "type": "object",
    "properties": {
        "quality_score": {"type": "number"},
        "identity_preserved": {"type": "boolean"},
        "issues": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["quality_score", "identity_preserved", "issues"],
    "additionalProperties": False,
}

_QUALITY_PROMPT = """First image = original photo, second image = AI garment-swap result.
Score the result (JSON only):
- quality_score 0~1: artifacts, broken hands/patterns, unnatural garment boundaries
- identity_preserved: is it clearly the SAME person? Face, hair, body shape and background
  must be unchanged; only the garment may differ. Be strict — any face change means false.
- issues: short list of detected problems
"""


def _data_url(image_bytes: bytes) -> str:
    return "data:image/jpeg;base64," + base64.b64encode(image_bytes).decode()


def _face_pixel_similarity(original: bytes, generated: bytes) -> float:
    """얼굴 영역(상단 35%) 픽셀 상관 기반 보조 지표.

    TODO: 얼굴 임베딩 모델(예: open_clip 얼굴 crop) 도입 전까지의 경량 안전장치.
    gpt-image-1 edit가 마스크 밖(얼굴)까지 재생성하는 사고를 이중으로 걸러낸다.
    """
    def face_gray(data: bytes) -> list[int]:
        with Image.open(io.BytesIO(data)) as im:
            face = im.convert("L").crop((0, 0, im.width, int(im.height * 0.35)))
            return list(face.resize((32, 32)).getdata())

    a, b = face_gray(original), face_gray(generated)
    mean_a, mean_b = sum(a) / len(a), sum(b) / len(b)
    cov = sum((x - mean_a) * (y - mean_b) for x, y in zip(a, b))
    var_a = sum((x - mean_a) ** 2 for x in a) ** 0.5
    var_b = sum((y - mean_b) ** 2 for y in b) ** 0.5
    if var_a == 0 or var_b == 0:
        return 0.0
    return max(0.0, cov / (var_a * var_b))


class OpenAIVisionProvider(VisionProvider):
    def __init__(self) -> None:
        settings = get_settings()
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY is required in live mode")
        self.client = AsyncOpenAI(api_key=settings.openai_api_key)
        self.model = settings.vision_model
        self.face_threshold = settings.face_similarity_threshold

    async def _structured(self, prompt: str, images: list[bytes], schema_name: str, schema: dict) -> dict:
        content: list[dict] = [{"type": "input_text", "text": prompt}]
        content += [{"type": "input_image", "image_url": _data_url(img)} for img in images]
        response = await self.client.responses.create(
            model=self.model,
            input=[{"role": "user", "content": content}],
            text={"format": {"type": "json_schema", "name": schema_name, "schema": schema, "strict": True}},
        )
        return json.loads(response.output_text)

    async def analyze(self, image_bytes: bytes) -> VisionAnalysis:
        data = await self._structured(_ANALYSIS_PROMPT, [image_bytes], "photo_analysis", _ANALYSIS_SCHEMA)
        suggestions = [
            {"id": f"st_{i + 1}", "label": s["label"], "style": s["style"]}
            for i, s in enumerate(data["style_suggestions"])
        ]
        return VisionAnalysis(
            person_count=data["person_count"],
            pose=data["pose"],
            garment_regions=data["garment_regions"],
            occlusion_score=data["occlusion_score"],
            background_tags=data["background_tags"],
            lighting=data["lighting"],
            color_palette=data["color_palette"],
            style_suggestions=suggestions,
            is_valid=data["is_valid"],
            reject_reason=data["reject_reason"],
        )

    async def assess_quality(self, original_bytes: bytes, generated_bytes: bytes) -> QualityReport:
        data = await self._structured(
            _QUALITY_PROMPT, [original_bytes, generated_bytes], "quality_report", _QUALITY_SCHEMA
        )
        face_similarity = _face_pixel_similarity(original_bytes, generated_bytes)
        identity = bool(data["identity_preserved"]) and face_similarity >= self.face_threshold
        issues = list(data["issues"])
        if face_similarity < self.face_threshold:
            issues.append(f"face_similarity={face_similarity:.2f} below threshold")
        return QualityReport(
            quality_score=float(data["quality_score"]),
            identity_preserved=identity,
            issues=issues,
        )
