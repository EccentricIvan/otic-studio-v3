import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // LiteRT-LM runs the Qwen3-0.6B chat model on Android, Windows, and Linux —
  // one engine, one .litertlm file format, no separate desktop server.
  if (!kIsWeb) {
    try {
      await FlutterGemma.initialize(
        inferenceEngines: const [LiteRtLmEngine()],
      );
    } catch (e) {
      debugPrint('FlutterGemma init failed: $e');
    }
  }

  runApp(const ProviderScope(child: OticApp()));
}
