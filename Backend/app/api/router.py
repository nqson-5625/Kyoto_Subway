from app.api.v1 import stations, routes, health,line_status_events,station_status_events,trip_status_events,edge_status_events,control_center

api_router = APIRouter()

api_router.include_router(health.router)
api_router.include_router(stations.router)
api_router.include_router(routes.router)
api_router.include_router(line_status_events.router)
api_router.include_router(station_status_events.router)
api_router.include_router(trip_status_events.router)
api_router.include_router(edge_status_events)
api_router.include_router(control_center)
