import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'models/transcription_result.dart';
import 'models/note_event.dart';

class RegenerateResult {
  const RegenerateResult({required this.musicxml, required this.midiBase64});

  final String musicxml;
  final String midiBase64;

  factory RegenerateResult.fromJson(Map<String, dynamic> json) =>
      RegenerateResult(
        musicxml: json['musicxml'] as String,
        midiBase64: json['midi'] as String,
      );
}

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://musictranscriber-production.up.railway.app',
);

class ApiClient {
  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120),
    ));
  }

  late final Dio _dio;

  Future<TranscriptionResult> transcribe({
    required File audioFile,
    required String instrumentId,
    int? tempoHint,
    String? timeSigHint,
    void Function(double progress)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'audio_file': await MultipartFile.fromFile(
        audioFile.path,
        filename: p.basename(audioFile.path),
      ),
      'instrument_id': instrumentId,
      if (tempoHint != null) 'tempo_hint': tempoHint.toString(),
      if (timeSigHint != null) 'time_sig_hint': timeSigHint,
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/transcribe',
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );

    return TranscriptionResult.fromJson(response.data!);
  }

  Future<RegenerateResult> regenerate({
    required List<NoteEvent> noteEvents,
    required String instrumentId,
    required double tempo,
    required String timeSig,
    required String key,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/regenerate',
      data: {
        'note_events': noteEvents.map((n) => n.toJson()).toList(),
        'instrument_id': instrumentId,
        'tempo': tempo,
        'time_sig': timeSig,
        'key': key,
      },
    );
    return RegenerateResult.fromJson(response.data!);
  }

  Future<List<int>> exportPdf({
    required String musicxml,
    String paperSize = 'a4',
  }) async {
    final response = await _dio.post<List<int>>(
      '/export/pdf',
      data: {'musicxml': musicxml, 'paper_size': paperSize},
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
  }
}
