from fastapi import APIRouter # Tạo Router tổng gom nhiều router lại

from app.api.v1 import health_router

api_router = APIRouter(prefix="/api")
api_router.include_router(health_router) 