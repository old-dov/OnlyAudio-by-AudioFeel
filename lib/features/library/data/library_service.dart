import 'dart:io';

import 'package:file_picker/file_picker.dart';

class LibraryService {
  static const supportedExtensions = {
    '.mp3',
    '.wav',
    '.flac',
    '.ogg',
    '.m4a',
    '.aac',
  };

  Future<List<String>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions:
          supportedExtensions.map((e) => e.replaceFirst('.', '')).toList(),
    );
    if (result == null) return [];
    return result.paths.whereType<String>().toList();
  }

  Future<List<String>> pickFolderAndScan() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return [];
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((path) => supportedExtensions.any(path.toLowerCase().endsWith))
        .toList()
      ..sort();
    return files;
  }
}
