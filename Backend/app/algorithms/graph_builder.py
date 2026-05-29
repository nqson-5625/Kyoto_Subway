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
    
    # Lấy các cạnh tàu điện ngầm. Tích hợp thời gian trễ và trạng thái đóng cửa thời gian thực.
    sql_edges = text("""
        WITH latest_line_status AS (
            SELECT line_id, delay_min, status
            FROM line_status_events
            WHERE effective_to IS NULL OR effective_to > NOW()
            ORDER BY recorded_at DESC
        ),
        latest_edge_status AS (
            SELECT edge_id, delay_min, status
            FROM edge_status_events
            WHERE effective_to IS NULL OR effective_to > NOW()
            ORDER BY recorded_at DESC
        ),
        latest_station_status AS (
            SELECT station_id, status
            FROM station_status_events
            WHERE effective_to IS NULL OR effective_to > NOW()
            ORDER BY recorded_at DESC
        )
        SELECT e.from_station_id, e.to_station_id, e.line_id, 
               (e.travel_time_min * 60) 
               + COALESCE((SELECT delay_min * 60 FROM latest_line_status lls WHERE lls.line_id = e.line_id LIMIT 1), 0) 
               + COALESCE((SELECT delay_min * 60 FROM latest_edge_status les WHERE les.edge_id = e.edge_id LIMIT 1), 0)
               as total_travel_seconds,
               (SELECT status FROM latest_station_status lss WHERE lss.station_id = e.from_station_id LIMIT 1) as from_status,
               (SELECT status FROM latest_station_status lss WHERE lss.station_id = e.to_station_id LIMIT 1) as to_status,
               (SELECT status FROM latest_edge_status les WHERE les.edge_id = e.edge_id LIMIT 1) as edge_status,
               (SELECT status FROM latest_line_status lls WHERE lls.line_id = e.line_id LIMIT 1) as line_status
        FROM edges e
        WHERE e.is_active = TRUE;
    """)
    
    edges_result = db.execute(sql_edges).fetchall()
    closed_statuses = {'closed', 'suspended', 'disrupted'}

    for row in edges_result:
        from_st, to_st, line_id, travel_seconds, from_status, to_status, edge_status, line_status = row
        
        # Loại bỏ các đoạn đường bị ảnh hưởng hoàn toàn bởi sự cố đóng cửa
        if (from_status in closed_statuses or 
            to_status in closed_statuses or 
            edge_status in closed_statuses or 
            line_status in closed_statuses):
            continue
            
        graph.add_edge(RideEdge(from_st, to_st, line_id, float(travel_seconds)))

    # Lấy các cạnh trung chuyển đi bộ giữa các thềm ga (transfer)
    sql_transfers = text("""
        SELECT from_station_id, to_station_id, (transfer_time_min * 60) as transfer_seconds
        FROM transfers
        WHERE is_active = TRUE;
    """)
    transfers_result = db.execute(sql_transfers).fetchall()
    for row in transfers_result:
        graph.add_edge(TransferEdge(row[0], row[1], float(row[2])))

    return graph