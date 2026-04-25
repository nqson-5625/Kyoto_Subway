import heapq
from app.db.repositories.edge_repository import EdgeRepository

class RouteService:

    def __init__(self, db):
        self.repo = EdgeRepository(db)

    def shortest_path(self, start_id, end_id):

        edges = self.repo.get_active_edges()

        graph = {}

        for e in edges:
            graph.setdefault(e.from_station_id, []).append(
                (e.to_station_id, e.travel_time_min)
            )

        pq = [(0, start_id, [])]
        visited = set()

        while pq:
            cost, node, path = heapq.heappop(pq)

            if node in visited:
                continue

            visited.add(node)
            path = path + [node]

            if node == end_id:
                return {
                    "minutes": cost,
                    "path": path
                }

            for nxt, w in graph.get(node, []):
                heapq.heappush(pq, (cost + w, nxt, path))

        return None