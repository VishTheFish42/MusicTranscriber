import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:dio/dio.dart';

import '../../features/instrument/instrument_registry.dart';
import '../../features/sheet_music/sheet_music_screen.dart';
import '../../shared/models/transcription_result.dart';
import 'transcription_state.dart';

// Common time signatures offered in the override picker
const _timeSigs = ['2/4', '3/4', '4/4', '6/8', '3/8', '12/8'];

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

      if (mounted) _showOverrideSheet(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _friendlyError(e);
        });
      }
    }
  }

  void _showOverrideSheet(TranscriptionResult result) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (ctx) => _OverrideSheet(
        result: result,
        instrumentId: widget.args.instrumentId,
        onConfirmed: (updated) {
          Navigator.of(ctx).pop();
          context.push(
            '/sheet',
            extra: SheetMusicArgs(
              result: updated,
              instrumentId: widget.args.instrumentId,
            ),
          );
        },
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
    if (e is DioException) {
      // Timeouts
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'Request timed out — try a shorter audio clip.';
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Could not reach the server. Check your internet connection and try again.';
      }
      // Extract the body detail the backend sends
      final data = e.response?.data;
      final detail = (data is Map ? data['detail'] : null)?.toString() ??
          data?.toString();
      if (detail != null) return detail;
    }
    return e.toString();
  }
}

// ── Override sheet ────────────────────────────────────────────────────────────

class _OverrideSheet extends ConsumerStatefulWidget {
  const _OverrideSheet({
    required this.result,
    required this.instrumentId,
    required this.onConfirmed,
  });

  final TranscriptionResult result;
  final String instrumentId;
  final void Function(TranscriptionResult updated) onConfirmed;

  @override
  ConsumerState<_OverrideSheet> createState() => _OverrideSheetState();
}

class _OverrideSheetState extends ConsumerState<_OverrideSheet> {
  late final TextEditingController _tempoCtrl;
  late String _timeSig;
  bool _regenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final bpm = widget.result.detectedTempo.round();
    _tempoCtrl = TextEditingController(text: bpm.toString());
    _timeSig = _canonicalTimeSig(widget.result.detectedTimeSig);
  }

  @override
  void dispose() {
    _tempoCtrl.dispose();
    super.dispose();
  }

  // Normalise whatever the backend returns to one of the offered chips, or
  // fall back to '4/4'.
  String _canonicalTimeSig(String raw) {
    final cleaned = raw.trim();
    return _timeSigs.contains(cleaned) ? cleaned : '4/4';
  }

  bool get _changed {
    final tempo = int.tryParse(_tempoCtrl.text) ?? 0;
    return tempo != widget.result.detectedTempo.round() ||
        _timeSig != _canonicalTimeSig(widget.result.detectedTimeSig);
  }

  void _adjustTempo(int delta) {
    final current = int.tryParse(_tempoCtrl.text) ?? 120;
    final next = (current + delta).clamp(20, 300);
    _tempoCtrl.text = next.toString();
    _tempoCtrl.selection =
        TextSelection.collapsed(offset: _tempoCtrl.text.length);
  }

  Future<void> _confirm() async {
    final tempo = int.tryParse(_tempoCtrl.text) ?? 0;
    if (tempo < 20 || tempo > 300) {
      setState(() => _error = 'Tempo must be between 20 and 300 BPM.');
      return;
    }

    if (!_changed) {
      widget.onConfirmed(widget.result);
      return;
    }

    setState(() { _regenerating = true; _error = null; });

    try {
      final client = ref.read(apiClientProvider);
      final regen = await client.regenerate(
        noteEvents: widget.result.noteEvents,
        instrumentId: widget.instrumentId,
        tempo: tempo.toDouble(),
        timeSig: _timeSig,
        key: widget.result.detectedKey,
      );

      final updated = widget.result.copyWith(
        musicxml: regen.musicxml,
        midiBase64: regen.midiBase64,
        detectedTempo: tempo.toDouble(),
        detectedTimeSig: _timeSig,
      );

      widget.onConfirmed(updated);
    } catch (e) {
      setState(() {
        _regenerating = false;
        _error = 'Could not regenerate the score. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detected = widget.result;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Review Transcription',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Detected key: ${detected.detectedKey}  ·  '
                '${detected.durationSeconds.toStringAsFixed(0)}s',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // ── Tempo ────────────────────────────────────────────────────
              Text('Tempo (BPM)', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StepButton(
                    icon: Icons.remove,
                    onPressed: _regenerating ? null : () => _adjustTempo(-1),
                    onLongPress: _regenerating ? null : () => _adjustTempo(-5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _tempoCtrl,
                      enabled: !_regenerating,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StepButton(
                    icon: Icons.add,
                    onPressed: _regenerating ? null : () => _adjustTempo(1),
                    onLongPress: _regenerating ? null : () => _adjustTempo(5),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Time signature ───────────────────────────────────────────
              Text('Time Signature', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _timeSigs.map((sig) {
                  return ChoiceChip(
                    label: Text(sig),
                    selected: _timeSig == sig,
                    onSelected: _regenerating
                        ? null
                        : (selected) {
                            if (selected) setState(() => _timeSig = sig);
                          },
                  );
                }).toList(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],

              const SizedBox(height: 28),

              // ── Actions ──────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _regenerating ? null : _confirm,
                  child: _regenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_changed
                          ? 'Regenerate & View Sheet Music'
                          : 'View Sheet Music'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onPressed,
    required this.onLongPress,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
        child: Icon(icon),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

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
