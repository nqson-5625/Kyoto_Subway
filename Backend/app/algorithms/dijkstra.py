import heapq
import itertools
from datetime import datetime, timedelta
from typing import List, Tuple, Optional, Any
from .graph_builder import TransitGraph, RideEdge, TransferEdge

def time_dependent_dijkstra(
    graph: TransitGraph,
    start_station_id: str,
    end_station_id: str,
    start_time: datetime
) -> Tuple[Optional[List[Any]], float]:
    """
    Tìm đường ngắn nhất phụ thuộc vào thời gian.
    Trả về (List các Segments (RideEdge/TransferEdge), tổng thời gian di chuyển (giây)).
    """
    # Hàng đợi ưu tiên: (current_time, current_station_id, path_so_far)
    # Lưu ý: Trong production, để tránh memory overhead, ta thường lưu mảng 'parent_pointers'
    # thay vì lưu mảng 'path_so_far' thẳng vào queue. Ở đây dùng path mảng để dễ theo dõi logic.
    counter = itertools.count() # Tiebreaker để tránh lỗi so sánh khi 2 path có cùng cost
    pq = [(start_time, next(counter), start_station_id, [])]
    
    # Earliest Arrival Time (EAT) - Thời gian đến sớm nhất tại mỗi ga
    earliest_arrival = {start_station_id: start_time}
    
    while pq:
        curr_time, _, curr_station, path = heapq.heappop(pq)
        
        # Nếu đã đến đích, kết thúc
        if curr_station == end_station_id:
            return path, (curr_time - start_time).total_seconds()
        
        # Nếu node này đã được thăm với thời gian tốt hơn từ một đường khác, bỏ qua
        if curr_time > earliest_arrival.get(curr_station, datetime.max):
            continue
            
        # 1. Xét các kết nối đi bộ (Transfers)
        for transfer in graph.transfers.get(curr_station, []):
            arr_time = curr_time + timedelta(seconds=transfer.travel_seconds)
            if arr_time < earliest_arrival.get(transfer.to_station, datetime.max):
                earliest_arrival[transfer.to_station] = arr_time
                heapq.heappush(pq, (arr_time, next(counter), transfer.to_station, path + [transfer]))
        
        # 2. Xét các kết nối tàu (Rides)
        seen_lines = set()
        for ride in graph.rides.get(curr_station, []):
            if ride.departure_at >= curr_time:
                line_dir_key = (ride.line_id, ride.direction_id)
                # Chỉ thử chuyến tàu sớm nhất của mỗi (tuyến + hướng) để giảm không gian duyệt
                if line_dir_key not in seen_lines:
                    seen_lines.add(line_dir_key)
                    if ride.arrival_at < earliest_arrival.get(ride.to_station, datetime.max):
                        earliest_arrival[ride.to_station] = ride.arrival_at
                        heapq.heappush(pq, (ride.arrival_at, next(counter), ride.to_station, path + [ride]))
                        
    return None, 0.0 # Không tìm thấy đường