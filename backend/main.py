from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import transcribe, export

app = FastAPI(title="MusicTranscriber API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten in production
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(transcribe.router)
app.include_router(export.router)


@app.get("/health")
def health():
    return {"status": "ok", "version": app.version}
