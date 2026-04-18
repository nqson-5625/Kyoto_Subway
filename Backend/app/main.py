from fastapi import FastAPI
from app.api.router import api_router
from app.lifecycle import lifespan
from app.core.config import settings
from app.core.logging import setup_logging

setup_logging()

app = FastAPI(
    title=settings.app_name, 
    version=settings.app_version,
    debug=settings.app_debug,
    lifespan=lifespan
)

app.include_router(api_router)