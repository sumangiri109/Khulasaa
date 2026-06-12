import os

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles

from backend.routers import analysis, reports, scorecards

load_dotenv()

app = FastAPI(
    title="Khulasaa API",
    description="Anonymous corruption reporting platform for Nepal",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(reports.router)
app.include_router(scorecards.router)
app.include_router(analysis.router)

static_path = os.path.join(os.path.dirname(__file__), "static")
os.makedirs(static_path, exist_ok=True)

app.mount("/static", StaticFiles(directory=static_path), name="static")


@app.get("/")
def read_root():
    """Serve the web dashboard when it is available."""
    static_index = os.path.join(static_path, "index.html")
    if os.path.exists(static_index):
        return FileResponse(static_index)
    return RedirectResponse(url="/docs")


if __name__ == "__main__":
    import uvicorn

    host = os.getenv("HOST", "127.0.0.1")
    port = int(os.getenv("PORT", 8000))
    print(f"Starting Khulasaa backend server at http://{host}:{port}/")
    uvicorn.run("backend.main:app", host=host, port=port, reload=True)
