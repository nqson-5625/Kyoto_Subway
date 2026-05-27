from fastapi import HTTPException

from app.db.repositories.predicted_stop_time_repository import (
    PredictedStopTimeRepository,
)


class PredictedStopTimeService:

    def __init__(self, db):
        self.repo = PredictedStopTimeRepository(db)

    def get_all(self):
        return self.repo.get_all()

    def get_by_id(self, predicted_stop_time_id: int):
        item = self.repo.get_by_id(predicted_stop_time_id)

        if not item:
            raise HTTPException(
                status_code=404,
                detail="Predicted stop time not found"
            )

        return item

    def get_by_station(self, station_id: str):
        return self.repo.get_by_station(station_id)

    def get_by_trip(self, trip_id: str):
        return self.repo.get_by_trip(trip_id)

    
    