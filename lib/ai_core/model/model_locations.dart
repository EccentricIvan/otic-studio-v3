import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Folders that may contain `chat-model.litertlm` / `translate-afrislm.gguf`.
///
/// Documents/OTIC is the install target, but a Release zip (and this repo's
/// `dist/models` / `build/.../Release/models`) keeps the files next to the
/// exe. [getApplicationDocumentsDirectory] can also throw on a broken
/// OneDrive Documents folder — that used to abort discovery entirely and
/// surface as "AI check failed".
Future<List<String>> modelCandidateFiles(String fileName) async {
  final seen = <String>{};
  final out = <String>[];

  void addFile(String path) {
    final n = p.normalize(path);
    if (seen.add(n)) out.add(n);
  }

  void addDir(String? dir) {
    if (dir == null || dir.isEmpty) return;
    addFile(p.join(dir, fileName));
    addFile(p.join(dir, 'models', fileName));
    addFile(p.join(dir, 'OTIC', fileName));
    addFile(p.join(dir, 'dist', 'models', fileName));
  }

  try {
    addDir((await getApplicationDocumentsDirectory()).path);
  } catch (e) {
    debugPrint('model_locations: documents dir failed: $e');
  }

  try {
    addDir(p.dirname(Platform.resolvedExecutable));
  } catch (e) {
    debugPrint('model_locations: exe dir failed: $e');
  }

  try {
    addDir(Directory.current.path);
  } catch (_) {}

  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    addDir(p.join(home, 'Documents'));
    addDir(p.join(home, 'Documents', 'OTIC'));
    addDir(p.join(home, 'OneDrive', 'Documents'));
    addDir(p.join(home, 'OneDrive', 'Documents', 'OTIC'));
  }

  return out;
}
