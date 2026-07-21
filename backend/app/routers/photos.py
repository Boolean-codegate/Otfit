from typing import Annotated

from fastapi import APIRouter, File, Form, UploadFile, status

from app.core.deps import CurrentUser, DbSession
from app.schemas.photo import PhotoAnalyzeResponse, PhotoUploadResponse
from app.schemas.product import RecommendationRequest, RecommendationResponse
from app.services.photos import PhotoService
from app.services.recommendations import RecommendationService
import uuid

router = APIRouter(tags=["photos"])


@router.post("/photos", response_model=PhotoUploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_photo(
    user: CurrentUser,
    session: DbSession,
    file: Annotated[UploadFile, File()],
    consent_image_processing: Annotated[bool, Form()] = False,
):
    service = PhotoService(session)
    photo = await service.upload(user.id, await file.read(), consent_image_processing)
    return {
        "id": photo.id,
        "storage_url": service.storage_url(photo),
        "width": photo.width,
        "height": photo.height,
        "status": photo.status,
        "uploaded_at": photo.created_at,
    }


@router.post("/photos/{photo_id}/analyze", response_model=PhotoAnalyzeResponse)
async def analyze_photo(photo_id: uuid.UUID, user: CurrentUser, session: DbSession):
    return await PhotoService(session).analyze(user.id, photo_id)


@router.delete("/photos/{photo_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_photo(photo_id: uuid.UUID, user: CurrentUser, session: DbSession):
    await PhotoService(session).delete(user.id, photo_id)


@router.post("/photos/{photo_id}/recommendations", response_model=RecommendationResponse)
async def recommend(
    photo_id: uuid.UUID, body: RecommendationRequest, user: CurrentUser, session: DbSession
):
    await PhotoService(session).get_owned(user.id, photo_id)  # 소유권 확인
    return await RecommendationService(session).recommend(photo_id, body.mode, body.style_id)
