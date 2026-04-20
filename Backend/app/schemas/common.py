from pydantic import BaseModel

# quy định khuôn mẫu của response/request
class MessageResponse(BaseModel):
    message: str # định dạng JSON: {"message": "chuỗi văn bản"}