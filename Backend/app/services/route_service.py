# File: Backend/app/services/route_service.py
import traceback
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime, timedelta
from app.algorithms.graph_builder import build_graph_from_db
from app.algorithms.dijkstra import time_dependent_dijkstra

class RouteService:
    def __init__(self, db: Session):
        self.db = db

    async def calculate_optimal_route(self, payload):
        try:
            # 1. Dựng đồ thị trực tiếp từ Database
            transit_graph = build_graph_from_db(self.db, payload.scenario_id)
            
            # KIỂM TRA BẮT BỆNH: Nếu đồ thị rỗng (Không có edges)
            if not transit_graph.adj:
                return {"message": "CẢNH BÁO: Đồ thị rỗng. Bạn chưa import dữ liệu vào bảng 'edges' trong Database!"}

            # 2. Tìm ga xuất phát và ga đích gần nhất (Dùng PostGIS)
            start_st, origin_walk = await self._find_nearest_station(payload.start.lng, payload.start.lat)
            end_st, dest_walk = await self._find_nearest_station(payload.end.lng, payload.end.lat)
            
            if start_st == end_st:
                return {"message": f"Điểm đi và đến quá gần nhau (đều thuộc ga {start_st}). Hãy chọn điểm xa hơn."}

            # 3. Chạy thuật toán định tuyến Dijkstra
            actual_start_time = datetime.now() + timedelta(seconds=origin_walk)
            path, time_cost_seconds = time_dependent_dijkstra(transit_graph, start_st, end_st, actual_start_time)

            if path is None:
                return {"message": f"Không tìm thấy tuyến nối giữa {start_st} và {end_st}. Vui lòng kiểm tra lại kết nối đồ thị."}

            # 4. Map dữ liệu trực tiếp cho Frontend vẽ bản đồ (Bỏ qua các Schema Pydantic phức tạp)
            fe_segments = []
            for edge in path:
                coords, stations = self._get_geometry_for_segment(edge.from_station, edge.to_station)
                fe_segments.append({
                    "mode": "subway" if hasattr(edge, 'line_id') else "walk",
                    "line_id": getattr(edge, 'line_id', None),
                    "coordinates": coords,
                    "stations": stations,
                    "travel_minutes": round(edge.travel_seconds / 60.0, 2)
                })

            total_time_min = (origin_walk + time_cost_seconds + dest_walk) / 60.0

            return {
                "path": True,
                "travel_time": round(total_time_min, 2),
                "distance": 0,
                "segments": fe_segments,
                "message": "Đã tìm thấy tuyến đường tối ưu."
            }
        except Exception as e:
            traceback.print_exc()
            return {"message": f"Lỗi hệ thống: {str(e)}"}

    async def _find_nearest_station(self, lon, lat):
        # Truy vấn tìm ga gần nhất
        sql = text("""
            SELECT station_id, 
                   ST_Distance(geom::geography, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography) as dist_meters
            FROM stations
            WHERE is_active = TRUE
            ORDER BY geom <-> ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)
            LIMIT 1;
        """)
        result = self.db.execute(sql, {"lon": lon, "lat": lat}).fetchone()
        if not result:
            raise Exception("Bảng 'stations' trống. Hãy chạy file seed data.")
        return result[0], int(result[1] / 1.2) # walk_seconds

    def _get_geometry_for_segment(self, from_station, to_station):
        # Lấy tọa độ từng node để FE nối điểm LineString
        if not from_station or not to_station:
            return [], []
        sql = text("""
            SELECT station_id, station_name, ST_Y(geom::geometry) as lat, ST_X(geom::geometry) as lng
            FROM stations WHERE station_id IN (:from_st, :to_st)
        """)
        result = self.db.execute(sql, {"from_st": from_station, "to_st": to_station}).fetchall()
        
        # Đảm bảo thứ tự tọa độ luôn là [Ga_đi, Ga_đến]
        station_dict = {row[0]: {"id": row[0], "name": row[1], "lat": row[2], "lng": row[3]} for row in result}
        coords = []
        stations_info = []
        
        if from_station in station_dict and to_station in station_dict:
            stations_info = [station_dict[from_station], station_dict[to_station]]
            coords = [
                [station_dict[from_station]['lat'], station_dict[from_station]['lng']],
                [station_dict[to_station]['lat'], station_dict[to_station]['lng']]
            ]
            
        return coords, stations_info