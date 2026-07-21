from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

# 에러 공통 포맷 (계약 §0):
# { "error": { "code": "INVALID_PHOTO", "message": "...", "detail": {} } }
# 대표 code: UNAUTHORIZED, VALIDATION_ERROR, INVALID_PHOTO, INSUFFICIENT_CREDITS,
#            NOT_FOUND, GENERATION_FAILED, RATE_LIMITED


class AppError(Exception):
    status_code = status.HTTP_400_BAD_REQUEST
    code = "VALIDATION_ERROR"

    def __init__(
        self,
        message: str,
        *,
        code: str | None = None,
        status_code: int | None = None,
        detail: dict | None = None,
    ):
        self.message = message
        self.detail = detail or {}
        if code:
            self.code = code
        if status_code:
            self.status_code = status_code
        super().__init__(message)


class NotFoundError(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    code = "NOT_FOUND"


class UnauthorizedError(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = "UNAUTHORIZED"


class ForbiddenError(AppError):
    status_code = status.HTTP_403_FORBIDDEN
    code = "FORBIDDEN"


class ConflictError(AppError):
    status_code = status.HTTP_409_CONFLICT
    code = "CONFLICT"


class InsufficientCreditsError(AppError):
    status_code = status.HTTP_402_PAYMENT_REQUIRED
    code = "INSUFFICIENT_CREDITS"


class InvalidPhotoError(AppError):
    status_code = status.HTTP_400_BAD_REQUEST
    code = "INVALID_PHOTO"


class GenerationFailedError(AppError):
    status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
    code = "GENERATION_FAILED"


def _error_body(code: str, message: str, detail: dict | list | None = None) -> dict:
    return {"error": {"code": code, "message": message, "detail": detail or {}}}


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def app_error_handler(request: Request, exc: AppError):
        return JSONResponse(
            status_code=exc.status_code,
            content=_error_body(exc.code, exc.message, exc.detail),
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(request: Request, exc: RequestValidationError):
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content=_error_body(
                "VALIDATION_ERROR",
                "요청 형식이 올바르지 않습니다.",
                {"errors": [{"loc": [str(l) for l in e["loc"]], "msg": e["msg"]} for e in exc.errors()]},
            ),
        )
