from fastapi import FastAPI

app = FastAPI(title="Kyoto_Subway")

@app.get("/")
def root():
    return {"message": "Kyoto_Subway API is running"}