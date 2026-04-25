from fastapi import APIRouter

router = APIRouter(
    prefix="/lines",
    tags=["lines"]
)

@router.get("/")
def get_lines():
    return [
        {"id": 1, "name": "Karasuma Line"},
        {"id": 2, "name": "Tozai Line"}
    ]