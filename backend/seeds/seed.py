"""시드: 실제 카탈로그(카테고리 폴더 기반) 상품 + 협력사 + 테스트 유저.

backend/seeds/catalog_images/{top|jacket|shirt|dress}/ 의 이미지 1장 = 상품 1개.
- 폴더명 = category (계약: top|jacket|shirt|dress 만 허용)
- CURATED에 파일명이 있으면 수작업 메타데이터 사용 (실사진 상품 r01~r13),
  없으면 파일명 힌트(색상/소재/패턴 토큰)로 데모용 생성
- image_url: R2_PUBLIC_URL 있으면 공개 URL, 없으면 R2 key만 저장
  (응답 시점에 presigned URL로 변환 — app/services/catalog.py)
  ※ Segmind garm_img가 공개 접근 URL을 요구하므로 /media 로컬 서빙은 쓰지 않는다.

선행: docker-compose exec api python -m scripts.upload_catalog  (R2 업로드)
실행: docker-compose exec api python -m seeds.seed
"""
import asyncio
import hashlib
import re
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import get_settings
from app.core.security import hash_password
from app.models import Consent, Partner, Product, User
from app.providers.mock.embedding import MockEmbeddingProvider

TEST_EMAIL = "test@otfit.app"
TEST_PASSWORD = "test1234"

CATEGORIES = ("top", "jacket", "shirt", "dress")
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}
IMAGES_DIR = Path(__file__).resolve().parent / "catalog_images"

CATEGORY_NOUN = {"top": "톱", "jacket": "재킷", "shirt": "셔츠", "dress": "원피스"}
BRANDS = ("ACME", "MUSE", "MONO", "CLASSIQ", "DENIMLAB", "STREETONE")
STYLES = ("casual", "minimal", "street", "classic", "romantic")
PRICE_RANGE = {  # (최소, 최대) 원
    "top": (19000, 59000),
    "shirt": (29000, 89000),
    "jacket": (59000, 189000),
    "dress": (49000, 129000),
}

# 실사진 상품 수작업 메타데이터 — filename: (title, brand, price, style, color, pattern, length, material)
# 카테고리는 폴더 위치가 결정한다 (r01~r13은 origin/main의 REAL_PRODUCTS에서 가져옴)
CURATED = {
    "r01.png": ("네이비 스트라이프 반팔 니트 가디건", "노드유", 49000, "casual", "navy", "stripe", "regular", "knit"),
    "r02.png": ("윙 스터드 크롭 집업 후드", "헬레네파리스", 69000, "street", "black", "graphic", "crop", "fleece"),
    "r03.png": ("그레이 케이블 니트 가디건", "노드유", 59000, "classic", "gray", "solid", "regular", "wool"),
    "r04.png": ("오트밀 와플 헨리넥 롱슬리브", "언더오프", 33000, "casual", "oatmeal", "solid", "regular", "cotton"),
    "r05.png": ("블랙 헨리넥 루즈핏 롱슬리브", "러기드하우스", 35000, "street", "black", "solid", "long", "cotton"),
    "r06.png": ("버건디 롤업 슬리브 반팔 티", "키뮤어", 29000, "casual", "burgundy", "solid", "regular", "cotton"),
    "r07.png": ("에크루 스탠드칼라 스냅 풀오버 셔츠", "러기드하우스", 55000, "casual", "ivory", "solid", "regular", "cotton"),
    "r08.png": ("네이비 케이블 반팔 니트 가디건", "효지", 47000, "casual", "navy", "solid", "regular", "knit"),
    "r09.png": ("화이트 오프숄더 레터링 롱슬리브", "오드민", 31000, "romantic", "white", "graphic", "regular", "jersey"),
    "r10.png": ("차콜 레이어드 크롭 하프슬리브 톱", "헬레네파리스", 28000, "street", "charcoal", "solid", "crop", "jersey"),
    "r11.png": ("블루 버튼 브이넥 니트 톱", "미쏘", 39000, "romantic", "blue", "solid", "regular", "knit"),
    "r12.png": ("네이비 스냅 헨리넥 반팔 티", "브렌슨", 27000, "casual", "navy", "solid", "regular", "cotton"),
    "r13.png": ("네이비 체크 오버 셔츠", "유니온블루", 52000, "casual", "navy", "check", "regular", "cotton"),
    # 폴더 스캔 이미지 중 파일명 힌트만으로는 실물과 안 맞는 것들 (이미지 확인 후 수기 등록)
    "floral_dress.jpg": ("레드 플레어 롱 원피스", "MUSE", 89000, "romantic", "red", "solid", "long", "chiffon"),
    "top_1.png": ("버건디 라운드넥 반팔 티", "MONO", 29000, "casual", "burgundy", "solid", "regular", "cotton"),
    "top_2.png": ("차콜 립 반팔 티", "MONO", 27000, "minimal", "charcoal", "solid", "regular", "cotton"),
    "dress_1.png": ("화이트 플리츠 버클 미니 원피스", "CLASSIQ", 79000, "minimal", "white", "solid", "mini", "cotton"),
    "knit_sweater.jpg": ("크림 프린지 니트 판초", "MUSE", 55000, "romantic", "cream", "solid", "regular", "knit"),
}


# 실사진 상품 → 실제 무신사 상품 페이지 ('옷 링크 매칭' 기준, 구매하러 가기 연결)
MUSINSA_URLS = {
    "r01.png": "https://www.musinsa.com/products/5054252",  # 노드유 (가디건 반팔)
    "r02.png": "https://www.musinsa.com/products/5313081",  # 헬레네파리스 엔젤 레터링 후드 집업
    "r03.png": "https://www.musinsa.com/products/5406016",  # 노드유 (가디건 그레이)
    "r04.png": "https://www.musinsa.com/products/5996770",  # 언더오프
    "r05.png": "https://www.musinsa.com/products/6099654",  # 러기드하우스 차이나 헨리넥
    "r06.png": "https://www.musinsa.com/products/6154816",  # 키뮤어
    "r07.png": "https://www.musinsa.com/products/6182780",  # 러기드하우스 벗나우 풀오버
    "r08.png": "https://www.musinsa.com/products/6326050",  # 효지
    "r09.png": "https://www.musinsa.com/products/6449577",  # 오드민
    "r10.png": "https://www.musinsa.com/products/6458359",  # 헬레네파리스
    "r11.png": "https://www.musinsa.com/products/6517564",  # 미쏘
    "r12.png": "https://www.musinsa.com/products/6575824",  # 브렌슨 컴포트 배색 롤업
    "r13.png": "https://www.musinsa.com/products/6652860",  # 유니온블루
}

# 파일명 힌트 사전 (영문 토큰 → 한글)
COLORS = {
    "white": "화이트", "black": "블랙", "ivory": "아이보리", "navy": "네이비",
    "blue": "블루", "beige": "베이지", "gray": "그레이", "grey": "그레이",
    "pink": "핑크", "red": "레드", "green": "그린", "brown": "브라운",
    "cream": "크림", "khaki": "카키", "olive": "올리브", "camel": "카멜",
}
MATERIALS = {
    "linen": "린넨", "cotton": "코튼", "denim": "데님", "wool": "울",
    "knit": "니트", "silk": "실크", "satin": "새틴", "tweed": "트위드",
    "leather": "레더", "corduroy": "코듀로이", "flannel": "플란넬",
}
PATTERNS = {
    "stripe": "스트라이프", "check": "체크", "floral": "플로럴",
    "graphic": "그래픽", "dot": "도트",
}


def _tokens(stem: str) -> list[str]:
    return re.split(r"[\s_\-.]+", stem.lower())


def _pick(mapping: dict, tokens: list[str]) -> tuple[str | None, str | None]:
    for token in tokens:
        if token in mapping:
            return token, mapping[token]
    return None, None


def build_product_fields(category: str, filename: str) -> dict:
    """CURATED 우선, 없으면 파일명 힌트 + 결정적 해시로 데모 상품 메타 생성."""
    curated = CURATED.get(filename)
    if curated:
        title, brand, price, style, color, pattern, length, material = curated
        return {
            "title": title,
            "brand": brand,
            "price": price,
            "attributes": {
                "color": color, "pattern": pattern, "length": length,
                "material": material, "style": style,
                "source": "무신사",  # 이미지 출처 (데모 시연용, 출처 표기 원칙)
            },
        }

    stem = Path(filename).stem
    digest = int(hashlib.sha256(f"{category}/{filename}".encode()).hexdigest()[:8], 16)
    tokens = _tokens(stem)

    color_en, color_ko = _pick(COLORS, tokens)
    material_en, material_ko = _pick(MATERIALS, tokens)
    pattern_en, pattern_ko = _pick(PATTERNS, tokens)
    color_en = color_en or list(COLORS)[digest % len(COLORS)]
    color_ko = color_ko or COLORS[color_en]
    material_en = material_en or list(MATERIALS)[digest % len(MATERIALS)]
    material_ko = material_ko or MATERIALS[material_en]

    title_parts = [color_ko]
    if pattern_ko:
        title_parts.append(pattern_ko)
    title_parts += [material_ko, CATEGORY_NOUN[category]]

    low, high = PRICE_RANGE[category]
    price = low + (digest % ((high - low) // 1000)) * 1000

    return {
        "title": " ".join(title_parts),
        "brand": BRANDS[digest % len(BRANDS)],
        "price": price,
        "attributes": {
            "color": color_en,
            "pattern": pattern_en or "solid",
            "length": "midi" if category == "dress" else "regular",
            "material": material_en,
            "style": STYLES[digest % len(STYLES)],
        },
    }


def scan_catalog() -> list[tuple[str, str]]:
    """[(category, filename)] — 카테고리 폴더의 이미지 목록."""
    items: list[tuple[str, str]] = []
    for category in CATEGORIES:
        folder = IMAGES_DIR / category
        if not folder.is_dir():
            continue
        for path in sorted(folder.iterdir()):
            if path.suffix.lower() in IMAGE_SUFFIXES:
                items.append((category, path.name))
    return items


async def seed() -> None:
    settings = get_settings()
    engine = create_async_engine(settings.database_url)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    embedder = MockEmbeddingProvider()

    catalog = scan_catalog()
    if not catalog:
        print(f"⚠ 카탈로그 이미지가 없습니다: {IMAGES_DIR}/{{top,jacket,shirt,dress}}/")
        return

    async with factory() as session:
        # 협력사
        partner = (
            await session.execute(select(Partner).where(Partner.name == "OTFIT 파트너몰"))
        ).scalar_one_or_none()
        if partner is None:
            partner = Partner(
                name="OTFIT 파트너몰",
                catalog_source="seeds/catalog_images (R2: catalog/)",
                commission_rate=0.1,
                contract_note="데모 카탈로그 — 계약 범위 내 이미지 사용",
            )
            session.add(partner)
            await session.flush()

        # 구 더미 시드(SKU-%) 제거 — placeholder image_url이라 브라우저/Segmind 모두 실패
        removed = await session.execute(
            delete(Product).where(Product.external_id.like("SKU-%"))
        )

        created = updated = 0
        for category, filename in catalog:
            external_id = f"{category}/{filename}"
            key = f"catalog/{external_id}"
            image_url = (
                f"{settings.r2_public_url.rstrip('/')}/{key}"
                if settings.r2_public_url
                else key  # 응답 시점 presigned 변환
            )
            fields = build_product_fields(category, filename)
            # 실사진 상품은 매칭된 무신사 상품 페이지로, 스톡 이미지 상품은
            # 동일 상품이 존재하지 않으므로 상품명 무신사 검색 결과로 연결 (죽은 링크 방지)
            product_url = MUSINSA_URLS.get(
                filename,
                f"https://www.musinsa.com/search/goods?keyword={quote(fields['title'])}",
            )
            text = (
                f"{fields['title']} {fields['brand']} {category} "
                + " ".join(str(v) for v in fields["attributes"].values())
            )
            embedding = await embedder.embed_text(text)

            product = (
                await session.execute(
                    select(Product).where(
                        Product.partner_id == partner.id, Product.external_id == external_id
                    )
                )
            ).scalar_one_or_none()
            if product is None:
                product = Product(
                    partner_id=partner.id,
                    external_id=external_id,
                    category=category,
                    currency="KRW",
                    stock_status="in_stock",
                    product_url=product_url,
                    **fields,
                    image_url=image_url,
                    text_embedding=embedding,
                    image_embedding=embedding,
                )
                session.add(product)
                created += 1
            else:
                product.title = fields["title"]
                product.brand = fields["brand"]
                product.price = fields["price"]
                product.attributes = fields["attributes"]
                product.product_url = product_url
                product.image_url = image_url
                product.text_embedding = embedding
                updated += 1

        # 테스트 유저
        user = (await session.execute(select(User).where(User.email == TEST_EMAIL))).scalar_one_or_none()
        if user is None:
            user = User(
                email=TEST_EMAIL,
                hashed_password=hash_password(TEST_PASSWORD),
                nickname="테스트",
                credit_balance=100,
            )
            session.add(user)
            await session.flush()
            for consent_type in ("image_processing", "marketing"):
                session.add(
                    Consent(
                        user_id=user.id, type=consent_type, granted=True,
                        granted_at=datetime.now(timezone.utc),
                    )
                )

        await session.commit()
        print(
            f"seed 완료: 카탈로그 {len(catalog)}개 (신규 {created}, 갱신 {updated}, "
            f"수작업 메타 {sum(1 for _, f in catalog if f in CURATED)}개), "
            f"구 더미 삭제 {removed.rowcount}건, 테스트 유저 {TEST_EMAIL} / {TEST_PASSWORD}"
        )

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(seed())
