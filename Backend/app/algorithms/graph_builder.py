from datetime import datetime
from collections import defaultdict
from typing import List, Dict

class RideEdge:
    """Cạnh mô tả một phân đoạn đi tàu (ride) giữa 2 ga."""
    def __init__(self, trip_id: str, line_id: str, direction_id: int, 
                 from_station: str, to_station: str, 
                 departure_at: datetime, arrival_at: datetime, travel_seconds: int):
        self.trip_id = trip_id
        self.line_id = line_id
        self.direction_id = direction_id
        self.from_station = from_station
        self.to_station = to_station
        self.departure_at = departure_at
        self.arrival_at = arrival_at
        self.travel_seconds = travel_seconds

class TransferEdge:
    """Cạnh mô tả việc đi bộ/chuyển tuyến (transfer) giữa 2 ga."""
    def __init__(self, from_station: str, to_station: str, travel_seconds: int):
        self.from_station = from_station
        self.to_station = to_station
        self.travel_seconds = travel_seconds

class TransitGraph:
    def __init__(self):
        # Dictionary lưu danh sách chuyến tàu rời đi từ một ga
        self.rides: Dict[str, List[RideEdge]] = defaultdict(list)
        # Dictionary lưu danh sách đi bộ/transfer từ một ga
        self.transfers: Dict[str, List[TransferEdge]] = defaultdict(list)

    def add_ride(self, edge: RideEdge):
        self.rides[edge.from_station].append(edge)

    def add_transfer(self, edge: TransferEdge):
        self.transfers[edge.from_station].append(edge)

    def sort_rides(self):
        """Sắp xếp các chuyến tàu theo thời gian xuất phát để dễ dàng tìm kiếm khi routing."""
        for station in self.rides:
            self.rides[station].sort(key=lambda e: e.departure_at)

def build_graph_from_records(records: List[dict]) -> TransitGraph:
    """Xây dựng đồ thị từ dữ liệu query view `v_routing_edges_active`."""
    graph = TransitGraph()
    for row in records:
        edge_type = row.get('edge_type')
        if edge_type == 'ride':
            graph.add_ride(RideEdge(
                trip_id=row['trip_id'],
                line_id=row['line_id'],
                direction_id=row['direction_id'],
                from_station=row['from_station_id'],
                to_station=row['to_station_id'],
                departure_at=row['departure_at'],
                arrival_at=row['arrival_at'],
                travel_seconds=row['travel_seconds']
            ))
        elif edge_type == 'transfer':
            graph.add_transfer(TransferEdge(
                from_station=row['from_station_id'],
                to_station=row['to_station_id'],
                travel_seconds=row['travel_seconds']
            ))
    graph.sort_rides()
    return graph