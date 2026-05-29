from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.api.deps import get_db
from app.services.route_service import RouteService
import traceback

router = APIRouter(prefix="/route", tags=["AI Route"])

class Coordinate(BaseModel):
    lat: float
    lng: float

class RouteRequestPayload(BaseModel):
    start: Coordinate
    end: Coordinate
    algorithm: str = "dijkstra"
    scenario_id: str = ""
    service_date: str = ""

@router.post("/find-path")
async def find_path(payload: RouteRequestPayload, db: Session = Depends(get_db)):
    try:
        service = RouteService(db)
        # Sử dụng await để gọi Service xử lý bất đồng bộ
        result = await service.calculate_optimal_route(payload)
        return result
    except Exception as e:
        print("=== LỖI TÌM ĐƯỜNG ===")
        traceback.print_exc() # In chi tiết lỗi đỏ ra Terminal để dễ bắt bệnh
        raise HTTPException(status_code=500, detail=str(e))