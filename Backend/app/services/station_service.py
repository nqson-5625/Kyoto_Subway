from app.db.repositories.station_repository import StationRepository

class StationService:

    def __init__(self, db):
        self.repo = StationRepository(db)

    def get_all_stations(self):
        return self.repo.get_all()

    def get_station_detail(self, station_id):
        station = self.repo.get_by_id(station_id)

        if not station:
            raise Exception("Station not found")

        return station