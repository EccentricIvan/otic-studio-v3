import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await FlutterGemma.initialize(
      inferenceEngines: const [MediaPipeEngine()],
    );
  }

  runApp(const ProviderScope(child: OticApp()));
}
