"""SNS 데모 게시물 시드 — 홈 피드가 비어 보이지 않게 채운다.

선행: python -m seeds.seed (상품 카탈로그)
실행: docker-compose exec api python -m seeds.seed_posts

데모 유저 3명 + 게시물 8개(카탈로그 상품 태그) + 투표 분포를 만든다.
after_url은 태그 상품 이미지를 사용(실서비스에서는 사용자의 생성 결과).
멱등: 데모 유저 이메일 기준으로 이미 게시물이 있으면 건너뛴다.
"""
import asyncio

from app.core.config import get_settings
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.security import hash_password
from app.models import Post, Product, User

DEMO_USERS = [
    ("mina@otfit.app", "미나"),
    ("juno@otfit.app", "주노"),
    ("sol@otfit.app", "솔"),
]
PASSWORD = "demo1234"

# (작성자 인덱스, 캡션, buy/skip 초기 분포)
POSTS = [
    (0, "여름 바다 갈 때 이거 어때요? 🌊", 14, 3),
    (1, "면접 끝나고 데이트… 과한가요?", 9, 6),
    (2, "이 니트 색 나한테 어울리는지 봐주세요 🙏", 21, 2),
    (0, "스트릿으로 갈아탈까 고민 중", 7, 8),
    (1, "휴양지 룩 최종 후보. 살까 말까?", 17, 4),
    (2, "출근룩인데 너무 튀나요?", 5, 11),
    (0, "오늘 보정해본 것 중 제일 마음에 듦", 12, 1),
    (1, "체크 셔츠 유행 다시 온 거 맞죠?", 8, 5),
]


async def seed_posts() -> None:
    engine = create_async_engine(get_settings().database_url)
    factory = async_sessionmaker(engine, expire_on_commit=False)

    async with factory() as session:
        # 실사진 상품(r01~r13) 우선 태그 — 구/신 시드 external_id 모두 대응
        real_first = or_(Product.external_id.like("SKU-R%"), Product.external_id.like("%/r%.png"))
        products = list(
            (await session.execute(
                select(Product)
                .order_by((~real_first).asc(), Product.created_at)
                .limit(len(POSTS))
            )).scalars()
        )
        if not products:
            print("⚠ 상품이 없습니다. 먼저 python -m seeds.seed 를 실행하세요.")
            return

        users: list[User] = []
        for email, nickname in DEMO_USERS:
            user = (await session.execute(select(User).where(User.email == email))).scalar_one_or_none()
            if user is None:
                user = User(
                    email=email, hashed_password=hash_password(PASSWORD),
                    nickname=nickname, credit_balance=30,
                )
                session.add(user)
                await session.flush()
            users.append(user)

        existing = (
            await session.execute(select(Post).where(Post.user_id == users[0].id))
        ).scalars().first()
        if existing:
            print("데모 게시물이 이미 있습니다 — 건너뜀")
            return

        created = 0
        for index, (author_idx, caption, buy, skip) in enumerate(POSTS):
            product = products[index % len(products)]
            session.add(Post(
                user_id=users[author_idx].id,
                product_id=product.id,
                caption=caption,
                before_url=None,
                after_url=product.image_url,  # 데모: 상품컷. 실서비스는 생성 결과 이미지
                buy_votes=buy,
                skip_votes=skip,
            ))
            created += 1

        await session.commit()
        print(f"SNS 시드 완료: 데모 유저 {len(users)}명, 게시물 {created}개")


if __name__ == "__main__":
    asyncio.run(seed_posts())
