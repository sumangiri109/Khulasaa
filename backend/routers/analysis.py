from fastapi import APIRouter
from typing import List, Dict, Any
from backend.scheduler import nightly_job

router = APIRouter(prefix="/api/analysis", tags=["Analysis"])

@router.get("/hotspots")
def get_hotspots() -> List[Dict[str, Any]]:
    """Returns geographical K-Means corruption hot spots across Nepal."""
    return nightly_job.cached_hotspots

@router.post("/trigger-nightly")
def trigger_nightly_analysis():
    """Manually forces the midnight processing job (re-runs K-Means and scorecard totals)."""
    success = nightly_job.run_nightly_job()
    return {
        "success": success,
        "message": "Nightly spatial clustering and institutional metrics aggregation completed.",
        "hotspots_count": len(nightly_job.cached_hotspots)
    }
