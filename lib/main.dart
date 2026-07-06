import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await FlutterGemma.initialize(
        inferenceEngines: const [MediaPipeEngine()],
      );
    } catch (e) {
      debugPrint('FlutterGemma init failed: $e');
    }
  }

  runApp(const ProviderScope(child: OticApp()));
}
