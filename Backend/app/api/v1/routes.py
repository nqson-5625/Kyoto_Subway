from fastapi import APIRouter, Depends
from app.services.route_service import RouteService
from app.api.deps import get_db

router = APIRouter(prefix="/route", tags=["AI Route"])

@router.get("/search")
def search_route(
    origin: str,
    destination: str,
    db=Depends(get_db)
):
    service = RouteService(db)
    return service.shortest_path(origin, destination)