from enum import Enum

# Loại segment trong route.
class SegmentMode(str, Enum):
    WALK = "walk" # đi bộ
    RIDE = "ride" # đi tàu
    TRANSFER = "transfer" # trung chuyển/chuyển tuyến


# Trạng thái chung của kết quả routing.
class RouteStatus(str, Enum):
    SUCCESS = "success" # tìm được route hoàn chỉnh
    NO_ROUTE = "no_route" # không tìm được route
    PARTIAL = "partial" # chỉ tìm được một phần route
    ERROR = "error" # lỗi xử lý