from fastapi import APIRouter
<<<<<<< Updated upstream
=======
from app.api.v1 import stations, routes, health
>>>>>>> Stashed changes

from app.api.v1 import health_router, stations_router, lines_router,routes_router

<<<<<<< Updated upstream
api_router = APIRouter(prefix="/api")

api_router.include_router(health_router)
api_router.include_router(stations_router)
api_router.include_router(lines_router)
api_router.include_router(routes_router)
=======
api_router.include_router(health.router)
api_router.include_router(stations.router)
api_router.include_router(routes.router)
>>>>>>> Stashed changes
