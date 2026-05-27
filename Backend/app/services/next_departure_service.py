from fastapi import HTTPException

from app.db.repositories.next_departure_repository import (
    NextDepartureRepository,
)


class NextDepartureService:

    def __init__(self, db):
        self.repo = NextDepartureRepository(db)

    def get_all(self):
        return self.repo.get_all()

    def get_by_id(self, next_departure_id: int):
        item = self.repo.get_by_id(next_departure_id)

        if not item:
            raise HTTPException(
                status_code=404,
                detail="Next departure not found"
            )

        return item

    def get_by_station(self, station_id: str):
        return self.repo.get_by_station(station_id)

    def get_by_line(self, line_id: str):
        return self.repo.get_by_line(line_id)

    