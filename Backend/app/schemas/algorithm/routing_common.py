from __future__ import annotations

from pydantic import BaseModel, ConfigDict

# Tọa độ cơ bản
class Coordinate(BaseModel): 
    lon: float  # Kinh độ
    lat: float # Vĩ độ

    model_config = ConfigDict(from_attributes=True)


# Core-routing tính "cost theo logic thuật toán", không nhất thiết là phút thực tế
class CostBreakdown(BaseModel):
    total_cost: float # Tổng cost route   
    walking_cost: float = 0.0 # Phần cost đến từ đi bộ
    ride_cost: float = 0.0 # Phần cost đến từ đi tàu
    transfer_cost: float = 0.0 # Phần cost đến từ transfer 
    penalty_cost: float = 0.0 # Các loại penalty khác: delay penalty, disruption penalty, scenario penalty...

    model_config = ConfigDict(from_attributes=True)


# Schema breakdown về thời gian thực tế hơn (route-postprocessing tính)
class TimeBreakdown(BaseModel):
    walking_minutes: float = 0.0 # Tổng thời gian đi bộ
    in_vehicle_minutes: float = 0.0 # Tổng thời gian ngồi trên phương tiện
    transfer_minutes: float = 0.0 # Tổng thời gian transfer
    waiting_minutes: float = 0.0 # Tổng thời gian chờ
    total_minutes: float = 0.0 # Tổng thời gian toàn hành trình

    model_config = ConfigDict(from_attributes=True)


# Warning chung cho core-routing và route-postprocessing
class RouteWarning(BaseModel):
    code: str # Mã warning ngắn gọngọn:"long_walk", "partial_realtime", "station_closed_nearby"
    message: str # Message mô tả warning

    model_config = ConfigDict(from_attributes=True)


# Schema polyline đơn giản: giữ list tọa độ
class RoutePolyline(BaseModel):
    coordinates: list[Coordinate] = [] # Danh sách điểm tạo thành đường đi

    model_config = ConfigDict(from_attributes=True)


# Tham chiếu ga: Dùng khi chỉ cần "ga nào", không cần toàn bộ record station
class StationRef(BaseModel):
    station_id: str # Mã ga, ví dụ K08, T13
    station_name: str | None = None # Tên ga 
    line_id: str | None = None # Tuyến liên quan 
    line_station_order: int | None = None # Thứ tự ga trên tuyến 

    model_config = ConfigDict(from_attributes=True)


# Schema tham chiếu graph node: Dùng cho walking graph hoặc graph
class GraphNodeRef(BaseModel):
    node_id: int | str # ID node trong graph 
    lon: float | None = None # Kinh độ của node
    lat: float | None = None # Vĩ độ của node

    model_config = ConfigDict(from_attributes=True)