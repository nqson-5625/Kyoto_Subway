from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ScenarioResponse(BaseModel):
    scenario_id: str
    scenario_name: str
    scenario_type: str
    description: str | None = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
