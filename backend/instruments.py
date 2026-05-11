from dataclasses import dataclass
from enum import Enum
from typing import Optional


class StaffConfig(str, Enum):
    GRAND = "grand"   # treble + bass (piano)
    SINGLE = "single"  # one staff


class Clef(str, Enum):
    TREBLE = "treble"
    BASS = "bass"
    ALTO = "alto"
    TENOR = "tenor"


class TranscriptionMode(str, Enum):
    MONO = "mono"
    POLY = "poly"


@dataclass(frozen=True)
class Instrument:
    id: str
    name: str
    family: str
    staff: StaffConfig
    clef: Clef
    transpose_interval: int   # semitones: written pitch − concert pitch
    midi_program: int         # 0-indexed General MIDI
    lowest_pitch: int         # MIDI note number
    highest_pitch: int
    default_mode: TranscriptionMode


# v1: piano and guitar only.
# To add an instrument in v2/v3, append an entry here — no pipeline code changes needed.
INSTRUMENTS: dict[str, Instrument] = {
    "piano": Instrument(
        id="piano",
        name="Piano",
        family="Keyboard",
        staff=StaffConfig.GRAND,
        clef=Clef.TREBLE,          # grand staff uses both; clef here is the upper staff
        transpose_interval=0,
        midi_program=0,
        lowest_pitch=21,           # A0
        highest_pitch=108,         # C8
        default_mode=TranscriptionMode.POLY,
    ),
    "guitar_acoustic": Instrument(
        id="guitar_acoustic",
        name="Acoustic Guitar",
        family="Strings",
        staff=StaffConfig.SINGLE,
        clef=Clef.TREBLE,
        transpose_interval=0,      # written at concert pitch in v1; 8vb convention deferred to v3
        midi_program=24,
        lowest_pitch=40,           # E2
        highest_pitch=84,          # C6
        default_mode=TranscriptionMode.POLY,
    ),
}


def get_instrument(instrument_id: str) -> Instrument:
    if instrument_id not in INSTRUMENTS:
        valid = ", ".join(INSTRUMENTS.keys())
        raise ValueError(f"Unknown instrument '{instrument_id}'. Valid: {valid}")
    return INSTRUMENTS[instrument_id]
