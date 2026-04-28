from fastapi import APIRouter, Depends, Query
from app.services.route_service import RouteService
from app.api.deps import get_db
from app.schemas.route import RouteResponse

router = APIRouter(prefix="/route", tags=["AI Route"])


@router.get("/search", response_model=RouteResponse)
def search_route(
    origin: str = Query(..., min_length=1),
    destination: str = Query(..., min_length=1),
    db=Depends(get_db)
):
    service = RouteService(db)
    return service.shortest_path(origin, destination)