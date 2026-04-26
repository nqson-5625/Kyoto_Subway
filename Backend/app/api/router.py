from fastapi import APIRouter
from app.api.v1 import stations, routes

api_router = APIRouter()

api_router.include_router(stations.router)
api_router.include_router(routes.router)