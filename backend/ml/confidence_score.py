import math
from typing import Dict, Any, List

def calculate_confidence(
    report: Dict[str, Any], 
    corroborating_count: int = 0
) -> float:
    """
    Weighs various features of a report to determine its credibility score (0.0 to 1.0).
    Features weighed:
    1. Evidence Attachment: +0.3 if evidence (image/video URL) is attached.
    2. Specificity and Detail: +0.2 for descriptive, long text indicating rich specificity.
    3. Community Validation (Upvotes): Up to +0.3 (+0.05 per 5 upvotes, capped at 30 upvotes).
    4. Institutional Corroboration: +0.2 if there are other matching complaints for this office.
    
    Base score starts at 0.1 (minimum threshold for valid reporting).
    """
    score = 0.1
    
    # 1. Evidence Attachment (30%)
    evidence_url = report.get("evidenceUrl") or report.get("evidence_url")
    evidence_photo = report.get("evidencePhoto") or report.get("evidence_photo")
    evidence_audio = report.get("evidenceAudio") or report.get("evidence_audio")
    evidence_video = report.get("evidenceVideo") or report.get("evidence_video")
    
    has_evidence = (
        (evidence_url and str(evidence_url).strip() and str(evidence_url).lower() != "none") or
        (evidence_photo and str(evidence_photo).strip() and str(evidence_photo).lower() != "none") or
        (evidence_audio and str(evidence_audio).strip() and str(evidence_audio).lower() != "none") or
        (evidence_video and str(evidence_video).strip() and str(evidence_video).lower() != "none")
    )
    if has_evidence:
        score += 0.30
        
    # 2. Specificity and Word count details (20%)
    description = report.get("description", "")
    word_count = len(description.split())
    if word_count >= 50:
        score += 0.20
    elif word_count >= 20:
        score += 0.10
    elif word_count >= 10:
        score += 0.05
        
    # 3. Community Validation (Upvotes) (30%)
    upvotes = int(report.get("upvotes", 0))
    upvote_bonus = (upvotes // 5) * 0.05
    score += min(upvote_bonus, 0.30)
    
    # 4. Institutional Corroboration (20%)
    # If other citizens are complaining about the same department in the same district
    if corroborating_count > 0:
        corroborate_bonus = min(corroborating_count * 0.05, 0.20)
        score += corroborate_bonus
        
    # Cap score at 1.0 and round to 2 decimal places
    final_score = min(score, 1.0)
    return round(final_score, 2)

def is_escalation_eligible(confidence_score: float, threshold: float = 0.75) -> bool:
    """Returns True if the confidence score exceeds the target threshold."""
    return confidence_score >= threshold
