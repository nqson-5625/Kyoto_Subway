from fastapi import HTTPException

from app.db.repositories.edge_repository import EdgeRepository


class EdgeService:

    def __init__(self, db):
        self.repo = EdgeRepository(db)

    def get_all(self):
        return self.repo.get_all()

    def get_by_id(self, edge_id: int):
        edge = self.repo.get_by_id(edge_id)

        if not edge:
            raise HTTPException(
                status_code=404,
                detail="Edge not found"
            )

        return edge

    def get_active_edges(self):
        return self.repo.get_active_edges()