import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api_client.dart';
import '../../shared/models/transcription_result.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// Upload progress 0.0–1.0, null when not uploading
final uploadProgressProvider = StateProvider<double?>((ref) => null);

final transcriptionResultProvider =
    StateProvider<TranscriptionResult?>((ref) => null);
