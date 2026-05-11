# MusicTranscriber — Task Breakdown

> Related docs: [Requirements](REQUIREMENTS.md) · [Architecture](ARCHITECTURE.md)

## Milestone Summary

| Milestone | Phases | Instruments | Target |
|---|---|---|---|
| **v1** | 1–4 | Piano, Guitar | App Store submission |
| **v2** | 5 | + 6 instruments | Instrument expansion update |
| **v3** | 6 | 50+ instruments | Full library update |

---

## Phase 1 — Backend Pipeline, Piano + Guitar (Weeks 1–4)

**Backend**
- [x] B1.1: Set up FastAPI project skeleton with Docker
- [x] B1.2: Implement audio ingestion endpoint (multipart upload, format detection via ffmpeg)
- [x] B1.3: Implement audio preprocessing (resample to 22050 Hz mono, normalize, noise gate)
- [x] B1.4: Integrate Basic Pitch for polyphonic note event extraction
- [x] B1.5: Implement tempo detection and rhythm quantization (1/32nd-note grid snapping)
- [x] B1.6: Implement key signature detection via `music21`
- [x] B1.7: Implement instrument registry with `piano` and `guitar_acoustic` entries
- [x] B1.8: Wire transposition as a no-op pipeline stage (passes through for v1 instruments; required for v2)
- [x] B1.9: Implement MusicXML assembly — grand staff for piano, single treble clef for guitar
- [x] B1.10: Implement MIDI assembly with `pretty_midi`, GM program from registry
- [x] B1.11: Implement `/regenerate` endpoint (note events in → MusicXML + MIDI out)
- [x] B1.12: Deploy to Railway with `/health` check

**Flutter**
- [x] F1.1: Set up Flutter project (Riverpod, go_router, Dio, environment config)
- [x] F1.2: Implement microphone recording screen with real-time level meter
- [x] F1.3: Implement audio file import (file_picker, format validation)
- [x] F1.4: Implement `api_client.dart` — multipart upload with progress callback
- [x] F1.5: Build instrument picker — two-card UI (Piano, Guitar) backed by instrument registry
- [x] F1.6: Build transcription progress screen (upload %, processing spinner, error states)

---

## Phase 2 — Sheet Music & Playback, Piano + Guitar (Weeks 5–8)

- [x] F2.1: Bundle OSMD static HTML in Flutter assets
- [x] F2.2: Implement `osmd_webview.dart` — load local HTML, set up JavaScript channels
- [x] F2.3: Implement `osmd_bridge.dart` — `loadScore()`, `highlightMeasure()`, error handling
- [x] F2.4: Build sheet music screen with zoom and scroll; verify grand staff renders correctly for piano
- [ ] F2.5: Implement MIDI playback with play/pause/stop/scrub controls
- [ ] F2.6: Wire playback position → `highlightMeasure()` in OSMD
- [ ] F2.7: Tempo/time signature override UI (shown after transcription, before final render)

---

## Phase 3 — Editing & Export, Piano + Guitar (Weeks 9–11)

- [ ] F3.1: Note tap detection (JS → Dart via OSMD message channel)
- [ ] F3.2: Note editor bottom panel (pitch, duration, accidental controls)
- [ ] F3.3: Undo/redo command stack (50-step limit)
- [ ] F3.4: Wire edits → `/regenerate` → OSMD re-render
- [ ] B3.1: Implement `/export/pdf` endpoint (music21 → LilyPond → PDF, async with job polling)
- [ ] F3.5: Export bottom sheet with PDF, MusicXML, and MIDI options
- [ ] F3.6: Save to device and share via `share_plus`

---

## Phase 4 — Polish & v1 Submission (Weeks 12–14)

- [ ] F4.1: Onboarding flow (instrument select on first launch)
- [ ] F4.2: App icon and splash screen
- [ ] F4.3: Error states and retry logic (network failure, transcription failure, empty result)
- [ ] F4.4: Accessibility — semantic labels on all interactive elements
- [ ] F4.5: iOS permissions (microphone NSUsageDescription, privacy manifest)
- [ ] F4.6: Android permissions (RECORD_AUDIO, READ_EXTERNAL_STORAGE)
- [ ] B4.1: Rate limiting (10 transcriptions/hour per IP for anonymous users)
- [ ] B4.2: Request logging and error alerting (Sentry)
- [ ] F4.7: Integration tests for the recording → upload → render flow
- [ ] F4.8: App Store submission (screenshots, metadata, review notes)
- [ ] F4.9: Google Play submission

> **v1 ships here.** Piano and Guitar are fully supported.

---

## Phase 5 — Instrument Expansion: v2 (Weeks 15–19)

The pipeline requires no restructuring. All work is additive — new registry entries and a monophonic AMT branch that is already staged.

**Backend**
- [ ] B5.1: Implement monophonic pipeline (CREPE + Aubio) — needed for flute, violin, trumpet
- [ ] B5.2: Branch AMT on `instrument.default_mode` in the pipeline
- [ ] B5.3: Activate transposition logic (apply `transpose_interval` from registry)
- [ ] B5.4: Add v2 instruments to registry:
  - Violin (treble, mono, program 40, transpose 0)
  - Flute (treble, mono, program 73, transpose 0)
  - Trumpet in Bb (treble, mono, program 56, transpose −2)
  - Alto Saxophone in Eb (treble, mono, program 65, transpose −9)
  - Bass Guitar (bass clef, poly, program 33, transpose 0)
  - Ukulele (treble, poly, program 24, transpose 0)
- [ ] B5.5: Pitch range clamping and out-of-range warnings per instrument

**Flutter**
- [ ] F5.1: Add v2 instruments to the Dart instrument registry
- [ ] F5.2: Expose monophonic/polyphonic toggle in UI for applicable instruments
- [ ] F5.3: Update instrument picker layout for 8 instruments (grid or grouped list)
- [ ] F5.4: End-to-end test each new instrument (record, transcribe, render, export)

> **v2 ships here.**

---

## Phase 6 — Full Library: v3 (Weeks 20–26)

- [ ] B6.1: Add remaining instrument registry entries (target: 50+ instruments)
- [ ] B6.2: Handle exotic clefs (alto clef for viola, tenor clef for trombone/bassoon)
- [ ] B6.3: Add `octave_shift_display` field to guitar entry (sounds 8vb, display convention)
- [ ] B6.4: Voice types (soprano, alto, tenor, bass) — pitch range only, no timbre modeling
- [ ] F6.1: Full instrument picker with search bar and family grouping
- [ ] F6.2: Expand Flutter registry to full 50+ instrument library
- [ ] F6.3: Regression test suite across all instrument families

> **v3 ships here.**
