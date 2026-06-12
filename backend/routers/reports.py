import time
import uuid
import httpx
import os
import base64
import shutil
from fastapi import APIRouter, HTTPException, BackgroundTasks, File, UploadFile
from pydantic import BaseModel, Field
from typing import Optional, List
from backend.ml.spam_filter import spam_filter
from backend.ml.confidence_score import calculate_confidence, is_escalation_eligible
from backend.scheduler import nightly_job

router = APIRouter(prefix="/api/reports", tags=["Reports"])

class ReportSubmission(BaseModel):
    institution: str = Field(..., example="Malpot (Land Revenue)")
    district: str = Field(..., example="Kathmandu")
    description: str = Field(..., min_length=10, example="Officer requested extra cash for signing property deeds.")
    bribeAmount: float = Field(default=0.0, example=5000.0)
    evidenceUrl: Optional[str] = Field(default="", example="https://firebase.storage/evidence.jpg")
    evidencePhoto: Optional[str] = Field(default="")
    evidenceAudio: Optional[str] = Field(default="")
    evidenceVideo: Optional[str] = Field(default="")
    lat: float = Field(..., example=27.7172)
    lng: float = Field(..., example=85.3240)
    isAnonymous: bool = Field(default=True)

class UpvoteResponse(BaseModel):
    id: str
    upvotes: int
    confidence: float
    escalated: bool

# Background task to simulate escalation webhook to CIAA / Police
async def escalate_to_ciaa(report: dict):
    webhook_url = os.getenv("CIAA_WEBHOOK_URL", "https://mock-ciaa-endpoint.gov.np/report")
    print(f"[ESCALATION] CIAA Triggered! Sending Report {report['id']} to {webhook_url} with confidence {report['confidence']}")
    
    payload = {
        "reportId": report["id"],
        "targetOffice": report["institution"],
        "district": report["district"],
        "allegation": report["description"],
        "reportedBribe": report["bribeAmount"],
        "supportingEvidence": report["evidenceUrl"],
        "confidenceRating": report["confidence"],
        "escalationStamp": time.time()
    }
    
    try:
        async with httpx.AsyncClient() as client:
            # We mock the post, catching exceptions since the endpoint is imaginary
            response = await client.post(webhook_url, json=payload, timeout=2.0)
            print(f"[ESCALATION] Webhook response code: {response.status_code}")
    except Exception as e:
        # Gracefully handle since it's a simulated governmental webhook
        print(f"[ESCALATION] Webhook logged internally: {str(e)}")

class Base64Upload(BaseModel):
    filename: str
    base64_data: str

@router.post("/upload")
async def upload_evidence(file: UploadFile = File(...)):
    uploads_dir = os.path.join("backend", "static", "uploads")
    if not os.path.exists(uploads_dir):
        os.makedirs(uploads_dir)
        
    ext = os.path.splitext(file.filename)[1] if file.filename else ".bin"
    # Ensure a fallback extension if splitext is empty or has length 0
    if not ext:
        ext = ".bin"
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(uploads_dir, filename)
    
    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    return {"url": f"/static/uploads/{filename}"}

@router.post("/upload-base64")
async def upload_base64_evidence(payload: Base64Upload):
    uploads_dir = os.path.join("backend", "static", "uploads")
    if not os.path.exists(uploads_dir):
        os.makedirs(uploads_dir)
        
    data = payload.base64_data
    if "," in data:
        data = data.split(",")[1]
        
    binary_data = base64.b64decode(data)
    
    ext = os.path.splitext(payload.filename)[1] if payload.filename else ".bin"
    if not ext:
        ext = ".bin"
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(uploads_dir, filename)
    
    with open(filepath, "wb") as f:
        f.write(binary_data)
        
    return {"url": f"/static/uploads/{filename}"}

@router.post("/submit")
async def submit_report(submission: ReportSubmission, background_tasks: BackgroundTasks):
    # Fetch existing reports for this institution to check duplicates
    same_inst_reports = [
        r["description"] for r in nightly_job.db_reports 
        if r["institution"] == submission.institution
    ]
    
    # 1. Spam & Duplicate Check
    is_duplicate, sim_score = spam_filter.check_duplicate(submission.description, same_inst_reports)
    
    # Generate UID
    report_id = f"rep_{uuid.uuid4().hex[:8]}"
    status = "flagged" if is_duplicate else "validated"
    
    # Prepare base report structure
    new_report = {
        "id": report_id,
        "institution": submission.institution,
        "district": submission.district,
        "description": submission.description,
        "bribeAmount": submission.bribeAmount,
        "evidenceUrl": submission.evidenceUrl,
        "evidencePhoto": submission.evidencePhoto,
        "evidenceAudio": submission.evidenceAudio,
        "evidenceVideo": submission.evidenceVideo,
        "lat": submission.lat,
        "lng": submission.lng,
        "timestamp": time.time(),
        "status": status,
        "upvotes": 0,
        "confidence": 0.0
    }
    
    # 2. Calculate Confidence Score
    corrob_count = len(same_inst_reports)
    confidence = calculate_confidence(new_report, corroborating_count=corrob_count)
    new_report["confidence"] = confidence
    
    # Add to in-memory database
    nightly_job.db_reports.append(new_report)
    
    # 3. CIAA Escalation check
    escalated = False
    if status == "validated" and is_escalation_eligible(confidence):
        escalated = True
        background_tasks.add_task(escalate_to_ciaa, new_report)
        
    return {
        "success": True,
        "id": report_id,
        "status": status,
        "confidence": confidence,
        "is_duplicate": is_duplicate,
        "similarity_score": round(sim_score, 2),
        "escalated": escalated,
        "message": "Report submitted successfully." + (" WARNING: Duplicate similarity detected." if is_duplicate else "")
    }

@router.get("")
def get_reports():
    """Retrieves all reports sorted by timestamp descending."""
    sorted_reports = sorted(nightly_job.db_reports, key=lambda x: x["timestamp"], reverse=True)
    return sorted_reports

@router.post("/{report_id}/upvote", response_model=UpvoteResponse)
def upvote_report(report_id: str, background_tasks: BackgroundTasks):
    """Upvotes a report and dynamically recalculates credibility/escalation eligibility."""
    report = next((r for r in nightly_job.db_reports if r["id"] == report_id), None)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
        
    # Increment upvotes
    report["upvotes"] += 1
    
    # Re-calculate confidence rating
    same_inst_reports_count = len([
        r for r in nightly_job.db_reports 
        if r["institution"] == report["institution"] and r["id"] != report_id
    ])
    
    old_confidence = report["confidence"]
    new_confidence = calculate_confidence(report, corroborating_count=same_inst_reports_count)
    report["confidence"] = new_confidence
    
    # If confidence just crossed threshold, trigger auto-escalation
    escalated = False
    threshold = float(os.getenv("CONFIDENCE_THRESHOLD", 0.75))
    if old_confidence < threshold <= new_confidence and report["status"] == "validated":
        escalated = True
        background_tasks.add_task(escalate_to_ciaa, report)
        
    return {
        "id": report_id,
        "upvotes": report["upvotes"],
        "confidence": new_confidence,
        "escalated": escalated
    }
