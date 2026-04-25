from fastapi import APIRouter
from pydantic import BaseModel
from app.services.pathfinder import shortest_path

router = APIRouter(
    prefix="/routes",
    tags=["routes"]
)


class RouteRequest(BaseModel):
    start: str
    end: str


@router.post("/find")
def find_route(data: RouteRequest):
    return shortest_path(data.start, data.end)