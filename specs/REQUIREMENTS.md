# MusicTranscriber — Product Requirements

> Related docs: [Architecture](ARCHITECTURE.md) · [Tasks](TASKS.md)

## Release Milestones

| Milestone | Instruments | Goal |
|---|---|---|
| **v1** | Piano, Guitar | Core pipeline working end-to-end; shippable to App Store |
| **v2** | + Violin, Flute, Trumpet, Saxophone, Bass Guitar, Ukulele | Instrument expansion; architecture already supports it |
| **v3** | Full library (50+ instruments) | Long tail — transposing instruments, exotic clefs, voice |

---

## 1. Problem Statement

Musicians need a way to convert audio (live performance or recorded track) into readable sheet music without manual transcription. Existing tools are either desktop-only, expensive, or handle only simple monophonic input.

## 2. Target Users

- Amateur musicians who want to learn songs by ear
- Composers who improvise and want to capture ideas
- Music teachers creating exercises from recordings
- Arrangers transcribing existing recordings

## 3. Functional Requirements

Each requirement is tagged **[v1]**, **[v2]**, or **[v3]** to indicate which milestone it ships in.

### 3.1 Audio Input

- **FR-1** [v1] Record live audio through the device microphone
- **FR-2** [v1] Import audio files from device storage (WAV, MP3, M4A, OGG, FLAC)
- **FR-3** [v1] Configurable recording duration limit (default 5 min)
- **FR-4** [v1] Show real-time audio level meter while recording

### 3.2 Instrument Selection

- **FR-5** [v1] Select instrument from a list: Piano or Guitar
- **FR-6** [v2] Instrument list expands to include Violin, Flute, Trumpet, Saxophone, Bass Guitar, Ukulele
- **FR-7** [v3] Full library of 50+ instruments, searchable and grouped by family
- **FR-8** [v1] Instrument selection configures: staff clef and MIDI program number
- **FR-9** [v2] Instrument selection additionally configures: pitch range filter and transposition interval

### 3.3 Transcription Mode

- **FR-10** [v1] Always run polyphonic mode for v1 (piano and guitar are both polyphonic instruments)
- **FR-11** [v2] Expose monophonic/polyphonic toggle when single-line instruments are added (flute, violin, trumpet)

### 3.4 Transcription

- **FR-12** [v1] Send audio to cloud backend for processing
- **FR-13** [v1] Show processing progress indicator with estimated wait time
- **FR-14** [v1] Auto-detect tempo (BPM), time signature, and key signature
- **FR-15** [v1] Allow user to override detected tempo/time signature before final render
- **FR-16** [v2] Apply instrument-specific transposition for non-concert-pitch instruments (e.g. Bb trumpet, Eb alto sax)

### 3.5 Sheet Music View

- **FR-17** [v1] Render MusicXML notation inline (scrollable, pinch-to-zoom)
- **FR-18** [v1] Highlight the current bar during MIDI playback
- **FR-19** [v1] Display tempo, time signature, key signature, and instrument name in header
- **FR-20** [v1] Piano renders on a grand staff (treble + bass clef)
- **FR-21** [v1] Guitar renders on a single treble clef staff

### 3.6 In-App Editing

- **FR-22** [v1] Tap a note to select it; show pitch, duration, and octave controls
- **FR-23** [v1] Add or delete notes
- **FR-24** [v1] Change note pitch (chromatic semitone up/down) and duration (whole → 32nd)
- **FR-25** [v1] Add/remove accidentals (sharp, flat, natural)
- **FR-26** [v1] Undo/redo (min 50 steps)
- **FR-27** [v1] Changes regenerate the MusicXML and re-render instantly

### 3.7 Playback

- **FR-28** [v1] Play back transcribed MIDI through the device speaker
- **FR-29** [v1] Playback uses the instrument's General MIDI program number
- **FR-30** [v1] Play/pause/stop/scrub controls

### 3.8 Export

- **FR-31** [v1] Export as PDF (print-ready, A4 and Letter)
- **FR-32** [v1] Export as MusicXML (importable into MuseScore, Sibelius, Finale, GarageBand)
- **FR-33** [v1] Export as MIDI
- **FR-34** [v1] Share via iOS Share Sheet / Android Share Intent

## 4. Non-Functional Requirements

- **NFR-1** Transcription latency: < 30s for a 1-minute clip
- **NFR-2** Pitch accuracy: ≥ 75% note-level F1 on clean polyphonic audio (piano benchmark)
- **NFR-3** Supports iOS 15+ and Android API 26+ (Android 8.0+)
- **NFR-4** Works with a minimum of 2G network connection for upload
- **NFR-5** Audio uploaded over HTTPS, deleted from server after processing
- **NFR-6** App installed size: < 60MB

## 5. Out of Scope (v1)

- Real-time streaming transcription
- Lyrics / vocal transcription
- Multi-track / stem separation
- Offline on-device transcription
- Collaboration / cloud save
- Chord symbol detection (lead sheet format)
- Monophonic mode (no single-line instruments in v1)
- Transposing instruments
