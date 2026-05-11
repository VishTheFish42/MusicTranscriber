import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppAudioRecorder {
  final _recorder = FlutterSoundRecorder();
  bool _initialized = false;

  Future<void> start({void Function(double level)? onLevel}) async {
    if (!_initialized) {
      await _recorder.openRecorder();
      _initialized = true;
    }

    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 80));
    _recorder.onProgress?.listen((event) {
      if (event.decibels != null && onLevel != null) {
        // Normalize dB (-60..0) to 0..1
        final normalized = ((event.decibels! + 60) / 60).clamp(0.0, 1.0);
        onLevel(normalized);
      }
    });

    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'recording_${DateTime.now().millisecondsSinceEpoch}.aac');

    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
    );
  }

  Future<File?> stop() async {
    final path = await _recorder.stopRecorder();
    if (path == null) return null;
    return File(path);
  }

  Future<void> dispose() async {
    if (_initialized) {
      await _recorder.closeRecorder();
      _initialized = false;
    }
  }
}
