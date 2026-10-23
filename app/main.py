from fastapi import FastAPI

from app.api.urls import router

app = FastAPI(
    title="URL Shortener",
    version="1.0.0",
)

app.include_router(router)


@app.get("/health")
def health_check():
    return {"status": "ok"}