from fastapi import APIRouter

from app.api.v1 import health_router, stations_router, lines_router,routes_router

api_router = APIRouter(prefix="/api")

api_router.include_router(health_router)
api_router.include_router(stations_router)
api_router.include_router(lines_router)
api_router.include_router(routes_router)