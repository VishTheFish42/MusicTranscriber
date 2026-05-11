# MusicTranscriber

A cross-platform mobile app (iOS + Android) that listens to audio — a live instrument performance or an imported recording — and generates sheet music from it.

**Live backend:** `https://musictranscriber-production.up.railway.app`

---

## How it works

1. Select an instrument (Piano or Guitar in v1)
2. Record live audio through the microphone, or import an audio file (WAV, MP3, M4A, OGG, FLAC)
3. Audio is sent to the cloud backend, which runs the transcription pipeline:
   - ffmpeg converts the audio to 22050 Hz mono WAV
   - [Basic Pitch](https://github.com/spotify/basic-pitch) (Spotify) detects notes using its ONNX model
   - librosa detects tempo; notes are snapped to a 1/32nd-note rhythmic grid
   - music21 assembles MusicXML; pretty_midi assembles a MIDI file
4. The app renders the MusicXML as sheet music using [OpenSheetMusicDisplay](https://github.com/opensheetmusicdisplay/opensheetmusicdisplay)
5. Edit notes in-app, play back via MIDI, and export as PDF, MusicXML, or MIDI

---

## Project structure

```
MusicTranscriber/
├── app/                    # Flutter app (iOS + Android)
│   ├── lib/
│   │   ├── app/            # Router and theme
│   │   ├── features/
│   │   │   ├── instrument/ # Instrument model, registry, picker screen
│   │   │   ├── recording/  # Microphone recorder, file importer, recording screen
│   │   │   ├── sheet_music/# OSMD WebView, bridge, editor, playback
│   │   │   ├── transcription/ # API calls, progress screen, state
│   │   │   └── export/     # PDF, MusicXML, MIDI export
│   │   └── shared/         # API client, data models
│   └── assets/osmd/        # Bundled OSMD JS library + HTML wrapper
├── backend/                # FastAPI backend (Python)
│   ├── pipeline/
│   │   ├── preprocess.py   # ffmpeg audio conversion + normalisation
│   │   ├── transcribe.py   # Basic Pitch ONNX inference
│   │   ├── quantize.py     # Tempo detection + rhythm quantisation
│   │   ├── transpose.py    # Instrument transposition (no-op in v1)
│   │   └── assemble.py     # MusicXML (music21) + MIDI (pretty_midi)
│   ├── instruments.py      # Instrument registry
│   ├── routers/            # /transcribe, /regenerate, /export/pdf
│   ├── main.py             # FastAPI app
│   ├── Dockerfile
│   └── requirements.txt
└── specs/                  # Requirements, architecture, and task docs
    ├── REQUIREMENTS.md
    ├── ARCHITECTURE.md
    └── TASKS.md
```

---

## Tech stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter 3.x (Dart) |
| State management | Riverpod 2.x |
| Navigation | go_router |
| HTTP client | Dio |
| Audio recording | flutter_sound |
| Sheet music rendering | OpenSheetMusicDisplay (OSMD) via WebView |
| MIDI playback | flutter_midi_pro |
| Backend framework | FastAPI + Uvicorn |
| AMT model | Basic Pitch (Spotify) — ONNX runtime |
| Audio processing | librosa, ffmpeg |
| Music notation | music21, pretty_midi |
| PDF export | LilyPond |
| Deployment | Railway (Docker) |

---

## Supported instruments

**v1 (current):** Piano, Acoustic Guitar

**v2 (planned):** Violin, Flute, Trumpet, Alto Saxophone, Bass Guitar, Ukulele

**v3 (planned):** Full library of 50+ instruments

Adding a new instrument is a data-only change — one entry in the instrument registry on both the backend and Flutter sides, no pipeline code changes.

---

## Local development

### Backend

**Requirements:** Python 3.11+, ffmpeg, LilyPond

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Health check: `http://localhost:8000/health`

To point the Flutter app at your local backend, run it with:
```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```
(Use `http://10.0.2.2:8000` for the Android emulator.)

### Flutter app

**Requirements:** Flutter 3.41+, Xcode (iOS), Android Studio (Android)

```bash
cd app
flutter pub get
flutter run
```

### Docker (backend)

```bash
cd backend
docker build -t musictranscriber-backend .
docker run -p 8000:8000 musictranscriber-backend
```

---

## API

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/transcribe` | Upload audio, returns MusicXML + MIDI |
| `POST` | `/regenerate` | Re-assemble MusicXML + MIDI from edited note events |
| `POST` | `/export/pdf` | Convert MusicXML to PDF via LilyPond |
| `GET` | `/health` | Health check |

### POST /transcribe

```
Content-Type: multipart/form-data

audio_file:     <binary>
instrument_id:  "piano" | "guitar_acoustic"
tempo_hint:     <int, optional>
time_sig_hint:  "4/4" | "3/4" | ... (optional)
```

Response:
```json
{
  "musicxml": "<MusicXML string>",
  "midi": "<base64-encoded MIDI>",
  "detected_tempo": 120.0,
  "detected_time_sig": "4/4",
  "detected_key": "C major",
  "duration_seconds": 30.5
}
```

---

## Roadmap

See [specs/TASKS.md](specs/TASKS.md) for the full phased task breakdown.

| Phase | Status | Scope |
|---|---|---|
| 1 — Foundation | Complete | Backend pipeline, Flutter scaffold, Railway deployment |
| 2 — Sheet Music & Playback | In progress | OSMD rendering, MIDI playback |
| 3 — Editing & Export | Planned | In-app note editing, PDF/MusicXML/MIDI export |
| 4 — v1 Polish & Submission | Planned | App Store + Google Play |
| 5 — Instrument Expansion | Planned | v2 instruments + monophonic pipeline |
| 6 — Full Library | Planned | 50+ instruments |
