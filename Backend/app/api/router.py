from app.api.v1 import stations, routes, health

api_router = APIRouter()

api_router.include_router(health.router)
api_router.include_router(stations.router)
api_router.include_router(routes.router)