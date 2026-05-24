import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Messages the JS side can send back to Dart via OsmdChannel.postMessage().
enum OsmdEventType { ready, rendered, error, noteTapped, midiLoaded, midiPosition, midiEnded }

class OsmdEvent {
  const OsmdEvent({required this.type, this.payload});

  final OsmdEventType type;

  /// Raw decoded JSON map — callers pick out what they need.
  final Map<String, dynamic>? payload;

  static OsmdEvent? tryParse(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final type = switch (map['type'] as String?) {
        'ready'        => OsmdEventType.ready,
        'rendered'     => OsmdEventType.rendered,
        'error'        => OsmdEventType.error,
        'noteTapped'   => OsmdEventType.noteTapped,
        'midiLoaded'   => OsmdEventType.midiLoaded,
        'midiPosition' => OsmdEventType.midiPosition,
        'midiEnded'    => OsmdEventType.midiEnded,
        _              => null,
      };
      if (type == null) return null;
      return OsmdEvent(type: type, payload: map);
    } catch (_) {
      return null;
    }
  }
}

/// A widget that hosts the OSMD HTML page in a WebView.
///
/// Callers receive a [WebViewController] via [onControllerCreated] and
/// listen for JS-side events via [onEvent].
///
/// The controller should not be used until [OsmdEventType.ready] fires.
class OsmdWebView extends StatefulWidget {
  const OsmdWebView({
    super.key,
    required this.onControllerCreated,
    required this.onEvent,
  });

  /// Called once, synchronously after the controller is configured but before
  /// the page has finished loading. Store it; use it only after [onEvent]
  /// delivers [OsmdEventType.ready].
  final void Function(WebViewController controller) onControllerCreated;

  /// Delivers parsed events from the JS side.
  final void Function(OsmdEvent event) onEvent;

  @override
  State<OsmdWebView> createState() => _OsmdWebViewState();
}

class _OsmdWebViewState extends State<OsmdWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'OsmdChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final event = OsmdEvent.tryParse(message.message);
          if (event != null) widget.onEvent(event);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            widget.onEvent(OsmdEvent(
              type: OsmdEventType.error,
              payload: {'message': '${error.description} (${error.errorCode})'},
            ));
          },
        ),
      )
      ..loadFlutterAsset('assets/osmd/index.html');

    widget.onControllerCreated(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
