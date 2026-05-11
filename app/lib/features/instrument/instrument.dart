enum StaffConfig { grand, single }

enum Clef { treble, bass, alto, tenor }

enum TranscriptionMode { mono, poly }

class Instrument {
  const Instrument({
    required this.id,
    required this.name,
    required this.family,
    required this.staff,
    required this.clef,
    required this.transposeInterval,
    required this.midiProgram,
    required this.lowestMidiPitch,
    required this.highestMidiPitch,
    required this.defaultMode,
  });

  final String id;
  final String name;
  final String family;
  final StaffConfig staff;
  final Clef clef;

  /// Semitones: written pitch − concert pitch.
  /// 0 for v1 instruments; non-zero activates transposition in v2+.
  final int transposeInterval;

  /// 0-indexed General MIDI program number.
  final int midiProgram;

  final int lowestMidiPitch;
  final int highestMidiPitch;
  final TranscriptionMode defaultMode;
}
