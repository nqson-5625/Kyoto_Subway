from fastapi import APIRouter, Depends
from app.api.deps import get_db
from app.services.line_service import LineService

router = APIRouter(prefix="/lines", tags=["Lines"])


@router.get("")
def get_lines(db=Depends(get_db)):
    service = LineService(db)
    return service.get_all()