from fastapi import HTTPException

from app.db.repositories.trip_repository import TripRepository


class TripService:

    def __init__(self, db):
        self.repo = TripRepository(db)

    def get_all(self):
        return self.repo.get_all()

    def get_by_id(self, trip_id: str):
        trip = self.repo.get_by_id(trip_id)

        if not trip:
            raise HTTPException(
                status_code=404,
                detail="Trip not found"
            )

        return trip

    def get_stops(self, trip_id: str):
        trip = self.repo.get_by_id(trip_id)

        if not trip:
            raise HTTPException(
                status_code=404,
                detail="Trip not found"
            )

        return self.repo.get_stops_by_trip_id(trip_id)