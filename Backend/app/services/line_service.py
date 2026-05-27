from app.db.repositories.line_repository import LineRepository


class LineService:

    def __init__(self, db):
        self.repo = LineRepository(db)

    def get_all(self):
        return self.repo.get_all()