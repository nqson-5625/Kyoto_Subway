from app.db.models.network import Edge


class EdgeRepository:

    def __init__(self, db):
        self.db = db

    def get_active_edges(self):
        return (
            self.db.query(Edge)
            .filter(Edge.is_active.is_(True))
            .all()
        )