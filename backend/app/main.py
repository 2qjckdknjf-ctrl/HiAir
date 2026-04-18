import json
import logging
from time import perf_counter
from uuid import uuid4

from app.api.auth import router as auth_router
from app.api.air import router as air_router
from app.api.alerts import router as alerts_router
from app.api.dashboard import router as dashboard_router
from fastapi import FastAPI
from fastapi import Request

from app.api.environment import router as environment_router
from app.api.health import router as health_router
from app.api.notifications import router as notifications_router
from app.api.observability import router as observability_router
from app.api.planner import router as planner_router
from app.api.privacy import router as privacy_router
from app.api.profiles import router as profiles_router
from app.api.recommendations import router as recommendations_router
from app.api.risk import router as risk_router
from app.api.settings import router as settings_router
from app.api.subscriptions import router as subscriptions_router
from app.api.symptoms import router as symptoms_router
from app.api.thresholds import router as thresholds_router
from app.api.validation import router as validation_router
from app.core.settings import settings, validate_runtime_settings
from app.services.observability import record_request

logger = logging.getLogger("hiair.api")
if not logger.handlers:
    logging.basicConfig(level=logging.INFO)


def create_app() -> FastAPI:
    validate_runtime_settings(settings)
    app = FastAPI(
        title="HiAir API",
        description="Backend API for HiAir MVP",
        version="0.1.0",
    )

    @app.middleware("http")
    async def request_logging_middleware(request: Request, call_next):  # type: ignore[no-redef]
        request_id = str(uuid4())
        started = perf_counter()
        response = await call_next(request)
        latency_ms = (perf_counter() - started) * 1000
        response.headers["X-Request-Id"] = request_id
        record_request(
            method=request.method,
            path=request.url.path,
            status_code=response.status_code,
            latency_ms=latency_ms,
        )
        logger.info(
            json.dumps(
                {
                    "request_id": request_id,
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": response.status_code,
                    "latency_ms": round(latency_ms, 2),
                }
            )
        )
        return response

    app.include_router(health_router, prefix="/api")
    app.include_router(auth_router, prefix="/api")
    app.include_router(profiles_router, prefix="/api")
    app.include_router(privacy_router, prefix="/api")
    app.include_router(dashboard_router, prefix="/api")
    app.include_router(planner_router, prefix="/api")
    app.include_router(environment_router, prefix="/api")
    app.include_router(risk_router, prefix="/api")
    app.include_router(air_router, prefix="/api")
    app.include_router(alerts_router, prefix="/api")
    app.include_router(settings_router, prefix="/api")
    app.include_router(subscriptions_router, prefix="/api")
    app.include_router(symptoms_router, prefix="/api")
    app.include_router(recommendations_router, prefix="/api")
    app.include_router(notifications_router, prefix="/api")
    app.include_router(observability_router, prefix="/api")
    app.include_router(thresholds_router, prefix="/api")
    app.include_router(validation_router, prefix="/api")
    return app


app = create_app()
