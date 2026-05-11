"""
Rhythm quantization: snaps raw note events from the AMT model onto a
musical grid derived from tempo detection.

The smallest grid unit is a 1/32nd note. Onsets are snapped to the
nearest grid point; durations are quantized to the nearest standard
note value (whole through 32nd, including dotted values).
"""

from dataclasses import dataclass, replace

import librosa
import numpy as np

from pipeline.transcribe import NoteEvent


# Supported note durations as fractions of a whole note, ordered longest → shortest.
# Dotted values are included to keep quantization faithful to actual rhythms.
_NOTE_VALUES: list[tuple[float, str]] = [
    (1.0,     "whole"),
    (0.75,    "dotted_half"),
    (0.5,     "half"),
    (0.375,   "dotted_quarter"),
    (0.25,    "quarter"),
    (0.1875,  "dotted_eighth"),
    (0.125,   "eighth"),
    (0.09375, "dotted_16th"),
    (0.0625,  "16th"),
    (0.03125, "32nd"),
]


@dataclass
class QuantizedNote:
    pitch: int
    onset_beat: float       # beat position (quarter-note beats from bar 1, beat 1)
    duration_name: str      # e.g. "quarter", "dotted_eighth"
    duration_beats: float   # duration in quarter-note beats
    amplitude: float


def detect_tempo(samples: np.ndarray, sample_rate: int, tempo_hint: int | None) -> float:
    if tempo_hint is not None:
        return float(tempo_hint)
    tempo, _ = librosa.beat.beat_track(y=samples, sr=sample_rate, units="time")
    # librosa may return an array; take the scalar
    return float(np.atleast_1d(tempo)[0])


def quantize(
    events: list[NoteEvent],
    samples: np.ndarray,
    sample_rate: int,
    tempo_hint: int | None,
    time_sig_hint: str | None,
) -> tuple[list[QuantizedNote], float, str]:
    """
    Returns (quantized_notes, tempo_bpm, time_signature_string).
    """
    tempo = detect_tempo(samples, sample_rate, tempo_hint)
    time_sig = time_sig_hint or "4/4"
    beats_per_bar, beat_unit = _parse_time_sig(time_sig)

    quarter_duration_s = 60.0 / tempo
    # Grid resolution: 1/32nd note = quarter / 8
    grid_s = quarter_duration_s / 8.0

    quantized: list[QuantizedNote] = []
    for ev in events:
        onset_beat = _snap_to_grid(ev.onset_s, grid_s, quarter_duration_s)
        raw_duration_beats = (ev.offset_s - ev.onset_s) / quarter_duration_s
        dur_name, dur_beats = _nearest_note_value(raw_duration_beats, quarter_duration_s)
        # Ensure note doesn't extend past a reasonable minimum
        if dur_beats < 0.03125:
            continue
        quantized.append(
            QuantizedNote(
                pitch=ev.pitch,
                onset_beat=onset_beat,
                duration_name=dur_name,
                duration_beats=dur_beats,
                amplitude=ev.amplitude,
            )
        )

    quantized = _merge_duplicates(quantized)
    return quantized, tempo, time_sig


def _parse_time_sig(ts: str) -> tuple[int, int]:
    parts = ts.split("/")
    return int(parts[0]), int(parts[1])


def _snap_to_grid(time_s: float, grid_s: float, quarter_s: float) -> float:
    grid_steps = round(time_s / grid_s)
    snapped_s = grid_steps * grid_s
    return snapped_s / quarter_s   # convert to quarter-note beats


def _nearest_note_value(duration_beats: float, quarter_s: float) -> tuple[str, float]:
    best_name, best_val, best_dist = "32nd", 0.03125, float("inf")
    for fraction, name in _NOTE_VALUES:
        dist = abs(duration_beats - fraction * 4)   # fraction is of whole note; whole = 4 beats
        if dist < best_dist:
            best_dist = dist
            best_name = name
            best_val = fraction * 4
    return best_name, best_val


def _merge_duplicates(notes: list[QuantizedNote], tol: float = 0.01) -> list[QuantizedNote]:
    """Remove notes that share onset and pitch within tolerance (AMT artefacts)."""
    seen: set[tuple[int, float]] = set()
    out: list[QuantizedNote] = []
    for n in notes:
        key = (n.pitch, round(n.onset_beat / tol) * tol)
        if key not in seen:
            seen.add(key)
            out.append(n)
    return out
