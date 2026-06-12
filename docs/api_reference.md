# Khulasaa API Reference & Machine Learning Pipelines

This document provides a technical guide to the Khulasaa (खुलासा) FastAPI endpoints and the AI/ML backend analytics pipeline.

---

## 1. API Endpoint Reference

All endpoints are hosted by default on `http://127.0.0.1:8000/`. The interactive OpenAPI UI is available at `/docs`.

### A. Reports Endpoint

#### Submit a Report
- **URL:** `POST /api/reports/submit`
- **Headers:** `Content-Type: application/json`
- **Request Body:**
```json
{
  "institution": "Malpot (Land Revenue)",
  "district": "Kathmandu",
  "description": "Bribe demanded for land registration. Desk officer asked for Rs. 5000Mutated desk 3.",
  "bribeAmount": 5000.0,
  "evidenceUrl": "evidence/rep_1/receipt.jpg",
  "lat": 27.7007,
  "lng": 85.3001,
  "isAnonymous": true
}
```
- **Responses:**
  - **200 OK (Clean Report):**
  ```json
  {
    "success": true,
    "id": "rep_a5b6c7",
    "status": "validated",
    "confidence": 0.82,
    "is_duplicate": false,
    "similarity_score": 0.12,
    "escalated": true,
    "message": "Report submitted successfully."
  }
  ```
  - **200 OK (Duplicate/Spam Warn):**
  ```json
  {
    "success": true,
    "id": "rep_f3d2e1",
    "status": "flagged",
    "confidence": 0.15,
    "is_duplicate": true,
    "similarity_score": 0.86,
    "escalated": false,
    "message": "Report submitted successfully. WARNING: Duplicate similarity detected."
  }
  ```

#### Fetch Active Reports
- **URL:** `GET /api/reports`
- **Response:** (Returns list sorted chronologically descending)
```json
[
  {
    "id": "rep_1",
    "institution": "Malpot (Land Revenue)",
    "district": "Kathmandu",
    "description": "Bribe demanded for land registration...",
    "bribeAmount": 5000,
    "evidenceUrl": "evidence/rep_1/receipt.jpg",
    "lat": 27.7007,
    "lng": 85.3001,
    "timestamp": 1780562300.0,
    "status": "validated",
    "upvotes": 12,
    "confidence": 0.82
  }
]
```

#### Upvote a Report
- **URL:** `POST /api/reports/{id}/upvote`
- **Response:** (Recalculates credibility and triggers escalation if passing threshold)
```json
{
  "id": "rep_1",
  "upvotes": 13,
  "confidence": 0.85,
  "escalated": true
}
```

---

### B. Institutional Scorecards Endpoint

#### Get Scorecards
- **URL:** `GET /api/scorecards`
- **Response:**
```json
[
  {
    "institution": "Malpot (Land Revenue)",
    "name_np": "मालपोत कार्यालय",
    "risk_score": 75,
    "total_reports": 3,
    "bribes_sum": 11500,
    "risk_level": "High"
  }
]
```

---

### C. Analysis & Clustering Endpoints

#### Get Hotspots
- **URL:** `GET /api/analysis/hotspots`
- **Response:** (Returns cluster centroid coordinates from nightly job)
```json
[
  {
    "lat": 27.7011,
    "lng": 85.3008,
    "weight": 2,
    "severity": "Moderate",
    "label": "Corruption Hub (2 reports) - Severity: Moderate"
  }
]
```

#### Manually Trigger Nightly Clustering
- **URL:** `POST /api/analysis/trigger-nightly`
- **Response:**
```json
{
  "success": true,
  "message": "Nightly spatial clustering and institutional metrics aggregation completed.",
  "hotspots_count": 2
}
```

---

## 2. Machine Learning Pipeline Architectures

### A. TF-IDF & Cosine Similarity Spam Engine
The submission pipeline parses the description text to check if the complaint is a duplicate.
1. **Normalization:** Strips special marks and extracts both English and Devanagari words.
2. **Vectorization:** Converts the description into numerical vectors based on **Term Frequency-Inverse Document Frequency (TF-IDF)** to analyze semantic weight.
3. **Similarity Equation:**
$$\text{Cosine Similarity} = \frac{\mathbf{A} \cdot \mathbf{B}}{\|\mathbf{A}\| \|\mathbf{B}\|}$$
Where $\mathbf{A}$ represents the incoming report and $\mathbf{B}$ represent each existing report in the target department. If similarity score $\ge 0.70$, it flags it as a duplicate.

### B. Geographic Hotspot Detection (K-Means)
A midnight task groups allegations spatially to trace systematic patterns of bribery.
- **Algorithm:** **K-Means Clustering** computes optimal coordinates to group geographic centroids.
- **Magnitude Weight:** The radius and severity classification of the hotspots expand based on the frequency counts clustered within that district radius.

### C. Confidence Rating Engine
Weighs components to determine total report credibility (0.0 to 1.0):
- **Base Score:** 0.1
- **Evidence Attached:** +0.3 (images/videos validating details)
- **Specificity Details:** +0.2 (length of description)
- **Community Validation:** Up to +0.3 (based on upvote thresholds)
- **Corroboration Weight:** +0.2 (matching target offices in district)
If confidence score reaches **0.75**, it fires a background webhook forwarding the incident particulars directly to the **CIAA (Commission for the Investigation of Abuse of Authority)**.
