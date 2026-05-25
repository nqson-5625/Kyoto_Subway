from sqlalchemy.orm import Session
from app.db.models.network import Station


class StationRepository:

    def __init__(self, db: Session):
        self.db = db

    def get_all(self):
        return self.db.query(Station).all()

    def get_by_id(self, station_id: str):
        return self.db.query(Station).filter(
            Station.station_id == station_id
        ).first()

    def search_by_name(self, keyword: str):
        return self.db.query(Station).filter(
            Station.station_name.ilike(f"%{keyword}%")
        ).all()