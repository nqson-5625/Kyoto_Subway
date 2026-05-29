import traceback
import json
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime
from app.algorithms.graph_builder import build_graph_from_db
from app.algorithms.core_router import process_routing_request
from app.algorithms.route_postprocessing_output_algorithms import get_final_output
from app.schemas.algorithm.core_routing_output import CoreRoutingRequestEcho

class RouteService:
    def __init__(self, db: Session):
        self.db = db

    async def calculate_optimal_route(self, payload):
        try:
            # 1. Khởi tạo đồ thị
            transit_graph = build_graph_from_db(self.db, payload.scenario_id)
            if not transit_graph.adj:
                return {"message": "CẢNH BÁO: Đồ thị định tuyến trống. Vui lòng kiểm tra dữ liệu."}

            request_echo = CoreRoutingRequestEcho(
                origin=(payload.start.lng, payload.start.lat),
                destination=(payload.end.lng, payload.end.lat),
                scenario_id=payload.scenario_id if payload.scenario_id else None,
                optimize_for="time"
            )

            # 2. Tính toán đường đi lõi
            core_output = await process_routing_request(
                request=request_echo,
                graph=transit_graph,
                request_time=datetime.now(),
                db=self.db,
                algorithm=payload.algorithm
            )

            status_val = getattr(core_output.status, 'value', str(core_output.status))
            if status_val in ["fail", "no_route"] or not core_output.routes:
                return {"message": "Không tìm thấy lộ trình phù hợp!"}

            # 3. Post-Processing xử lý chi tiết
            final_output = get_final_output(core_output, {}, {})
            optimal_route = final_output.routes[0]
            fe_segments = []

            # Lấy chính xác mảng dữ liệu (Hỗ trợ cả Postprocessing Schema và Core Schema)
            route_steps = getattr(optimal_route, 'instructions', getattr(optimal_route, 'segments', []))

            # Hàm đắc lực: Trích xuất ID Ga từ object lồng nhau (StationRef)
            def get_station_id(st_obj):
                if not st_obj: return None
                if isinstance(st_obj, dict): return st_obj.get('station_id')
                return getattr(st_obj, 'station_id', None)

            # 4. Trích xuất ID các ga để lấy tọa độ Snap Point
            all_station_ids = set()
            for step in route_steps:
                f_id = get_station_id(getattr(step, 'from_station', None)) or getattr(step, 'from_station_id', None)
                t_id = get_station_id(getattr(step, 'to_station', None)) or getattr(step, 'to_station_id', None)
                if f_id: all_station_ids.add(f_id)
                if t_id: all_station_ids.add(t_id)

            station_dict = {}
            if all_station_ids:
                sql_st = text("""
                    SELECT station_id, ST_Y(geom::geometry) as lat, ST_X(geom::geometry) as lng
                    FROM stations WHERE station_id = ANY(:ids)
                """)
                rows = self.db.execute(sql_st, {"ids": list(all_station_ids)}).fetchall()
                for r in rows:
                    station_dict[r[0]] = {"lat": r[1], "lng": r[2]}

            # 5. Khâu từng phân đoạn đường đi (Segments)
            for idx, step in enumerate(route_steps):
                mode_val = getattr(step, 'mode', 'unknown')
                if hasattr(mode_val, 'value'): mode_val = mode_val.value
                mode_val = str(mode_val).split('.')[-1].lower()

                # Gọi hàm bóc tách dữ liệu lồng nhau
                from_id = get_station_id(getattr(step, 'from_station', None)) or getattr(step, 'from_station_id', None)
                to_id = get_station_id(getattr(step, 'to_station', None)) or getattr(step, 'to_station_id', None)
                line_id = getattr(step, 'line_id', None)
                
                coords = []

                # --- CHẶNG A: ĐI BỘ (Nét đứt) ---
                if mode_val == "walk":
                    if idx == 0 and to_id:  # Chặng đầu từ A vào Ga
                        st_info = station_dict.get(to_id)
                        if st_info:
                            coords = [[payload.start.lat, payload.start.lng], [st_info['lat'], st_info['lng']]]
                    elif idx == len(route_steps) - 1 and from_id: # Chặng cuối từ Ga ra B
                        st_info = station_dict.get(from_id)
                        if st_info:
                            coords = [[st_info['lat'], st_info['lng']], [payload.end.lat, payload.end.lng]]
                    
                    if coords:
                        fe_segments.append({"mode": "walk", "coordinates": coords, "stations": []})
                
                # --- CHẶNG B: ĐI TÀU/TRUNG CHUYỂN (Tuyến ray uốn lượn màu xanh) ---
                elif mode_val in ["ride", "subway", "transfer"]:
                    if from_id and to_id:
                        if mode_val in ["ride", "subway"]:
                            sql_edge = text("""
                                SELECT ST_AsGeoJSON(geom), from_station_id 
                                FROM edges 
                                WHERE ((from_station_id = :from_st AND to_station_id = :to_st)
                                   OR (from_station_id = :to_st AND to_station_id = :from_st))
                                LIMIT 1
                            """)
                            edge_res = self.db.execute(sql_edge, {"from_st": from_id, "to_st": to_id}).fetchone()
                            
                            if edge_res and edge_res[0]:
                                try:
                                    geom_data = json.loads(edge_res[0])
                                    if geom_data.get("type") == "LineString":
                                        coords = [[pt[1], pt[0]] for pt in geom_data.get("coordinates", [])]
                                    elif geom_data.get("type") == "MultiLineString":
                                        for line in geom_data.get("coordinates", []):
                                            for pt in line:
                                                coords.append([pt[1], pt[0]])
                                    
                                    if coords and edge_res[1] == to_id:
                                        coords.reverse() # Lật chiều nếu DB đang lưu hướng ngược
                                except Exception:
                                    pass

                        st_from = station_dict.get(from_id)
                        st_to = station_dict.get(to_id)
                        
                        # Ràng buộc tọa độ khóa chặt đầu đuôi vào ga
                        if not coords and st_from and st_to:
                            coords = [[st_from['lat'], st_from['lng']], [st_to['lat'], st_to['lng']]]
                        elif coords and st_from and st_to:
                            coords[0] = [st_from['lat'], st_from['lng']]
                            coords[-1] = [st_to['lat'], st_to['lng']]

                        mode_str = "subway" if mode_val == "ride" else mode_val
                        
                        if coords:
                            fe_segments.append({
                                "mode": mode_str,
                                "line_id": line_id,
                                "coordinates": coords,
                                "stations": [] 
                            })

            # Tính tổng thời gian động cho nhiều kiểu output
            time_obj = getattr(optimal_route, 'time_breakdown', getattr(optimal_route, 'cost_breakdown', None))
            total_time = 0
            if time_obj:
                total_time = getattr(time_obj, 'total_minutes', getattr(time_obj, 'total_time_minutes', getattr(time_obj, 'total_cost', 0)))

            # Trong hàm calculate_optimal_route
            print(f"Số lượng segments được tạo: {len(fe_segments)}")
            for seg in fe_segments:
                print(f"Mode: {seg.get('mode')}, Toạ độ: {len(seg.get('coordinates', []))}")

            return {
                "path": True,
                "travel_time": round(float(total_time), 2),
                "distance": 0,
                "segments": fe_segments,
                "message": "Tìm đường thành công."
            }
        except Exception as e:
            traceback.print_exc()
            return {"message": f"Lỗi xử lý: {str(e)}"}