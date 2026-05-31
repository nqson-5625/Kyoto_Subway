from fastapi import HTTPException

from app.db.repositories.scenario_repository import ScenarioRepository


class ScenarioService:

    def __init__(self, db):
        self.repo = ScenarioRepository(db)

    def get_all(self):
        return self.repo.get_all()

    def get_by_id(self, scenario_id: str):
        scenario = self.repo.get_by_id(scenario_id)

        if not scenario:
            raise HTTPException(
                status_code=404,
                detail="Scenario not found"
            )

        return scenario