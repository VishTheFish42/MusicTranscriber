"""
Assembles quantized notes into MusicXML (via music21) and MIDI (via pretty_midi).
"""

import base64
import io
from fractions import Fraction

import music21.stream as m21stream
import music21.note as m21note
import music21.chord as m21chord
import music21.meter as m21meter
import music21.key as m21key
import music21.tempo as m21tempo
import music21.instrument as m21instrument
import music21.clef as m21clef
import pretty_midi

from instruments import Instrument, StaffConfig, Clef
from pipeline.quantize import QuantizedNote


# music21 duration type names match our internal names for most values
_DURATION_MAP: dict[str, str] = {
    "whole":          "whole",
    "dotted_half":    "half",       # dotted handled separately
    "half":           "half",
    "dotted_quarter": "quarter",
    "quarter":        "quarter",
    "dotted_eighth":  "eighth",
    "eighth":         "eighth",
    "dotted_16th":    "16th",
    "16th":           "16th",
    "32nd":           "32nd",
}

_DOTTED: set[str] = {"dotted_half", "dotted_quarter", "dotted_eighth", "dotted_16th"}


def build_musicxml(
    notes: list[QuantizedNote],
    instrument: Instrument,
    tempo: float,
    time_sig: str,
    key_name: str,
) -> str:
    score = m21stream.Score()
    beats_per_bar, _ = map(int, time_sig.split("/"))

    if instrument.staff == StaffConfig.GRAND:
        parts = _build_grand_staff(notes, instrument, tempo, time_sig, key_name, beats_per_bar)
        for p in parts:
            score.append(p)
    else:
        part = _build_single_staff(notes, instrument, tempo, time_sig, key_name, beats_per_bar)
        score.append(part)

    xml_bytes = score.write("musicxml")
    if isinstance(xml_bytes, bytes):
        return xml_bytes.decode("utf-8")
    # write() may return a path; read it back
    with open(str(xml_bytes), "r") as f:
        return f.read()


def build_midi_b64(
    notes: list[QuantizedNote],
    instrument: Instrument,
    tempo: float,
) -> str:
    pm = pretty_midi.PrettyMIDI(initial_tempo=tempo)
    instr_track = pretty_midi.Instrument(program=instrument.midi_program, name=instrument.name)

    quarter_s = 60.0 / tempo
    for n in notes:
        onset_s = n.onset_beat * quarter_s
        offset_s = onset_s + n.duration_beats * quarter_s
        pm_note = pretty_midi.Note(
            velocity=int(n.amplitude * 100),
            pitch=n.pitch,
            start=onset_s,
            end=max(offset_s, onset_s + 0.05),
        )
        instr_track.notes.append(pm_note)

    pm.instruments.append(instr_track)
    buf = io.BytesIO()
    pm.write(buf)
    return base64.b64encode(buf.getvalue()).decode()


def detect_key(notes: list[QuantizedNote]) -> str:
    import music21.analysis.discrete as m21discrete
    stream = m21stream.Stream()
    for n in notes:
        stream.append(m21note.Note(n.pitch))
    key_obj = stream.analyze("key")
    return str(key_obj)


# ── internals ────────────────────────────────────────────────────────────────

def _build_single_staff(
    notes: list[QuantizedNote],
    instrument: Instrument,
    tempo: float,
    time_sig: str,
    key_name: str,
    beats_per_bar: int,
) -> m21stream.Part:
    part = m21stream.Part()
    part.append(_clef_obj(instrument.clef))
    part.append(m21meter.TimeSignature(time_sig))
    part.append(m21key.Key(*_parse_key(key_name)))
    part.append(m21tempo.MetronomeMark(number=tempo))

    _fill_measures(part, notes, beats_per_bar)
    return part


def _build_grand_staff(
    notes: list[QuantizedNote],
    instrument: Instrument,
    tempo: float,
    time_sig: str,
    key_name: str,
    beats_per_bar: int,
) -> list[m21stream.Part]:
    # Split notes at middle C (MIDI 60) for treble/bass assignment
    treble_notes = [n for n in notes if n.pitch >= 60]
    bass_notes   = [n for n in notes if n.pitch < 60]

    treble = m21stream.Part()
    treble.append(m21clef.TrebleClef())
    treble.append(m21meter.TimeSignature(time_sig))
    treble.append(m21key.Key(*_parse_key(key_name)))
    treble.append(m21tempo.MetronomeMark(number=tempo))
    _fill_measures(treble, treble_notes, beats_per_bar)

    bass = m21stream.Part()
    bass.append(m21clef.BassClef())
    bass.append(m21meter.TimeSignature(time_sig))
    bass.append(m21key.Key(*_parse_key(key_name)))
    _fill_measures(bass, bass_notes, beats_per_bar)

    return [treble, bass]


def _fill_measures(part: m21stream.Part, notes: list[QuantizedNote], beats_per_bar: int) -> None:
    if not notes:
        rest = m21note.Rest()
        rest.duration.type = "whole"
        measure = m21stream.Measure()
        measure.append(rest)
        part.append(measure)
        return

    total_beats = max(n.onset_beat + n.duration_beats for n in notes)
    num_measures = max(1, int(total_beats / beats_per_bar) + 1)
    measures = [m21stream.Measure(number=i + 1) for i in range(num_measures)]

    # Group simultaneous notes into chords
    onset_map: dict[float, list[QuantizedNote]] = {}
    for n in notes:
        onset_map.setdefault(round(n.onset_beat, 6), []).append(n)

    for onset_beat, group in sorted(onset_map.items()):
        bar_idx = int(onset_beat / beats_per_bar)
        bar_idx = min(bar_idx, num_measures - 1)
        beat_in_bar = onset_beat - bar_idx * beats_per_bar
        dur_type = _DURATION_MAP.get(group[0].duration_name, "quarter")
        dotted = group[0].duration_name in _DOTTED

        if len(group) == 1:
            el = m21note.Note(group[0].pitch)
        else:
            el = m21chord.Chord([n.pitch for n in group])

        el.duration.type = dur_type
        if dotted:
            el.duration.dots = 1
        el.offset = beat_in_bar
        measures[bar_idx].append(el)

    for m in measures:
        part.append(m)


def _clef_obj(clef: Clef):
    return {
        Clef.TREBLE: m21clef.TrebleClef(),
        Clef.BASS:   m21clef.BassClef(),
        Clef.ALTO:   m21clef.AltoClef(),
        Clef.TENOR:  m21clef.TenorClef(),
    }[clef]


def _parse_key(key_name: str) -> tuple[str, str]:
    """Convert e.g. 'C major' → ('C', 'major'), 'a minor' → ('a', 'minor')."""
    parts = key_name.strip().split()
    if len(parts) == 2:
        return parts[0], parts[1]
    return parts[0], "major"
