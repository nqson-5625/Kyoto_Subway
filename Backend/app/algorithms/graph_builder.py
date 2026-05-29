# File: app/algorithms/graph_builder.py
from sqlalchemy.orm import Session
from sqlalchemy import text
from collections import defaultdict

class RideEdge:
    def __init__(self, from_station, to_station, line_id, travel_seconds):
        self.from_station = from_station
        self.to_station = to_station
        self.line_id = line_id
        self.travel_seconds = travel_seconds
        self.trip_id = None
        self.direction_id = 1

class TransferEdge:
    def __init__(self, from_station, to_station, travel_seconds):
        self.from_station = from_station
        self.to_station = to_station
        self.travel_seconds = travel_seconds

class TransitGraph:
    def __init__(self):
        self.adj = defaultdict(list)
    
    def add_edge(self, edge):
        self.adj[edge.from_station].append(edge)

def build_graph_from_db(db: Session, scenario_id: str = "") -> TransitGraph:
    graph = TransitGraph()
    
    # Lấy các cạnh tàu điện ngầm. Tích hợp thời gian trễ từ các sự kiện trạng thái.
    # Ưu tiên lấy từ routing_edges_current. Nếu không có thì fallback lấy edges gốc.
    sql_edges = text("""
        SELECT e.from_station_id, e.to_station_id, e.line_id, 
               (e.travel_time_min * 60) + COALESCE((
                   SELECT delay_min * 60 FROM line_status_events lse 
                   WHERE lse.line_id = e.line_id 
                   ORDER BY recorded_at DESC LIMIT 1
               ), 0) as total_travel_seconds
        FROM edges e
        WHERE e.is_active = TRUE;
    """)
    
    edges_result = db.execute(sql_edges).fetchall()
    for row in edges_result:
        graph.add_edge(RideEdge(row[0], row[1], row[2], float(row[3])))

    # Lấy các cạnh trung chuyển đi bộ (transfer)
    sql_transfers = text("""
        SELECT from_station_id, to_station_id, (transfer_time_min * 60) as transfer_seconds
        FROM transfers
        WHERE is_active = TRUE;
    """)
    transfers_result = db.execute(sql_transfers).fetchall()
    for row in transfers_result:
        graph.add_edge(TransferEdge(row[0], row[1], float(row[2])))

    return graph