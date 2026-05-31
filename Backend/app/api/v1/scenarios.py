from fastapi import APIRouter, Depends

from app.api.deps import get_db
from app.services.scenario_service import ScenarioService
from app.schemas.status.scenario import ScenarioResponse


router = APIRouter(
    prefix="/scenarios",
    tags=["Scenarios"]
)


@router.get("", response_model=list[ScenarioResponse])
def get_scenarios(db=Depends(get_db)):
    service = ScenarioService(db)
    return service.get_all()


@router.get("/{scenario_id}", response_model=ScenarioResponse)
def get_scenario(scenario_id: str, db=Depends(get_db)):
    service = ScenarioService(db)
    return service.get_by_id(scenario_id)