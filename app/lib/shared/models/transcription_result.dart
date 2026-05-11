class TranscriptionResult {
  const TranscriptionResult({
    required this.musicxml,
    required this.midiBase64,
    required this.detectedTempo,
    required this.detectedTimeSig,
    required this.detectedKey,
    required this.durationSeconds,
  });

  final String musicxml;
  final String midiBase64;
  final double detectedTempo;
  final String detectedTimeSig;
  final String detectedKey;
  final double durationSeconds;

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) =>
      TranscriptionResult(
        musicxml: json['musicxml'] as String,
        midiBase64: json['midi'] as String,
        detectedTempo: (json['detected_tempo'] as num).toDouble(),
        detectedTimeSig: json['detected_time_sig'] as String,
        detectedKey: json['detected_key'] as String,
        durationSeconds: (json['duration_seconds'] as num).toDouble(),
      );
}
