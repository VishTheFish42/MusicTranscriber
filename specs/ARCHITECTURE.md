# MusicTranscriber — Architecture & Design

> Related docs: [Requirements](REQUIREMENTS.md) · [Tasks](TASKS.md)

## 1. System Overview

```
┌─────────────────────────────────────────────────────┐
│                  Flutter App (iOS + Android)          │
│  ┌─────────┐  ┌──────────┐  ┌────────────────────┐  │
│  │Recording │  │Instrument│  │  Sheet Music View  │  │
│  │ Module   │  │ Picker   │  │  (OSMD via WebView)│  │
│  └────┬─────┘  └────┬─────┘  └────────┬───────────┘  │
│       │              │                 │               │
│  ┌────▼─────────────▼─────────────────▼───────────┐  │
│  │             Transcription State (Riverpod)       │  │
│  └────────────────────────┬────────────────────────┘  │
│                            │ HTTP (multipart upload)   │
└────────────────────────────┼────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  FastAPI Server  │
                    │   (Python 3.12)  │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        Preprocessing     AMT Engine    MusicXML/MIDI
        (librosa,         (Basic Pitch  Assembly
        ffmpeg)            or CREPE)   (music21)
                                            │
                              ┌─────────────▼──────────┐
                              │      PDF Renderer        │
                              │   (LilyPond subprocess)  │
                              └────────────────────────┘
```

---

## 2. The Instrument Registry (Core Extensibility Principle)

All instrument-specific logic lives in the registry, not in the pipeline code. **Adding a new instrument in v2/v3 is a data-only change** — append an entry to the registry on both the backend and Flutter sides. No pipeline code changes required.

### 2.1 Data Model

```dart
// lib/features/instrument/instrument.dart
class Instrument {
  final String id;               // "piano", "guitar_acoustic"
  final String name;             // "Piano", "Acoustic Guitar"
  final String family;           // "Keyboard", "Strings"
  final StaffConfig staff;       // StaffConfig.grand or StaffConfig.single
  final Clef clef;               // Clef.treble, Clef.bass, Clef.alto, Clef.tenor
  final int transposeInterval;   // semitones: written pitch − concert pitch (0 for v1)
  final int midiProgram;         // 0-indexed General MIDI program
  final int lowestMidiPitch;     // for range validation (v2+)
  final int highestMidiPitch;
  final TranscriptionMode defaultMode; // TranscriptionMode.mono or .poly
}
```

```python
# backend/instruments.py
INSTRUMENTS = {
    "piano": Instrument(
        id="piano", name="Piano", family="Keyboard",
        staff=StaffConfig.GRAND,
        transpose_interval=0, midi_program=0,
        lowest_pitch=21, highest_pitch=108,  # A0–C8
        default_mode="poly",
    ),
    "guitar_acoustic": Instrument(
        id="guitar_acoustic", name="Acoustic Guitar", family="Strings",
        staff=StaffConfig.SINGLE, clef=Clef.TREBLE,
        transpose_interval=0, midi_program=24,
        lowest_pitch=40, highest_pitch=84,   # E2–C6
        default_mode="poly",
    ),
    # v2+ entries appended here — no other files change
}
```

### 2.2 Guitar Transposition Note

Guitar conventionally sounds an octave lower than written. For v1, we write concert pitch and label it guitar — standard practice in digital tools. In v3, an `octave_shift_display` field handles this convention without touching the pipeline.

---

## 3. Flutter App

**Framework**: Flutter 3.x (Dart)  
**State management**: Riverpod 2.x  
**Navigation**: go_router

### 3.1 Directory Structure

```
lib/
├── main.dart
├── app/
│   ├── router.dart
│   └── theme.dart
├── features/
│   ├── recording/
│   │   ├── audio_recorder.dart          # flutter_sound wrapper
│   │   ├── file_importer.dart           # file_picker wrapper
│   │   └── recording_screen.dart
│   ├── instrument/
│   │   ├── instrument.dart              # data model
│   │   ├── instrument_registry.dart     # v1: 2 entries; grows here for v2/v3
│   │   └── instrument_picker_screen.dart  # generic list — works for 2 or 200
│   ├── transcription/
│   │   ├── transcription_service.dart   # HTTP client, upload, poll
│   │   ├── transcription_state.dart     # Riverpod providers
│   │   └── transcription_screen.dart
│   ├── sheet_music/
│   │   ├── sheet_music_screen.dart
│   │   ├── osmd_webview.dart            # WebView hosting OSMD HTML
│   │   ├── osmd_bridge.dart             # Dart ↔ JS message channel
│   │   ├── editor/
│   │   │   ├── note_editor_panel.dart
│   │   │   └── edit_state.dart          # undo/redo command stack
│   │   └── playback/
│   │       ├── midi_player.dart
│   │       └── playback_controls.dart
│   └── export/
│       ├── export_service.dart
│       └── export_sheet.dart
└── shared/
    ├── api_client.dart
    └── models/
        ├── transcription_result.dart
        └── note_event.dart
```

### 3.2 Key Dependencies

| Purpose | Package |
|---|---|
| Audio recording | `flutter_sound` |
| File import | `file_picker` |
| Sheet music rendering | `webview_flutter` + OSMD (JS) |
| MIDI playback | `flutter_midi_pro` |
| HTTP client | `dio` |
| State management | `flutter_riverpod` |
| Navigation | `go_router` |
| File sharing | `share_plus` |
| Permissions | `permission_handler` |

---

## 4. Backend

**Runtime**: Python 3.12  
**Framework**: FastAPI + Uvicorn  
**Deployment**: Railway or Render (Docker container)

### 4.1 API Endpoints

```
POST /transcribe
  Body: multipart/form-data
    audio_file: binary
    instrument_id: string        # "piano" | "guitar_acoustic" (v1)
    tempo_hint: int | null
    time_sig_hint: string | null # "4/4", "3/4", etc.
  Response: {
    musicxml: string,
    midi: string,                # base64-encoded
    detected_tempo: float,
    detected_time_sig: string,
    detected_key: string,
    duration_seconds: float
  }

POST /regenerate
  Body: {
    note_events: [...],
    instrument_id: string,
    tempo: float,
    time_sig: string,
    key: string
  }
  Response: { musicxml: string, midi: string }

POST /export/pdf
  Body: { musicxml: string, paper_size: "a4" | "letter" }
  Response: application/pdf binary

GET /health
  Response: { status: "ok", version: string }
```

### 4.2 Processing Pipeline

```
Audio file received
  │
  ▼
1. PREPROCESS (librosa + ffmpeg)
   - Convert to WAV mono, 22050 Hz
   - Normalize amplitude
   - Noise gate (RMS threshold)
  │
  ▼
2. AMT (Automatic Music Transcription)
   - v1: Basic Pitch (polyphonic) for both piano and guitar
   - v2+: branch on instrument.default_mode
         mono → CREPE + Aubio (pitch + onset detection)
         poly → Basic Pitch
   - Output: note events [pitch, onset_s, offset_s, amplitude]
  │
  ▼
3. TEMPO & METER DETECTION (librosa.beat.beat_track)
   - Estimate BPM (or apply tempo_hint override)
   - Infer time signature (default 4/4)
  │
  ▼
4. RHYTHM QUANTIZATION
   - Compute beat grid at detected tempo
   - Snap onsets/offsets to nearest 1/32nd-note grid
   - Merge near-duplicate notes (within 20ms)
  │
  ▼
5. KEY SIGNATURE DETECTION (music21)
  │
  ▼
6. TRANSPOSITION (instrument registry lookup)
   - v1: transpose_interval = 0 for both instruments — this step is a no-op
   - v2+: applies written-pitch offset for Bb/Eb/F instruments
   - Pipeline stage is wired in v1; no restructuring needed for v2
  │
  ▼
7. MUSICXML ASSEMBLY (music21)
   - Staff config from instrument registry (grand staff for piano, single for guitar)
   - Set clef, key, time sig, tempo, instrument name
  │
  ▼
8. MIDI ASSEMBLY (pretty_midi)
   - GM program from instrument registry
  │
  ▼
9. RETURN { musicxml, midi_b64, tempo, time_sig, key }
```

### 4.3 Infrastructure

```
┌──────────────────────────────────────────┐
│             Railway / Render              │
│  ┌─────────────────────────────────────┐ │
│  │  Docker container (Python 3.12)      │ │
│  │  FastAPI + Uvicorn (2 workers)       │ │
│  │  LilyPond (apt-installed)            │ │
│  │  Basic Pitch model (bundled)         │ │
│  └─────────────────────────────────────┘ │
│  Stateless — audio deleted after response │
└──────────────────────────────────────────┘
```

For v1, synchronous request/response is sufficient. If v2 load warrants it, move to async jobs (Celery + Redis) — the `/transcribe` API shape supports a polling pattern without client-side changes.

---

## 5. Sheet Music Rendering

Flutter has no mature native notation library. **OpenSheetMusicDisplay (OSMD)** — a JavaScript library that renders MusicXML to HTML5 canvas — is the best production-grade option.

- A static `osmd.html` is bundled in Flutter assets
- Loaded in a `WebView` with local assets enabled (no remote content — avoids App Store issues)
- Dart ↔ JS communication via `JavascriptChannel` (`postMessage`)
- OSMD handles all clef/staff variations (grand staff, single staff, etc.) automatically from MusicXML — no Flutter-side clef logic needed

```
Dart side                          JS side (osmd.html)
─────────────────────────────────────────────────────
osmdBridge.loadScore(musicxml)  →  osmd.load(musicxml); osmd.render()
osmdBridge.highlightMeasure(n)  →  move cursor to measure n
← NoteSelected event            ←  user taps note → postMessage(noteData)
```

---

## 6. In-App Editing

Editing operates on an in-memory `List<NoteEvent>` in Dart state. On any change:

1. Update the relevant `NoteEvent`
2. POST updated list to `/regenerate` with current instrument/tempo/key
3. Receive new MusicXML → push to OSMD via bridge

**Undo/redo**: Command pattern. Each edit produces a reversible `EditCommand` pushed onto a stack (max 50; oldest dropped on overflow).

---

## 7. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Rhythm quantization produces unreadable notation | High | Tunable thresholds; user can override tempo and meter before render |
| Basic Pitch inaccurate on guitar (vs piano) | Medium | Guitar is in Basic Pitch training data; test early with real recordings |
| OSMD WebView performance on older Android | Medium | Test on Android API 26; limit initial measures rendered; cache SVG |
| LilyPond PDF generation slow (>5s) | Medium | Make PDF async — return job ID, app polls |
| Audio upload fails on slow connections | Medium | Compress to low-bitrate MP3 before upload; show progress; allow retry |
| Transposition bugs when adding v2 instruments | Medium | Unit test each instrument's transpose_interval against known reference examples |

---

## 8. Open Questions (v3+)

1. **Real-time streaming**: Can Basic Pitch run on 2s audio chunks for live feedback?
2. **Stem separation**: Running Demucs before AMT on mixed recordings — worth the latency cost?
3. **On-device fallback**: Is CREPE small enough via TFLite for offline monophonic transcription?
4. **Chord symbols**: Detect and overlay chord names above the staff for lead-sheet output.
5. **Accounts + history**: Users saving and revisiting transcriptions requires auth and cloud storage.
