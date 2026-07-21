from fastapi import APIRouter

from app.core.deps import CurrentUser, DbSession
from app.schemas.consent import ConsentListResponse, ConsentOut, ConsentUpsertRequest
from app.services.consents import ConsentService

router = APIRouter(tags=["consents"])


@router.post("/consents", response_model=ConsentOut)
async def upsert_consent(body: ConsentUpsertRequest, user: CurrentUser, session: DbSession):
    return await ConsentService(session).upsert(user.id, body.type, body.granted)


@router.get("/consents", response_model=ConsentListResponse)
async def list_consents(user: CurrentUser, session: DbSession):
    return {"items": await ConsentService(session).list_for_user(user.id)}
