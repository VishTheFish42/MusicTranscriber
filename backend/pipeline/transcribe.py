"""
AMT (Automatic Music Transcription) layer.

v1: always polyphonic via Basic Pitch (both piano and guitar).
v2+: branch on instrument.default_mode to add monophonic CREPE/Aubio path.
"""

from dataclasses import dataclass

from basic_pitch.inference import predict
from basic_pitch import ICASSP_2022_MODEL_PATH


@dataclass
class NoteEvent:
    pitch: int
    onset_s: float
    offset_s: float
    amplitude: float


# Minimum confidence thresholds
_ONSET_THRESHOLD = 0.5
_FRAME_THRESHOLD = 0.3
_MIN_NOTE_LEN_MS = 100.0   # milliseconds (Basic Pitch 0.4.0 uses ms, not seconds)


def run_basic_pitch(audio_path: str) -> list[NoteEvent]:
    """
    Run Spotify's Basic Pitch model on a WAV file path.
    Returns a list of NoteEvent sorted by onset time.
    """
    _model_output, _midi_data, note_events = predict(
        audio_path=audio_path,
        model_or_model_path=ICASSP_2022_MODEL_PATH,
        onset_threshold=_ONSET_THRESHOLD,
        frame_threshold=_FRAME_THRESHOLD,
        minimum_note_length=_MIN_NOTE_LEN_MS,
        multiple_pitch_bends=False,
        melodia_trick=True,
    )

    # note_events: List[Tuple[start_s, end_s, pitch, amplitude, pitch_bends]]
    events: list[NoteEvent] = []
    for start_s, end_s, pitch, amplitude, *_ in note_events:
        events.append(
            NoteEvent(
                pitch=int(pitch),
                onset_s=float(start_s),
                offset_s=float(end_s),
                amplitude=float(amplitude),
            )
        )

    events.sort(key=lambda n: n.onset_s)
    return events
