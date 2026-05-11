import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../features/instrument/instrument_registry.dart';
import '../../features/sheet_music/sheet_music_screen.dart';
import '../../shared/models/transcription_result.dart';
import 'transcription_state.dart';

class TranscriptionArgs {
  const TranscriptionArgs({
    required this.audioFile,
    required this.instrumentId,
    this.tempoHint,
    this.timeSigHint,
  });

  final File audioFile;
  final String instrumentId;
  final int? tempoHint;
  final String? timeSigHint;
}

class TranscriptionScreen extends ConsumerStatefulWidget {
  const TranscriptionScreen({super.key, required this.args});

  final TranscriptionArgs args;

  @override
  ConsumerState<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends ConsumerState<TranscriptionScreen> {
  String _status = 'Uploading audio…';
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    setState(() {
      _hasError = false;
      _status = 'Uploading audio…';
    });

    try {
      final client = ref.read(apiClientProvider);
      final result = await client.transcribe(
        audioFile: widget.args.audioFile,
        instrumentId: widget.args.instrumentId,
        tempoHint: widget.args.tempoHint,
        timeSigHint: widget.args.timeSigHint,
        onProgress: (progress) {
          ref.read(uploadProgressProvider.notifier).state = progress;
          if (progress >= 1.0 && mounted) {
            setState(() => _status = 'Transcribing… this may take up to 30s');
          }
        },
      );

      ref.read(uploadProgressProvider.notifier).state = null;
      ref.read(transcriptionResultProvider.notifier).state = result;

      if (mounted) _showOverrideDialogOrProceed(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _friendlyError(e);
        });
      }
    }
  }

  void _showOverrideDialogOrProceed(TranscriptionResult result) {
    context.push(
      '/sheet',
      extra: SheetMusicArgs(
        result: result,
        instrumentId: widget.args.instrumentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(uploadProgressProvider);
    final instrument = getInstrumentById(widget.args.instrumentId);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Transcribing ${instrument.name}')),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: _hasError
            ? _ErrorView(
                message: _errorMessage ?? 'An unknown error occurred.',
                onRetry: _run,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 32),
                  Text(_status, textAlign: TextAlign.center),
                  if (progress != null && progress < 1.0) ...[
                    const SizedBox(height: 24),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'Could not reach the server. Check your internet connection and try again.';
    }
    if (msg.contains('422')) {
      return 'No notes were detected in the audio. Try recording in a quieter environment.';
    }
    return 'Something went wrong. Please try again.';
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline,
            size: 56, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(onPressed: onRetry, child: const Text('Try Again')),
      ],
    );
  }
}
