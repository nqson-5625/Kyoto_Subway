import heapq
import itertools
from datetime import datetime, timedelta
from typing import List, Tuple, Optional, Any, Callable
from .graph_builder import TransitGraph, RideEdge, TransferEdge

def time_dependent_astar(
    graph: TransitGraph,
    start_station_id: str,
    end_station_id: str,
    start_time: datetime,
    heuristic: Callable[[str, str], float]
) -> Tuple[Optional[List[Any]], float]:
    """
    Tìm đường ngắn nhất phụ thuộc thời gian sử dụng thuật toán A-Star (A*).
    Hàm heuristic(u, v) trả về thời gian ước tính (giây) từ ga u đến ga v.
    """
    counter = itertools.count() # Bộ đếm giúp phá hòa khi 2 node có cùng cost (tránh lỗi TypeError)
    
    # Khởi tạo ước lượng ban đầu
    h_start = heuristic(start_station_id, end_station_id)
    
    # Hàng đợi: (estimated_total_seconds, current_arrival_time, tiebreaker, current_station_id, path_so_far)
    pq = [(h_start, start_time, next(counter), start_station_id, [])]
    
    earliest_arrival = {start_station_id: start_time}
    
    while pq:
        est_total, curr_time, _, curr_station, path = heapq.heappop(pq)
        
        if curr_station == end_station_id:
            return path, (curr_time - start_time).total_seconds()
            
        if curr_time > earliest_arrival.get(curr_station, datetime.max):
            continue
            
        # 1. Xét các kết nối đi bộ (Transfers)
        for transfer in graph.transfers.get(curr_station, []):
            arr_time = curr_time + timedelta(seconds=transfer.travel_seconds)
            if arr_time < earliest_arrival.get(transfer.to_station, datetime.max):
                earliest_arrival[transfer.to_station] = arr_time
                h = heuristic(transfer.to_station, end_station_id)
                g = (arr_time - start_time).total_seconds()
                heapq.heappush(pq, (g + h, arr_time, next(counter), transfer.to_station, path + [transfer]))
                
        # 2. Xét các kết nối tàu (Rides)
        seen_lines = set()
        for ride in graph.rides.get(curr_station, []):
            if ride.departure_at >= curr_time:
                line_dir_key = (ride.line_id, ride.direction_id)
                if line_dir_key not in seen_lines:
                    seen_lines.add(line_dir_key)
                    if ride.arrival_at < earliest_arrival.get(ride.to_station, datetime.max):
                        earliest_arrival[ride.to_station] = ride.arrival_at
                        h = heuristic(ride.to_station, end_station_id)
                        g = (ride.arrival_at - start_time).total_seconds()
                        heapq.heappush(pq, (g + h, ride.arrival_at, next(counter), ride.to_station, path + [ride]))
                        
    return None, 0.0 # Không tìm thấy đường