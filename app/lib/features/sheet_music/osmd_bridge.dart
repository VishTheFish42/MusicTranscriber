import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import 'osmd_webview.dart';

/// Typed interface between Dart and the OSMD JavaScript runtime.
///
/// Usage:
///   1. Create an [OsmdBridge] and pass [handleEvent] to [OsmdWebView.onEvent].
///   2. Pass [attach] to [OsmdWebView.onControllerCreated].
///   3. Call [loadScore], [highlightMeasure], etc. at any time — calls made
///      before the page is ready are queued and replayed automatically.
class OsmdBridge {
  OsmdBridge({required this.onEvent});

  /// Forwarded from [OsmdWebView.onEvent]; callers listen here for
  /// rendered/error/noteTapped events.
  final void Function(OsmdEvent event) onEvent;

  WebViewController? _controller;
  bool _ready = false;
  final List<String> _queue = [];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Wire up to [OsmdWebView.onControllerCreated].
  void attach(WebViewController controller) {
    _controller = controller;
  }

  /// Wire up to [OsmdWebView.onEvent].
  void handleEvent(OsmdEvent event) {
    if (event.type == OsmdEventType.ready) {
      _ready = true;
      _flushQueue();
    }
    onEvent(event);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Load and render a MusicXML document.
  /// Fires [OsmdEventType.rendered] on success, [OsmdEventType.error] on failure.
  void loadScore(String musicxml) {
    // JSON-encode so all special characters (quotes, newlines, etc.) are safe
    // to embed directly into the JS call without manual escaping.
    final arg = jsonEncode(musicxml);
    _run('loadScore($arg)');
  }

  /// Move the playback cursor to [measureIndex] (0-based).
  void highlightMeasure(int measureIndex) {
    _run('highlightMeasure($measureIndex)');
  }

  /// Hide the playback cursor.
  void hideCursor() {
    _run('hideCursor()');
  }

  /// Set zoom level (1.0 = 100%). Triggers a re-render inside OSMD.
  void setZoom(double level) {
    _run('setZoom($level)');
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  void _run(String jsExpression) {
    if (_controller == null || !_ready) {
      _queue.add(jsExpression);
      return;
    }
    _controller!.runJavaScript(jsExpression);
  }

  void _flushQueue() {
    for (final call in _queue) {
      _controller?.runJavaScript(call);
    }
    _queue.clear();
  }
}
