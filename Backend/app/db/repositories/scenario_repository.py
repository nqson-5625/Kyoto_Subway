from app.db.models.network import Scenario


class ScenarioRepository:

    def __init__(self, db):
        self.db = db

    def get_all(self):
        return self.db.query(Scenario).all()

    def get_by_id(self, scenario_id: str):
        return (
            self.db.query(Scenario)
            .filter(Scenario.scenario_id == scenario_id)
            .first()
        )