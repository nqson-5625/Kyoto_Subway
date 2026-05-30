from fastapi import APIRouter, Depends

from app.api.deps import get_db
from app.services.edge_service import EdgeService
from app.schemas.network.edge import EdgeResponse


router = APIRouter(
    prefix="/edges",
    tags=["Edges"]
)


@router.get("", response_model=list[EdgeResponse])
def get_edges(db=Depends(get_db)):
    service = EdgeService(db)
    return service.get_all()


@router.get("/active", response_model=list[EdgeResponse])
def get_active_edges(db=Depends(get_db)):
    service = EdgeService(db)
    return service.get_active_edges()


@router.get("/{edge_id}", response_model=EdgeResponse)
def get_edge(edge_id: int, db=Depends(get_db)):
    service = EdgeService(db)
    return service.get_by_id(edge_id)