from fastapi import APIRouter
from typing import List, Dict, Any
from backend.scheduler import nightly_job

router = APIRouter(prefix="/api/scorecards", tags=["Scorecards"])

@router.get("")
def get_scorecards() -> List[Dict[str, Any]]:
    """Returns a list of all institutional scorecards."""
    return list(nightly_job.db_scorecards.values())
