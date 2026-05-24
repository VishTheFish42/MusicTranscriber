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

  // Render state
  bool _rendering = true;
  String? _error;
  double _zoom = 1.0;

  // Playback state
  bool _midiLoaded = false;
  bool _isPlaying = false;
  double _midiPosition = 0;
  double _midiDuration = 0;
  bool _isScrubbing = false;
  double _scrubValue = 0;

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
        _bridge.loadMidi(widget.args.result.midiBase64);
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
        // Phase 3 (editing)
        break;
      case OsmdEventType.midiLoaded:
        final dur = (event.payload?['duration'] as num?)?.toDouble() ?? 0;
        if (mounted) setState(() { _midiLoaded = true; _midiDuration = dur; });
      case OsmdEventType.midiPosition:
        if (!_isScrubbing && mounted) {
          final pos = (event.payload?['position'] as num?)?.toDouble() ?? 0;
          setState(() => _midiPosition = pos);
        }
      case OsmdEventType.midiEnded:
        if (mounted) setState(() { _isPlaying = false; _midiPosition = 0; });
    }
  }

  // ── Zoom ──────────────────────────────────────────────────────────────────

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

  // ── Playback ──────────────────────────────────────────────────────────────

  void _togglePlayPause() {
    if (_isPlaying) {
      setState(() => _isPlaying = false);
      _bridge.pauseMidi();
    } else {
      setState(() => _isPlaying = true);
      _bridge.playMidi();
    }
  }

  void _stop() {
    setState(() { _isPlaying = false; _midiPosition = 0; });
    _bridge.stopMidi();
  }

  String _formatTime(double seconds) {
    final s = seconds.toInt();
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
      bottomNavigationBar: _midiLoaded ? _buildPlaybackBar(context) : null,
    );
  }

  Widget _buildPlaybackBar(BuildContext context) {
    final sliderValue = (_isScrubbing ? _scrubValue : _midiPosition)
        .clamp(0.0, _midiDuration > 0 ? _midiDuration : 1.0);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: sliderValue,
                min: 0,
                max: _midiDuration > 0 ? _midiDuration : 1.0,
                onChangeStart: (v) => setState(() {
                  _isScrubbing = true;
                  _scrubValue = v;
                }),
                onChanged: (v) => setState(() => _scrubValue = v),
                onChangeEnd: (v) {
                  setState(() {
                    _isScrubbing = false;
                    _midiPosition = v;
                  });
                  _bridge.seekMidi(v);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      _formatTime(_isScrubbing ? _scrubValue : _midiPosition),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    tooltip: 'Stop',
                    onPressed: _stop,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    iconSize: 36,
                    tooltip: _isPlaying ? 'Pause' : 'Play',
                    onPressed: _togglePlayPause,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 36,
                    child: Text(
                      _formatTime(_midiDuration),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
