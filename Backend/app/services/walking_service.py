# File: Backend/app/services/walking_service.py
import json
from pathlib import Path
from typing import Tuple, List, Set, Optional
import pandas as pd
import networkx as nx
import osmnx as ox

class WalkingService:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(WalkingService, cls).__new__(cls)
            cls._instance.G = None
            cls._instance.station_nodes_map = {}
        return cls._instance

    def load_data(self):
        """Tải bản đồ OpenStreetMap và ánh xạ ga vào bộ nhớ"""
        base_dir = Path(__file__).resolve().parents[2]
        graph_path = base_dir / "data" / "current" / "walking_graph.graphml"
        links_path = base_dir / "data" / "current" / "station_access_links.parquet"

        if not graph_path.exists() or not links_path.exists():
            print("CẢNH BÁO: Chưa tìm thấy dữ liệu walking_graph. Vui lòng chạy script build trước.")
            return

        self.G = ox.load_graphml(graph_path)
        
        df_links = pd.read_parquet(links_path)
        self.station_nodes_map = {
            row["graph_node_id"]: row["station_id"] 
            for _, row in df_links.iterrows()
        }

    # Nhớ thêm Optional và Set vào phần import ở đầu file nếu chưa có:
    # from typing import Tuple, List, Set, Optional

    def find_nearest_station_path(
        self, 
        lon: float, 
        lat: float, 
        valid_station_ids: Optional[Set[str]] = None
    ) -> Tuple[str, int, List[List[float]]]:
        """
        Tìm ga gần nhất ĐANG HOẠT ĐỘNG và trả về:
        - station_id
        - thời gian đi bộ (giây)
        - danh sách toạ độ [[lat, lon], ...] của đường đi
        """
        if self.G is None:
            self.load_data()

        # 1. Tìm node (ngã tư/đoạn đường) gần vị trí click nhất
        user_node = ox.distance.nearest_nodes(self.G, X=lon, Y=lat)

        # 2. Tìm khoảng cách và đường đi tới tất cả các node kết nối
        lengths, paths = nx.single_source_dijkstra(self.G, user_node, weight='length')

        best_station_id = None
        min_walking_distance = float('inf')
        best_path_nodes = []

        # 3. Lọc lấy Ga (station) có khoảng cách đi bộ ngắn nhất VÀ hợp lệ
        for graph_node_id, station_id in self.station_nodes_map.items():
            
            # --- ĐIỂM NÂNG CẤP ---
            # Nếu Backend truyền vào danh sách ga hợp lệ (đang mở), 
            # mà ga này không nằm trong danh sách đó -> Bỏ qua, đi tìm ga khác xa hơn!
            if valid_station_ids is not None and station_id not in valid_station_ids:
                continue
            # ---------------------

            if graph_node_id in lengths:
                dist = lengths[graph_node_id]
                if dist < min_walking_distance:
                    min_walking_distance = dist
                    best_station_id = station_id
                    best_path_nodes = paths[graph_node_id]

        if best_station_id is None:
            raise Exception("Không tìm thấy đường đi bộ từ vị trí này tới bất kỳ ga nào đang hoạt động.")

        # 4. Trích xuất toạ độ lat/lon từ danh sách node đường đi
        coords = []
        for node in best_path_nodes:
            node_data = self.G.nodes[node]
            coords.append([float(node_data['y']), float(node_data['x'])])

        walk_seconds = int(min_walking_distance / 1.2) # Vận tốc 1.2m/s
        return best_station_id, walk_seconds, coords

    def get_walking_path(self, lon: float, lat: float, target_station_id: str) -> List[List[float]]:
        """Tìm đường đi bộ dựa trên mạng lưới đường bộ (OSM) từ toạ độ người dùng đến một ga cụ thể"""
        if self.G is None:
            self.load_data()

        # 1. Tìm node mạng đường bộ gần vị trí người dùng nhất
        user_node = ox.distance.nearest_nodes(self.G, X=lon, Y=lat)
        
        # 2. Tìm node tương ứng với ID của ga mục tiêu
        target_node = None
        for graph_node_id, station_id in self.station_nodes_map.items():
            if str(station_id) == str(target_station_id):
                target_node = graph_node_id
                break
                
        if not target_node:
            return None # Trả về None để code bên ngoài fallback vẽ đường thẳng

        try:
            # 3. Tìm đường đi ngắn nhất (Dijkstra) trên lưới OSM
            path_nodes = nx.shortest_path(self.G, source=user_node, target=target_node, weight='length')
            coords = []
            for node in path_nodes:
                node_data = self.G.nodes[node]
                coords.append([float(node_data['y']), float(node_data['x'])])
            return coords
        except (nx.NetworkXNoPath, nx.NodeNotFound):
            return None

# Khởi tạo Singleton
walking_service = WalkingService()