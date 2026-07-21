from pydantic import BaseModel, Field


class CreditBalanceResponse(BaseModel):
    balance: int


class CreditPurchaseRequest(BaseModel):
    amount: int = Field(gt=0, le=10000)  # 충전할 크레딧 수 (결제는 목)


class CreditPurchaseResponse(BaseModel):
    balance: int
    transaction_id: str
