from fastapi import APIRouter

from app.core.deps import CurrentUser, DbSession
from app.schemas.credit import CreditBalanceResponse, CreditPurchaseRequest, CreditPurchaseResponse
from app.services.credits import CreditService

router = APIRouter(tags=["credits"])


@router.get("/credits", response_model=CreditBalanceResponse)
async def get_balance(user: CurrentUser, session: DbSession):
    return {"balance": await CreditService(session).balance(user.id)}


@router.post("/credits/purchase", response_model=CreditPurchaseResponse)
async def purchase(body: CreditPurchaseRequest, user: CurrentUser, session: DbSession):
    balance, transaction_id = await CreditService(session).purchase(user.id, body.amount)
    return {"balance": balance, "transaction_id": transaction_id}
