class NoteEvent {
  const NoteEvent({
    required this.pitch,
    required this.onsetBeat,
    required this.durationName,
    required this.durationBeats,
    required this.amplitude,
  });

  final int pitch;
  final double onsetBeat;
  final String durationName;
  final double durationBeats;
  final double amplitude;

  factory NoteEvent.fromJson(Map<String, dynamic> json) => NoteEvent(
        pitch: json['pitch'] as int,
        onsetBeat: (json['onset_beat'] as num).toDouble(),
        durationName: json['duration_name'] as String,
        durationBeats: (json['duration_beats'] as num).toDouble(),
        amplitude: (json['amplitude'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'pitch': pitch,
        'onset_beat': onsetBeat,
        'duration_name': durationName,
        'duration_beats': durationBeats,
        'amplitude': amplitude,
      };
}
