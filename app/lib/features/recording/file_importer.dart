import 'dart:io';
import 'package:file_picker/file_picker.dart';

const _allowedExtensions = ['wav', 'mp3', 'm4a', 'aac', 'ogg', 'flac'];

Future<File?> importAudioFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: _allowedExtensions,
    withData: false,
    withReadStream: false,
  );

  if (result == null || result.files.isEmpty) return null;
  final path = result.files.first.path;
  if (path == null) return null;
  return File(path);
}
