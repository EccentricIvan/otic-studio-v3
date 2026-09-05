import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../cloud/cloud_api_settings.dart';
import '../inference/inference_engine.dart';
import '../inference/llama_cpp_engine.dart';
import '../inference/mock_engine.dart';
import '../inference/openai_compatible_engine.dart';
import '../model/bundled_model_bootstrap.dart';
import '../model/model_manager.dart';
import '../translate/afrislm_model_manager.dart';
import '../translate/translation_pipeline.dart';
import '../tutor/tutor_pipeline.dart';
import '../tutor/tutor_response.dart';
import '../tutor/school_math.dart';
import '../../curriculum/curriculum_provider.dart';
import '../../db/providers/db_provider.dart';
import '../../safety/emotional_safety.dart';

// ── Model status ────────────────────────────────────────────────────────────

final modelManagerProvider = Provider<ModelManager>((ref) => ModelManager());

final translateModelManagerProvider =
    Provider<AfriSlmModelManager>((ref) => AfriSlmModelManager());

/// Streams APK-bundled models into app storage once (Android fat APKs).
/// Slim builds and desktop no-op quickly. Chat/translate providers wait on this.
final bundledModelsBootstrapProvider =
    FutureProvider<BundledModelBootstrapResult>((ref) async {
  if (kIsWeb) {
    return const BundledModelBootstrapResult(
      chatReady: false,
      translateReady: false,
      extractedAnything: false,
    );
  }
  final bootstrap = BundledModelBootstrap(
    chatManager: ref.watch(modelManagerProvider),
    translateManager: ref.watch(translateModelManagerProvider),
  );
  return bootstrap.ensureExtracted();
});

final modelInfoProvider = FutureProvider<ModelInfo>((ref) async {
  // LiteRT-LM runs the same .litertlm chat model on Android, Windows, and
  // Linux — only the browser build has nowhere to run a local model at all.
  if (kIsWeb) {
    return const ModelInfo(status: ModelStatus.notInstalled);
  }
  await ref.watch(bundledModelsBootstrapProvider.future);
  return ref.watch(modelManagerProvider).checkModel();
});

// ── Engine lifecycle ─────────────────────────────────────────────────────────

final engineLoadedProvider = FutureProvider<InferenceEngine>((ref) async {
  // Rebuild when cloud API settings are saved.
  ref.watch(cloudApiReloadTickProvider);

  Future<InferenceEngine> demo(DemoReason reason) async {
    final mock = MockEngine(demoReason: reason);
    await mock.loadModel('');
    return mock;
  }

  // Prefer cloud API when the student enables it and pastes a key.
  final cloud = await ref.watch(cloudApiSettingsProvider.future);
  if (cloud.isConfigured) {
    try {
      final engine = OpenAiCompatibleEngine(cloud);
      await engine.loadModel('');
      ref.onDispose(engine.dispose);
      return engine;
    } catch (_) {
      // Fall through to local / demo backends.
    }
  }

  if (kIsWeb) {
    return demo(DemoReason.web);
  }

  // Android/Windows/Linux: on-device Qwen3-0.6B via LiteRT-LM (flutter_gemma).
  final modelInfo = await ref.watch(modelInfoProvider.future);
  if (!modelInfo.isReady) {
    return demo(DemoReason.modelNotInstalled);
  }

  try {
    final engine = createPlatformEngine();
    await engine.loadModel(modelInfo.path!);
    ref.onDispose(engine.dispose);
    return engine;
  } catch (e, st) {
    debugPrint('engineLoadedProvider: local model load failed: $e\n$st');
    return demo(DemoReason.loadFailed);
  }
});

// ── Translation (AfriSLM) ────────────────────────────────────────────────────

final translateModelInfoProvider = FutureProvider<ModelInfo>((ref) async {
  if (kIsWeb) {
    return const ModelInfo(status: ModelStatus.notInstalled);
  }
  await ref.watch(bundledModelsBootstrapProvider.future);
  return ref.watch(translateModelManagerProvider).checkModel();
});

/// Null when translation isn't available (web, no GGUF installed, or
/// llama.cpp failed to load) — translation is always a soft-fail feature,
/// never something that blocks the chat itself.
final translateEngineLoadedProvider = FutureProvider<InferenceEngine?>((ref) async {
  if (kIsWeb) return null;

  final modelInfo = await ref.watch(translateModelInfoProvider.future);
  if (!modelInfo.isReady) return null;

  try {
    final engine = LlamaCppEngineImpl();
    await engine.loadModel(modelInfo.path!);
    ref.onDispose(engine.dispose);
    return engine;
  } catch (e, st) {
    debugPrint('translateEngineLoadedProvider: llama.cpp load failed: $e\n$st');
    return null;
  }
});

final translationPipelineProvider = FutureProvider<TranslationPipeline?>((ref) async {
  final engine = await ref.watch(translateEngineLoadedProvider.future);
  if (engine == null) return null;
  return TranslationPipeline(engine);
});

/// Student's learning-language code (`en` if unknown).
Future<String> studentLanguageCode(Ref ref) async {
  try {
    return (await ref.read(activeStudentProvider.future))?.language ?? 'en';
  } catch (_) {
    return 'en';
  }
}

/// Best-effort: local-language student text → English for the tutor.
Future<String> localizeOutgoing(Ref ref, String text) async {
  final lang = await studentLanguageCode(ref);
  if (lang == 'en' || text.trim().isEmpty) return text;
  try {
    final pipeline = await ref.read(translationPipelineProvider.future);
    if (pipeline == null) return text;
    return await pipeline.toEnglish(text, lang);
  } catch (_) {
    return text;
  }
}

/// Best-effort: English tutor text → student's learning language.
Future<String> localizeIncoming(
  Ref ref,
  String englishText, {
  void Function(String token)? onToken,
}) async {
  final lang = await studentLanguageCode(ref);
  if (lang == 'en' || englishText.trim().isEmpty) return englishText;
  try {
    final pipeline = await ref.read(translationPipelineProvider.future);
    if (pipeline == null) return englishText;
    return await pipeline.fromEnglish(englishText, lang, onToken: onToken);
  } catch (_) {
    return englishText;
  }
}

Future<(String, String)> localizeIncomingPair(
  Ref ref,
  String reply,
  String followUp,
) async {
  return (await localizeIncoming(ref, reply), followUp);
}

/// User-facing AI runtime status (real model vs demo).
class AiStatus {
  const AiStatus({
    required this.isDemo,
    required this.title,
    required this.detail,
    this.backendLabel,
  });

  final bool isDemo;
  final String title;
  final String detail;
  final String? backendLabel;

  factory AiStatus.fromEngine(InferenceEngine engine) {
    if (engine is MockEngine) {
      return AiStatus(
        isDemo: true,
        title: engine.demoReason.title,
        detail: engine.demoReason.detail,
        backendLabel: engine.backendLabel,
      );
    }
    final isCloud = engine.backendLabel.startsWith('Cloud');
    return AiStatus(
      isDemo: false,
      title: isCloud ? 'Cloud AI ready' : 'AI ready',
      detail: isCloud
          ? 'Live answers via ${engine.backendLabel} (needs internet)'
          : 'Using ${engine.backendLabel}',
      backendLabel: engine.backendLabel,
    );
  }
}

final aiStatusProvider = Provider<AsyncValue<AiStatus>>((ref) {
  return ref.watch(engineLoadedProvider).when(
        data: (engine) => AsyncData(AiStatus.fromEngine(engine)),
        loading: () => const AsyncLoading(),
        error: (e, st) => AsyncError(e, st),
      );
});

// ── Tutor pipeline ───────────────────────────────────────────────────────────

final tutorPipelineProvider = FutureProvider<TutorPipeline>((ref) async {
  final engine = await ref.watch(engineLoadedProvider.future);
  final curriculum = ref.watch(curriculumServiceProvider);
  // Load curriculum in background — don't block startup
  curriculum.loadAll();
  return TutorPipeline(engine: engine, curriculum: curriculum);
});

// ── Chat state ───────────────────────────────────────────────────────────────

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isGenerating = false,
    this.streamingText = '',
    this.errorMessage,
  });

  final List<ChatMessage> messages;
  final bool isGenerating;
  final String streamingText;
  final String? errorMessage;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    String? streamingText,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      streamingText: streamingText ?? this.streamingText,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.stage,
    this.followUp,
    this.isError = false,
    this.translatedLanguage,
    this.math,
    this.mathCoach = false,
  });

  final String text;
  final bool isUser;
  final TutorStage? stage;
  final String? followUp;
  final bool isError;

  /// Set when this message was translated for display — the language code
  /// it was translated into (tutor replies) or the language the student
  /// wrote in and that was translated to English behind the scenes (user
  /// messages). Null means no translation was involved.
  final String? translatedLanguage;

  /// Dart-computed worked solution. Formulas stay in English so translation
  /// cannot scramble the arithmetic.
  final SchoolMathSolution? math;
  final bool mathCoach;
}

class ChatNotifier extends AsyncNotifier<ChatState> {
  @override
  Future<ChatState> build() async {
    return const ChatState();
  }

  static const _safetyEngine = EmotionalSafetyEngine();

  void clearError() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearError: true));
  }

  Future<void> send(String message) async {
    final current = state.valueOrNull ?? const ChatState();
    // Don't let a second question queue up before the first is answered —
    // the pipeline's first await (below) can still be pending on the very
    // first message of a session, leaving a window where the send button
    // hasn't disabled yet.
    if (current.isGenerating) return;

    // Add user message (shown exactly as typed) and lock input immediately.
    state = AsyncData(current.copyWith(
      messages: [
        ...current.messages,
        ChatMessage(
          text: message,
          isUser: true,
        ),
      ],
      isGenerating: true,
      streamingText: '',
      clearError: true,
    ));

    final TutorPipeline pipeline;
    try {
      pipeline = await ref.read(tutorPipelineProvider.future);
    } catch (e) {
      state = AsyncData(state.requireValue.copyWith(
        messages: [
          ...state.requireValue.messages,
          ChatMessage(
            text: _friendlyAiError(e),
            isUser: false,
            isError: true,
          ),
        ],
        isGenerating: false,
        streamingText: '',
        errorMessage: _friendlyAiError(e),
      ));
      return;
    }

    var streamBuf = '';
    var lastFlush = DateTime.fromMillisecondsSinceEpoch(0);
    void flushStream({bool force = false}) {
      final now = DateTime.now();
      if (!force && now.difference(lastFlush).inMilliseconds < 40) return;
      lastFlush = now;
      final cur = state.valueOrNull;
      if (cur == null || !cur.isGenerating) return;
      state = AsyncData(cur.copyWith(streamingText: streamBuf));
    }

    void onTok(String token) {
      streamBuf += token;
      flushStream();
    }

    // Behind-the-scenes translation: the tutor pipeline (topic detection,
    // curriculum matching, stage tracking) always runs in English. If the
    // student writes in another language, translate their message to
    // English here and translate the reply back below — best-effort, so a
    // translation hiccup degrades to "answer in English" rather than
    // failing the whole turn. Follow-up prompts are static UI strings
    // (instant) so they are not sent through the translation model.
    final englishMessage = await localizeOutgoing(ref, message);

    // Emotional safety check — crisis messages never reach the model
    final safety = _safetyEngine.check(englishMessage);
    if (safety.bypassTutor) {
      state = AsyncData(state.requireValue.copyWith(
        messages: [
          ...state.requireValue.messages,
          ChatMessage(
            text: await localizeIncoming(ref, safety.supportMessage!),
            isUser: false,
          ),
        ],
        isGenerating: false,
        streamingText: '',
      ));
      return;
    }

    try {
      final response = await pipeline.respond(
        studentMessage: englishMessage,
        safetyNote: safety.tutorNote,
        onToken: onTok,
      );

      var reply = streamBuf.trim().isNotEmpty ? streamBuf : response.text;
      flushStream(force: true);

      final lang = await studentLanguageCode(ref);
      if (lang != 'en' && response.math == null) {
        try {
          reply = await localizeIncoming(ref, reply);
        } catch (_) {}
      }

      final msgs = List<ChatMessage>.from(state.requireValue.messages)
        ..add(ChatMessage(
          text: reply,
          isUser: false,
          stage: response.stage,
          followUp: response.followUpPrompt,
          math: response.math,
          mathCoach: response.mathCoach,
        ));

      state = AsyncData(state.requireValue.copyWith(
        messages: msgs,
        isGenerating: false,
        streamingText: '',
        clearError: true,
      ));

      // Persist session summary after the student already sees the reply.
      unawaited(_saveSessionSnapshot(pipeline, response, msgs.length));
    } catch (e) {
      final friendly = _friendlyAiError(e);
      state = AsyncData(state.requireValue.copyWith(
        messages: [
          ...state.requireValue.messages,
          ChatMessage(text: friendly, isUser: false, isError: true),
        ],
        isGenerating: false,
        streamingText: '',
        errorMessage: friendly,
      ));
    }
  }

  Future<void> _saveSessionSnapshot(
    TutorPipeline pipeline,
    TutorResponse response,
    int msgCount,
  ) async {
    try {
      final student = await ref.read(activeStudentProvider.future);
      if (student == null) return;
      final db = ref.read(dbProvider);

      // Truncate — never call the chat model again here (it queued behind
      // the student's next question and made replies feel stuck).
      final summary = response.text.length > 200
          ? '${response.text.substring(0, 200)}…'
          : response.text;

      await db.sessionDao.saveSession(
        studentId: student.id,
        topic: response.topic,
        summary: summary,
        highestStage: response.stage.name,
        messageCount: msgCount,
      );
    } catch (_) {
      // Never crash the chat if DB write fails
    }
  }

  void reset() {
    ref.read(tutorPipelineProvider).valueOrNull?.reset();
    state = const AsyncData(ChatState());
  }
}

String _friendlyAiError(Object e) {
  final raw = e.toString();
  if (raw.contains('No internet') || raw.contains('SocketException')) {
    return 'No internet for Cloud AI. Connect online, or turn off cloud API in Settings.';
  }
  if (raw.contains('Cloud AI') || raw.contains('api key') || raw.contains('401')) {
    return 'Cloud AI failed. Check your API key and internet in Settings, then try again.';
  }
  if (raw.contains('ModelLoadException') || raw.contains('failed to load')) {
    return 'The AI model failed to load. Open Settings to check the model, then try again.';
  }
  if (raw.contains('SocketException') || raw.contains('Connection')) {
    return 'Couldn’t connect to the local AI. Check the model in Settings, then try again.';
  }
  return 'Couldn’t get an answer just now. Check your AI model in Settings, then try again.';
}

final chatProvider = AsyncNotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
