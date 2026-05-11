import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  runApp(const ProviderScope(child: MusicTranscriberApp()));
}

class MusicTranscriberApp extends StatelessWidget {
  const MusicTranscriberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MusicTranscriber',
      theme: appTheme,
      darkTheme: appDarkTheme,
      routerConfig: router,
    );
  }
}
