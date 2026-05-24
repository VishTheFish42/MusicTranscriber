import 'note_event.dart';

class TranscriptionResult {
  const TranscriptionResult({
    required this.musicxml,
    required this.midiBase64,
    required this.detectedTempo,
    required this.detectedTimeSig,
    required this.detectedKey,
    required this.durationSeconds,
    required this.noteEvents,
  });

  final String musicxml;
  final String midiBase64;
  final double detectedTempo;
  final String detectedTimeSig;
  final String detectedKey;
  final double durationSeconds;
  final List<NoteEvent> noteEvents;

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) =>
      TranscriptionResult(
        musicxml: json['musicxml'] as String,
        midiBase64: json['midi'] as String,
        detectedTempo: (json['detected_tempo'] as num).toDouble(),
        detectedTimeSig: json['detected_time_sig'] as String,
        detectedKey: json['detected_key'] as String,
        durationSeconds: (json['duration_seconds'] as num).toDouble(),
        noteEvents: (json['note_events'] as List<dynamic>)
            .map((e) => NoteEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  TranscriptionResult copyWith({
    String? musicxml,
    String? midiBase64,
    double? detectedTempo,
    String? detectedTimeSig,
    String? detectedKey,
    double? durationSeconds,
    List<NoteEvent>? noteEvents,
  }) =>
      TranscriptionResult(
        musicxml: musicxml ?? this.musicxml,
        midiBase64: midiBase64 ?? this.midiBase64,
        detectedTempo: detectedTempo ?? this.detectedTempo,
        detectedTimeSig: detectedTimeSig ?? this.detectedTimeSig,
        detectedKey: detectedKey ?? this.detectedKey,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        noteEvents: noteEvents ?? this.noteEvents,
      );
}
