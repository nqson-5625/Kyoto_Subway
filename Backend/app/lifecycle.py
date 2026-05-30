import logging
from contextlib import asynccontextmanager
from collections.abc import AsyncIterator

from fastapi import FastAPI
from app.services.walking_service import walking_service

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    logger.info("Starting Kyoto Subway backend...")
    print("Loading walking graph and station links...")
    try:
        walking_service.load_data()
        print("Walking graph loaded successfully.")
    except Exception as e:
        logger.error(f"Error occurred while loading walking data: {e}")
        raise
    yield
    logger.info("Shutting down Kyoto Subway backend...")