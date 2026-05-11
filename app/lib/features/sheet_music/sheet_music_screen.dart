import 'package:flutter/material.dart';

import '../../features/instrument/instrument_registry.dart';
import '../../shared/models/transcription_result.dart';
import 'osmd_bridge.dart';
import 'osmd_webview.dart';

class SheetMusicArgs {
  const SheetMusicArgs({
    required this.result,
    required this.instrumentId,
  });

  final TranscriptionResult result;
  final String instrumentId;
}

class SheetMusicScreen extends StatefulWidget {
  const SheetMusicScreen({super.key, required this.args});

  final SheetMusicArgs args;

  @override
  State<SheetMusicScreen> createState() => _SheetMusicScreenState();
}

class _SheetMusicScreenState extends State<SheetMusicScreen> {
  late final OsmdBridge _bridge;

  bool _rendering = true;
  String? _error;
  double _zoom = 1.0;

  static const _zoomStep = 0.15;
  static const _zoomMin = 0.5;
  static const _zoomMax = 2.5;

  @override
  void initState() {
    super.initState();
    _bridge = OsmdBridge(onEvent: _onOsmdEvent);
  }

  void _onOsmdEvent(OsmdEvent event) {
    switch (event.type) {
      case OsmdEventType.ready:
        _bridge.loadScore(widget.args.result.musicxml);
      case OsmdEventType.rendered:
        if (mounted) setState(() => _rendering = false);
      case OsmdEventType.error:
        if (mounted) {
          setState(() {
            _rendering = false;
            _error = event.payload?['message'] as String? ?? 'Render failed';
          });
        }
      case OsmdEventType.noteTapped:
        // handled in Phase 3 (editing)
        break;
    }
  }

  void _zoomIn() {
    final next = (_zoom + _zoomStep).clamp(_zoomMin, _zoomMax);
    setState(() => _zoom = next);
    _bridge.setZoom(next);
  }

  void _zoomOut() {
    final next = (_zoom - _zoomStep).clamp(_zoomMin, _zoomMax);
    setState(() => _zoom = next);
    _bridge.setZoom(next);
  }

  @override
  Widget build(BuildContext context) {
    final instrument = getInstrumentById(widget.args.instrumentId);
    final result = widget.args.result;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(instrument.name),
            Text(
              '${result.detectedTempo.toStringAsFixed(0)} BPM  '
              '${result.detectedTimeSig}  '
              '${result.detectedKey}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: 'Zoom out',
            onPressed: _zoom <= _zoomMin ? null : _zoomOut,
          ),
          Text(
            '${(_zoom * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Zoom in',
            onPressed: _zoom >= _zoomMax ? null : _zoomIn,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          OsmdWebView(
            onControllerCreated: _bridge.attach,
            onEvent: _bridge.handleEvent,
          ),
          if (_rendering && _error == null)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_off,
                        size: 48,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      'Could not render sheet music',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
