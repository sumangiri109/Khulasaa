import time
from typing import List, Dict, Any
from backend.ml.clustering import clusterer
from backend.ml.confidence_score import calculate_confidence

# In-memory mock database to ensure it runs out-of-the-box
# in case Firebase credentials aren't set up yet!
db_reports: List[Dict[str, Any]] = [
    {
        "id": "rep_1",
        "institution": "Malpot (Land Revenue)",
        "district": "Kathmandu",
        "description": "Bribe demanded for land registration. The officer refused to sign unless I paid Rs. 5000 in cash.",
        "bribeAmount": 5000,
        "evidenceUrl": "evidence/rep_1/receipt.jpg",
        "evidencePhoto": "https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?q=80&w=600&auto=format&fit=crop",
        "evidenceAudio": "",
        "evidenceVideo": "",
        "lat": 27.7007,
        "lng": 85.3001,
        "timestamp": time.time() - 36000,
        "status": "validated",
        "upvotes": 12,
        "confidence": 0.82
    },
    {
        "id": "rep_2",
        "institution": "Malpot (Land Revenue)",
        "district": "Kathmandu",
        "description": "Malpot desk 4 officer asking for extra service charge under the table. Had to pay 2000 rupees.",
        "bribeAmount": 2000,
        "evidenceUrl": "",
        "evidencePhoto": "",
        "evidenceAudio": "https://www.w3schools.com/html/horse.mp3",
        "evidenceVideo": "",
        "lat": 27.7015,
        "lng": 85.3015,
        "timestamp": time.time() - 25000,
        "status": "validated",
        "upvotes": 5,
        "confidence": 0.55
    },
    {
        "id": "rep_3",
        "institution": "Yatayat (Transport Management)",
        "district": "Lalitpur",
        "description": "Licensing trial examiner asking Rs. 15000 bribe to pass a failed driving license test.",
        "bribeAmount": 15000,
        "evidenceUrl": "evidence/rep_3/video.mp4",
        "evidencePhoto": "",
        "evidenceAudio": "",
        "evidenceVideo": "https://www.w3schools.com/html/mov_bbb.mp4",
        "lat": 27.6710,
        "lng": 85.3240,
        "timestamp": time.time() - 50000,
        "status": "validated",
        "upvotes": 34,
        "confidence": 0.95
    },
    {
        "id": "rep_4",
        "institution": "Nepal Police Office",
        "district": "Bhaktapur",
        "description": "Refusal to file an FIR unless a 'processing fee' of 3000 rupees was provided.",
        "bribeAmount": 3000,
        "evidenceUrl": "",
        "lat": 27.6715,
        "lng": 85.4298,
        "timestamp": time.time() - 72000,
        "status": "validated",
        "upvotes": 2,
        "confidence": 0.45
    },
    {
        "id": "rep_5",
        "institution": "Malpot (Land Revenue)",
        "district": "Kaski",
        "description": "Paying bribe at Pokhara Malpot for standard mutation service.",
        "bribeAmount": 4500,
        "evidenceUrl": "",
        "lat": 28.2096,
        "lng": 83.9856,
        "timestamp": time.time() - 90000,
        "status": "validated",
        "upvotes": 8,
        "confidence": 0.50
    }
]

# Initial institutional scorecards state
db_scorecards: Dict[str, Dict[str, Any]] = {
    "Malpot (Land Revenue)": {
        "institution": "Malpot (Land Revenue)",
        "name_np": "मालपोत कार्यालय",
        "risk_score": 75,
        "total_reports": 3,
        "bribes_sum": 11500,
        "risk_level": "High"
    },
    "Yatayat (Transport Management)": {
        "institution": "Yatayat (Transport Management)",
        "name_np": "यातयात व्यवस्था कार्यालय",
        "risk_score": 90,
        "total_reports": 1,
        "bribes_sum": 15000,
        "risk_level": "Critical"
    },
    "Nepal Police Office": {
        "institution": "Nepal Police Office",
        "name_np": "नेपाल प्रहरी कार्यालय",
        "risk_score": 40,
        "total_reports": 1,
        "bribes_sum": 3000,
        "risk_level": "Medium"
    },
    "Customs Department": {
        "institution": "Customs Department",
        "name_np": "भन्सार विभाग",
        "risk_score": 60,
        "total_reports": 0,
        "bribes_sum": 0,
        "risk_level": "Medium"
    },
    "Internal Revenue Office": {
        "institution": "Internal Revenue Office",
        "name_np": "आन्तरिक राजस्व कार्यालय",
        "risk_score": 30,
        "total_reports": 0,
        "bribes_sum": 0,
        "risk_level": "Low"
    }
}

# In-memory clusters cache
cached_hotspots: List[Dict[str, Any]] = []

def run_nightly_job():
    """
    Executes nightly batch processing.
    1. Re-calculates K-Means geo hotspots.
    2. Recalculates institutional corruption risk scorecards using latest submission statistics.
    3. Re-weighs confidence scores for all reports.
    """
    global cached_hotspots
    print("[Nightly Job] Initiating scheduled analysis...")
    
    # 1. K-Means Clustering on verified reports coordinates
    coords = [{"lat": r["lat"], "lng": r["lng"]} for r in db_reports if r.get("status") == "validated"]
    cached_hotspots = clusterer.detect_hotspots(coords)
    print(f"[Nightly Job] Identified {len(cached_hotspots)} corruption hotspots via K-Means.")

    # 2. Reset / Recalculate scorecards
    for key in db_scorecards.keys():
        db_scorecards[key]["total_reports"] = 0
        db_scorecards[key]["bribes_sum"] = 0

    # Aggregate counts and bribes
    for r in db_reports:
        inst = r.get("institution")
        if inst in db_scorecards:
            db_scorecards[inst]["total_reports"] += 1
            db_scorecards[inst]["bribes_sum"] += r.get("bribeAmount", 0)

    # Re-calculate index scores (scale of 0-100)
    for inst, card in db_scorecards.items():
        count = card["total_reports"]
        bribes = card["bribes_sum"]
        
        if count == 0:
            card["risk_score"] = 15 # baseline risk
            card["risk_level"] = "Low"
            continue
            
        # Risk score formula combining frequency (60%) and bribe weight (40%)
        # frequency log-scaled, bribes capped at 50,000 for index ratio
        freq_factor = min(count * 20, 60)
        bribe_factor = min((bribes / 50000) * 40, 40)
        
        raw_score = freq_factor + bribe_factor
        card["risk_score"] = int(min(raw_score, 100))
        
        if card["risk_score"] >= 80:
            card["risk_level"] = "Critical"
        elif card["risk_score"] >= 60:
            card["risk_level"] = "High"
        elif card["risk_score"] >= 35:
            card["risk_level"] = "Medium"
        else:
            card["risk_level"] = "Low"

    print("[Nightly Job] Re-calculated scorecards for all government bodies.")
    return True

# Initialize hotspots at runtime
run_nightly_job()
