from typing import List

from app.schemas.network.line import LineResponse
from fastapi import APIRouter, Depends
from app.api.deps import get_db
from app.services.line_service import LineService

router = APIRouter(prefix="/lines", tags=["Lines"])


@router.get("", response_model=List[LineResponse])
def get_lines(db=Depends(get_db)):
    service = LineService(db)
    return service.get_all()