# How to Run Khulasaa

## Requirements

- Python 3.11 or newer
- Flutter SDK
- Firebase project, if you want to connect Firebase services

## Run Backend

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Open the web app:

```text
http://127.0.0.1:8000/
```

Open API docs:

```text
http://127.0.0.1:8000/docs
```

## Run Flutter App

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## Optional Backend Environment

Create `backend/.env` if needed:

```env
FIREBASE_CREDENTIALS=path/to/serviceAccountKey.json
GOOGLE_MAPS_API_KEY=your_google_maps_key
CIAA_WEBHOOK_URL=https://example.gov.np/report
CONFIDENCE_THRESHOLD=0.75
HOST=127.0.0.1
PORT=8000
```
