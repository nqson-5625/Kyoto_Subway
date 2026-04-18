from fastapi import APIRouter # Dùng để tách Router thành module riêng

router = APIRouter(prefix="/v1/health", tags=["health"]) #prefix="/health" tất cả API trong file sẽ tự động có thêm /health phía trước
                                                      #tags=["health"]  nhóm API trong Swagger API (docs)
@router.get("/") # Định nghĩa API GET

def health_check(): # Hàm xử lý khi có request GET tới /health
    return {"status": "OK"} # Trả về JSON response