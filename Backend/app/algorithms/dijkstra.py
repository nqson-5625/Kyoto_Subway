import heapq
import itertools
from datetime import datetime, timedelta
from typing import List, Tuple, Optional, Any

def time_dependent_dijkstra(
    graph,
    start_station_id: str,
    end_station_id: str,
    start_time: datetime
) -> Tuple[Optional[List[Any]], float]:
    """
    Tìm đường ngắn nhất phụ thuộc vào thời gian (đã cộng dồn delay).
    """
    counter = itertools.count() 
    # Hàng đợi: (thời_gian_đến, id_thứ_tự, ga_hiện_tại, đường_đi_tích_lũy)
    pq = [(start_time, next(counter), start_station_id, [])]
    
    # EAT: Earliest Arrival Time
    earliest_arrival = {start_station_id: start_time}
    
    while pq:
        curr_time, _, curr_station, path = heapq.heappop(pq)
        
        # Nếu đã đến đích, trả về lộ trình và tổng thời gian (giây)
        if curr_station == end_station_id:
            return path, (curr_time - start_time).total_seconds()
        
        # Bỏ qua nếu có đường khác đến ga này sớm hơn
        if curr_time > earliest_arrival.get(curr_station, datetime.max):
            continue
            
        # Duyệt qua TẤT CẢ các cạnh (cả đi bộ lẫn đi tàu) từ ga hiện tại
        for edge in graph.adj.get(curr_station, []):
            arr_time = curr_time + timedelta(seconds=edge.travel_seconds)
            
            if arr_time < earliest_arrival.get(edge.to_station, datetime.max):
                earliest_arrival[edge.to_station] = arr_time
                heapq.heappush(pq, (arr_time, next(counter), edge.to_station, path + [edge]))
                
    return None, 0.0 # Không tìm thấy đường