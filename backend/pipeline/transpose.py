"""
Instrument transposition.

Converts concert-pitch note events to written pitch for transposing
instruments (e.g. Bb clarinet, Eb alto sax).

v1: both piano and guitar have transpose_interval=0, so this is a no-op.
v2+: non-zero intervals activate automatically via the instrument registry.
"""

from pipeline.quantize import QuantizedNote
from instruments import Instrument


def apply_transposition(notes: list[QuantizedNote], instrument: Instrument) -> list[QuantizedNote]:
    interval = instrument.transpose_interval
    if interval == 0:
        return notes
    return [
        QuantizedNote(
            pitch=note.pitch + interval,
            onset_beat=note.onset_beat,
            duration_name=note.duration_name,
            duration_beats=note.duration_beats,
            amplitude=note.amplitude,
        )
        for note in notes
    ]
