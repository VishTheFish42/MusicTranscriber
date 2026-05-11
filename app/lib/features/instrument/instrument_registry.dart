import 'instrument.dart';

// v1: piano and guitar only.
// To add an instrument in v2/v3, append an entry here — no other files change.
const List<Instrument> instrumentRegistry = [
  Instrument(
    id: 'piano',
    name: 'Piano',
    family: 'Keyboard',
    staff: StaffConfig.grand,
    clef: Clef.treble,
    transposeInterval: 0,
    midiProgram: 0,
    lowestMidiPitch: 21,   // A0
    highestMidiPitch: 108, // C8
    defaultMode: TranscriptionMode.poly,
  ),
  Instrument(
    id: 'guitar_acoustic',
    name: 'Acoustic Guitar',
    family: 'Strings',
    staff: StaffConfig.single,
    clef: Clef.treble,
    transposeInterval: 0,
    midiProgram: 24,
    lowestMidiPitch: 40,   // E2
    highestMidiPitch: 84,  // C6
    defaultMode: TranscriptionMode.poly,
  ),
];

Instrument getInstrumentById(String id) {
  return instrumentRegistry.firstWhere(
    (i) => i.id == id,
    orElse: () => throw ArgumentError('Unknown instrument: $id'),
  );
}
