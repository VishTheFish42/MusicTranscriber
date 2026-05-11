import 'package:go_router/go_router.dart';

import '../features/instrument/instrument_picker_screen.dart';
import '../features/recording/recording_screen.dart';
import '../features/transcription/transcription_screen.dart';

final router = GoRouter(
  initialLocation: '/instrument',
  routes: [
    GoRoute(
      path: '/instrument',
      builder: (context, state) => const InstrumentPickerScreen(),
    ),
    GoRoute(
      path: '/record',
      builder: (context, state) {
        final instrumentId = state.extra as String;
        return RecordingScreen(instrumentId: instrumentId);
      },
    ),
    GoRoute(
      path: '/transcribing',
      builder: (context, state) {
        final args = state.extra as TranscriptionArgs;
        return TranscriptionScreen(args: args);
      },
    ),
  ],
);
