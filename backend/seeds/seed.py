"""시드: 협력사 1 + 더미 상품 40개 + 실사진 상품 13개(임베딩 포함) + 테스트 유저.

실행: docker-compose exec api python -m seeds.seed
mock EmbeddingProvider가 결정적이므로 몇 번을 돌려도 같은 임베딩이 생성된다.

실사진 상품: seeds/assets/products/*.png 를 스토리지로 복사하고
/media/products/... URL로 서빙한다 (데모용 실제 상품 이미지).
"""
import asyncio
import shutil
import uuid
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import get_settings
from app.core.security import hash_password
from app.models import Consent, Partner, Product, User
from app.providers.mock.embedding import MockEmbeddingProvider

TEST_EMAIL = "test@otfit.app"
TEST_PASSWORD = "test1234"

# (title, brand, category, price, style, color, pattern, length, material)
PRODUCTS = [
    ("린넨 오버셔츠", "ACME", "shirt", 39000, "casual", "ivory", "solid", "regular", "linen"),
    ("화이트 옥스포드 셔츠", "ACME", "shirt", 45000, "classic", "white", "solid", "regular", "cotton"),
    ("스트라이프 코튼 셔츠", "ACME", "shirt", 42000, "casual", "blue", "stripe", "regular", "cotton"),
    ("데님 웨스턴 셔츠", "DENIMLAB", "shirt", 59000, "street", "indigo", "solid", "regular", "denim"),
    ("체크 플란넬 셔츠", "WOODSMAN", "shirt", 49000, "casual", "red", "check", "regular", "flannel"),
    ("실크 블라우스 셔츠", "MUSE", "shirt", 89000, "romantic", "cream", "solid", "regular", "silk"),
    ("블랙 포플린 셔츠", "MONO", "shirt", 47000, "minimal", "black", "solid", "regular", "cotton"),
    ("베이지 코듀로이 셔츠", "WOODSMAN", "shirt", 55000, "casual", "beige", "solid", "regular", "corduroy"),
    ("베이직 크루넥 티셔츠", "MONO", "top", 19000, "minimal", "white", "solid", "regular", "cotton"),
    ("그래픽 프린트 티", "STREETONE", "top", 29000, "street", "black", "graphic", "regular", "cotton"),
    ("니트 폴로 셔츠", "CLASSIQ", "top", 52000, "classic", "navy", "solid", "regular", "knit"),
    ("파스텔 후드 티", "STREETONE", "top", 45000, "street", "lavender", "solid", "regular", "fleece"),
    ("보트넥 스트라이프 톱", "MARINE", "top", 33000, "casual", "navy", "stripe", "regular", "cotton"),
    ("캐시미어 라운드 니트", "MUSE", "top", 98000, "minimal", "gray", "solid", "regular", "cashmere"),
    ("크롭 리브드 니트", "MUSE", "top", 41000, "romantic", "pink", "solid", "crop", "knit"),
    ("오버핏 스웨트셔츠", "STREETONE", "top", 39000, "street", "charcoal", "solid", "long", "cotton"),
    ("버튼 카디건 톱", "CLASSIQ", "top", 47000, "classic", "brown", "solid", "regular", "wool"),
    ("슬리브리스 새틴 톱", "MUSE", "top", 36000, "romantic", "champagne", "solid", "regular", "satin"),
    ("워셔블 니트 베스트", "MONO", "top", 35000, "minimal", "oatmeal", "solid", "regular", "knit"),
    ("샴브레이 헨리넥", "DENIMLAB", "top", 31000, "casual", "lightblue", "solid", "regular", "chambray"),
    ("싱글 브레스트 블레이저", "CLASSIQ", "jacket", 129000, "classic", "navy", "solid", "regular", "wool"),
    ("크롭 트위드 자켓", "MUSE", "jacket", 119000, "romantic", "pink", "tweed", "crop", "tweed"),
    ("워크웨어 초어 자켓", "WOODSMAN", "jacket", 89000, "street", "olive", "solid", "regular", "canvas"),
    ("데님 트러커 자켓", "DENIMLAB", "jacket", 79000, "casual", "indigo", "solid", "regular", "denim"),
    ("경량 봄버 자켓", "STREETONE", "jacket", 85000, "street", "black", "solid", "regular", "nylon"),
    ("린넨 셋업 자켓", "ACME", "jacket", 99000, "minimal", "beige", "solid", "regular", "linen"),
    ("체크 울 블레이저", "CLASSIQ", "jacket", 149000, "classic", "gray", "check", "regular", "wool"),
    ("코듀로이 셔킷", "WOODSMAN", "jacket", 69000, "casual", "camel", "solid", "regular", "corduroy"),
    ("레더 바이커 자켓", "STREETONE", "jacket", 189000, "street", "black", "solid", "crop", "leather"),
    ("화이트 데님 자켓", "DENIMLAB", "jacket", 82000, "minimal", "white", "solid", "regular", "denim"),
    ("플로럴 미디 원피스", "MUSE", "dress", 78000, "romantic", "coral", "floral", "midi", "chiffon"),
    ("린넨 셔츠 원피스", "ACME", "dress", 69000, "casual", "beige", "solid", "midi", "linen"),
    ("블랙 슬립 드레스", "MONO", "dress", 59000, "minimal", "black", "solid", "long", "satin"),
    ("트위드 미니 원피스", "CLASSIQ", "dress", 109000, "classic", "ivory", "tweed", "mini", "tweed"),
    ("데님 셔츠 원피스", "DENIMLAB", "dress", 75000, "casual", "lightblue", "solid", "midi", "denim"),
    ("퍼프 슬리브 원피스", "MUSE", "dress", 66000, "romantic", "white", "solid", "midi", "cotton"),
    ("니트 롱 원피스", "MONO", "dress", 88000, "minimal", "gray", "solid", "long", "knit"),
    ("스트라이프 맥시 원피스", "MARINE", "dress", 72000, "casual", "navy", "stripe", "long", "cotton"),
    ("새틴 랩 원피스", "MUSE", "dress", 95000, "romantic", "emerald", "solid", "midi", "satin"),
    ("테일러드 셔츠 드레스", "CLASSIQ", "dress", 99000, "classic", "khaki", "solid", "midi", "cotton"),
]

ASSETS_DIR = Path(__file__).parent / "assets" / "products"

# 실사진 상품 (filename, title, brand, category, price, style, color, pattern, length, material)
REAL_PRODUCTS = [
    ("r01.png", "네이비 스트라이프 반팔 니트 가디건", "OTFIT PARTNER", "top", 49000, "casual", "navy", "stripe", "regular", "knit"),
    ("r02.png", "윙 스터드 크롭 집업 후드", "OTFIT PARTNER", "jacket", 69000, "street", "black", "graphic", "crop", "fleece"),
    ("r03.png", "그레이 케이블 니트 가디건", "OTFIT PARTNER", "top", 59000, "classic", "gray", "solid", "regular", "wool"),
    ("r04.png", "오트밀 와플 헨리넥 롱슬리브", "OTFIT PARTNER", "top", 33000, "casual", "oatmeal", "solid", "regular", "cotton"),
    ("r05.png", "블랙 헨리넥 루즈핏 롱슬리브", "OTFIT PARTNER", "top", 35000, "street", "black", "solid", "long", "cotton"),
    ("r06.png", "버건디 롤업 슬리브 반팔 티", "OTFIT PARTNER", "top", 29000, "casual", "burgundy", "solid", "regular", "cotton"),
    ("r07.png", "에크루 스탠드칼라 스냅 풀오버 셔츠", "OTFIT PARTNER", "shirt", 55000, "casual", "ivory", "solid", "regular", "cotton"),
    ("r08.png", "네이비 케이블 반팔 니트 가디건", "OTFIT PARTNER", "top", 47000, "casual", "navy", "solid", "regular", "knit"),
    ("r09.png", "화이트 오프숄더 레터링 롱슬리브", "OTFIT PARTNER", "top", 31000, "romantic", "white", "graphic", "regular", "jersey"),
    ("r10.png", "차콜 레이어드 크롭 하프슬리브 톱", "OTFIT PARTNER", "top", 28000, "street", "charcoal", "solid", "crop", "jersey"),
    ("r11.png", "블루 버튼 브이넥 니트 톱", "OTFIT PARTNER", "top", 39000, "romantic", "blue", "solid", "regular", "knit"),
    ("r12.png", "네이비 스냅 헨리넥 반팔 티", "OTFIT PARTNER", "top", 27000, "casual", "navy", "solid", "regular", "cotton"),
    ("r13.png", "네이비 체크 오버 셔츠", "OTFIT PARTNER", "shirt", 52000, "casual", "navy", "check", "regular", "cotton"),
]


async def seed() -> None:
    settings = get_settings()
    engine = create_async_engine(settings.database_url)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    embedder = MockEmbeddingProvider()

    async with factory() as session:
        # 협력사
        partner = (await session.execute(select(Partner).where(Partner.name == "OTFIT 파트너몰"))).scalar_one_or_none()
        if partner is None:
            partner = Partner(
                name="OTFIT 파트너몰",
                catalog_source="https://cdn.partner-shop.example/catalog.json",
                commission_rate=0.1,
                contract_note="해커톤 데모용 더미 카탈로그 (계약 범위 내 이미지 사용)",
            )
            session.add(partner)
            await session.flush()

        # 상품 40개 (upsert by external_id)
        created = 0
        for index, (title, brand, category, price, style, color, pattern, length, material) in enumerate(PRODUCTS):
            external_id = f"SKU-{index + 1:04d}"
            exists = (
                await session.execute(
                    select(Product).where(Product.partner_id == partner.id, Product.external_id == external_id)
                )
            ).scalar_one_or_none()
            if exists:
                continue
            attributes = {
                "color": color, "pattern": pattern, "length": length,
                "material": material, "style": style,
            }
            text = f"{title} {brand} {category} {style} {color} {pattern} {length} {material}"
            product = Product(
                partner_id=partner.id,
                external_id=external_id,
                title=title,
                brand=brand,
                category=category,
                price=price,
                currency="KRW",
                stock_status="in_stock" if index % 13 else "low_stock",
                product_url=f"https://shop.partner-shop.example/products/{external_id}",
                image_url=f"https://cdn.partner-shop.example/products/{external_id}.jpg",
                text_embedding=await embedder.embed_text(text),
                image_embedding=await embedder.embed_text(f"image {text}"),
                attributes=attributes,
            )
            session.add(product)
            created += 1

        # 실사진 상품 13개: 이미지를 스토리지로 복사하고 /media URL로 서빙
        media_products_dir = Path(settings.storage_dir) / "products"
        media_products_dir.mkdir(parents=True, exist_ok=True)
        real_created = 0
        for index, (fname, title, brand, category, price, style, color, pattern, length, material) in enumerate(REAL_PRODUCTS):
            src = ASSETS_DIR / fname
            if src.exists():
                shutil.copyfile(src, media_products_dir / fname)
            image_url = f"{settings.base_url}/media/products/{fname}"
            external_id = f"SKU-R{index + 1:03d}"
            exists = (
                await session.execute(
                    select(Product).where(Product.partner_id == partner.id, Product.external_id == external_id)
                )
            ).scalar_one_or_none()
            if exists:
                exists.image_url = image_url  # base_url 변경 시 재시드로 갱신
                continue
            attributes = {
                "color": color, "pattern": pattern, "length": length,
                "material": material, "style": style,
            }
            text = f"{title} {brand} {category} {style} {color} {pattern} {length} {material}"
            session.add(Product(
                partner_id=partner.id,
                external_id=external_id,
                title=title,
                brand=brand,
                category=category,
                price=price,
                currency="KRW",
                stock_status="in_stock",
                product_url=f"https://shop.partner-shop.example/products/{external_id}",
                image_url=image_url,
                text_embedding=await embedder.embed_text(text),
                image_embedding=await embedder.embed_text(f"image {text}"),
                attributes=attributes,
            ))
            real_created += 1

        # 테스트 유저 (크레딧 100, 동의 완료)
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
            f"seed 완료: 더미 상품 {created}개 + 실사진 상품 {real_created}개 신규 생성 "
            f"(정의: 더미 {len(PRODUCTS)} / 실사진 {len(REAL_PRODUCTS)}), "
            f"테스트 유저 {TEST_EMAIL} / {TEST_PASSWORD}"
        )

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(seed())
