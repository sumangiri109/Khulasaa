# Khulasaa

Khulasaa is an anonymous corruption reporting platform focused on Nepal. It lets citizens submit reports without creating a public identity, attach supporting evidence, browse public disclosures, and view district-level trends through scorecards and heatmap data.

The project is built as a FastAPI backend with two frontend surfaces: a static web dashboard served from the backend and a Flutter web/mobile client. It also includes lightweight ML utilities for duplicate detection, confidence scoring, and hotspot clustering.

## Main Features

- Anonymous corruption report submission
- Public report feed with community upvotes
- Evidence upload support for photos, audio, and video
- Institution-level scorecards
- District and hotspot analysis
- Duplicate/spam detection using TF-IDF similarity
- Confidence scoring for escalation-ready reports
- Nightly clustering job for geographic patterns
- Firebase Auth, Firestore, and Storage rule placeholders

## Tech Stack

| Area | Tools |
| --- | --- |
| Backend | Python, FastAPI, Uvicorn |
| Frontend | HTML, CSS, JavaScript, Flutter |
| Data/ML | Pandas, NumPy, scikit-learn |
| Cloud | Firebase Auth, Firestore, Firebase Storage |

## Project Structure

```text
khulasa_project/
  backend/
    main.py
    routers/
      reports.py
      analysis.py
      scorecards.py
    ml/
      spam_filter.py
      confidence_score.py
      clustering.py
    scheduler/
      nightly_job.py
    static/
      index.html
      submit.html
      feed.html
      heatmap.html
      scorecards.html
      admin.html
      app.js
      styles.css
  frontend/
    lib/
      screens/
      services/
    pubspec.yaml
  firebase/
    firestore.rules
    storage.rules
  docs/
    api_reference.md
```

## Running the Backend

Create a virtual environment, install dependencies, and start the API:

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

The static web interface is available at:

```text
http://127.0.0.1:8000/
```

API docs are available at:

```text
http://127.0.0.1:8000/docs
```

## Running the Flutter Client

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## Environment Variables

The backend can use the following values from a `.env` file:

```env
FIREBASE_CREDENTIALS=path/to/serviceAccountKey.json
GOOGLE_MAPS_API_KEY=your_google_maps_key
CIAA_WEBHOOK_URL=https://example.gov.np/report
CONFIDENCE_THRESHOLD=0.75
HOST=127.0.0.1
PORT=8000
```

## API Summary

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `POST` | `/api/reports/submit` | Submit a corruption report |
| `GET` | `/api/reports` | Fetch public reports |
| `POST` | `/api/reports/{id}/upvote` | Upvote a report |
| `GET` | `/api/scorecards` | Fetch institution scorecards |
| `GET` | `/api/analysis/hotspots` | Fetch hotspot data |
| `POST` | `/api/analysis/trigger-nightly` | Manually run clustering and aggregation |

More details are in [docs/api_reference.md](docs/api_reference.md).

## Development Notes

This repository currently uses an in-memory dataset for local development and demonstration. Production deployment should connect the backend to Firestore or another persistent database, validate upload size/type limits, and replace the mock CIAA webhook with an approved integration.

Firebase security rules are included as a starting point and should be reviewed before deployment.
