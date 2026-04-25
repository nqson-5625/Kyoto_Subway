from fastapi import APIRouter

router = APIRouter(
    prefix="/stations",
    tags=["stations"]
)

@router.get("/")
def get_stations():
    return [
        {"id": 1, "name": "Kyoto"},
        {"id": 2, "name": "Karasuma"}
    ]