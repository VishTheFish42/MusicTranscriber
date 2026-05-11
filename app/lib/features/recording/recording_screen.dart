import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/instrument/instrument_registry.dart';
import '../../features/transcription/transcription_screen.dart';
import 'audio_recorder.dart';
import 'file_importer.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final _recorder = AppAudioRecorder();
  bool _isRecording = false;
  double _level = 0.0;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  static const _maxDuration = Duration(minutes: 5);

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndRecord() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (status.isDenied || status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required')),
      );
      return;
    }
    _startRecording();
  }

  Future<void> _startRecording() async {
    await _recorder.start(onLevel: (level) {
      if (mounted) setState(() => _level = level);
    });
    setState(() {
      _isRecording = true;
      _elapsed = Duration.zero;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed >= _maxDuration) _stopAndTranscribe();
    });
  }

  Future<void> _stopAndTranscribe() async {
    _timer?.cancel();
    final file = await _recorder.stop();
    setState(() => _isRecording = false);
    if (file != null && mounted) {
      _goToTranscription(file);
    }
  }

  Future<void> _importFile() async {
    final file = await importAudioFile();
    if (file != null && mounted) {
      _goToTranscription(file);
    }
  }

  void _goToTranscription(File file) {
    context.push(
      '/transcribing',
      extra: TranscriptionArgs(
        audioFile: file,
        instrumentId: widget.instrumentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final instrument = getInstrumentById(widget.instrumentId);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(instrument.name)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LevelMeter(level: _level, isRecording: _isRecording),
            const SizedBox(height: 32),
            if (_isRecording) ...[
              Text(
                _formatDuration(_elapsed),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Max ${_formatDuration(_maxDuration)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _stopAndTranscribe,
                icon: const Icon(Icons.stop),
                label: const Text('Stop & Transcribe'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: _requestPermissionAndRecord,
                icon: const Icon(Icons.mic),
                label: const Text('Start Recording'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _importFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import Audio File'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.level, required this.isRecording});

  final double level;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    final color = isRecording
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.1 + level * 0.5),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(
            isRecording ? Icons.mic : Icons.mic_none,
            size: 36,
            color: color,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: level,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

