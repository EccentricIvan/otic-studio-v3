import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../cloud/cloud_api_settings.dart';
import '../inference/inference_engine.dart';
import '../inference/mock_engine.dart';
import '../inference/ollama_engine.dart';
import '../inference/ollama_model_installer.dart';
import '../inference/openai_compatible_engine.dart';
import '../model/model_manager.dart';
import '../translate/afrislm_model_manager.dart';
import '../translate/translation_pipeline.dart';
import '../tutor/tutor_pipeline.dart';
import '../tutor/tutor_response.dart';
import '../../curriculum/curriculum_provider.dart';
import '../../db/providers/db_provider.dart';
import '../../safety/emotional_safety.dart';

// ── Model status ────────────────────────────────────────────────────────────

final modelManagerProvider = Provider<ModelManager>((ref) => ModelManager());

final modelInfoProvider = FutureProvider<ModelInfo>((ref) {
  // LiteRT-LM runs the same .litertlm chat model on Android, Windows, and
  // Linux — only the browser build has nowhere to run a local model at all.
  if (kIsWeb) {
    return Future.value(const ModelInfo(status: ModelStatus.notInstalled));
  }
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

final translateModelManagerProvider =
    Provider<AfriSlmModelManager>((ref) => AfriSlmModelManager());

final translateModelInfoProvider = FutureProvider<ModelInfo>((ref) {
  if (kIsWeb) {
    return Future.value(const ModelInfo(status: ModelStatus.notInstalled));
  }
  return ref.watch(translateModelManagerProvider).checkModel();
});

/// Null when translation isn't available (web, Android — no engine yet, no
/// model installed, or Ollama isn't reachable) — translation is always a
/// soft-fail feature, never something that blocks the chat itself.
final translateEngineLoadedProvider = FutureProvider<InferenceEngine?>((ref) async {
  if (kIsWeb) return null;

  final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;
  // Android's AfriSLM (llama.cpp) engine isn't implemented yet.
  if (!isDesktop) return null;

  final modelInfo = await ref.watch(translateModelInfoProvider.future);
  if (!modelInfo.isReady) return null;

  try {
    if (!await OllamaEngine.isAvailable()) return null;
    final engine = OllamaEngine(modelTag: afriSlmOllamaTag);
    try {
      await engine.loadModel(modelInfo.path!);
    } on ModelLoadException {
      // Ollama is running but the tag isn't registered yet — this is the
      // normal first-run state for a bundled GGUF (release zip ships the
      // file, not the Ollama registration, since that's machine-local).
      // Register it once from the file we already found, then retry.
      await OllamaModelInstaller().createFromGguf(ggufPath: modelInfo.path!);
      await engine.loadModel(modelInfo.path!);
    }
    ref.onDispose(engine.dispose);
    return engine;
  } catch (_) {
    return null;
  }
});

final translationPipelineProvider = FutureProvider<TranslationPipeline?>((ref) async {
  final engine = await ref.watch(translateEngineLoadedProvider.future);
  if (engine == null) return null;
  return TranslationPipeline(engine);
});

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

    // Student's preferred language — drives transparent translation below.
    // Never blocks: any lookup failure just leaves it as English.
    String studentLanguage = 'en';
    try {
      final student = await ref.read(activeStudentProvider.future);
      studentLanguage = student?.language ?? 'en';
    } catch (_) {}

    // Add user message (shown exactly as typed, in their own language) and
    // lock input immediately, before any await, so a quick second tap can't
    // slip through while the pipeline loads.
    state = AsyncData(current.copyWith(
      messages: [
        ...current.messages,
        ChatMessage(
          text: message,
          isUser: true,
          translatedLanguage: studentLanguage != 'en' ? studentLanguage : null,
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

    // Behind-the-scenes translation: the tutor pipeline (topic detection,
    // curriculum matching, stage tracking) always runs in English. If the
    // student writes in another language, translate their message to
    // English here and translate the reply back below — best-effort, so a
    // translation hiccup degrades to "answer in English" rather than
    // failing the whole turn.
    String englishMessage = message;
    bool translating = false;
    if (studentLanguage != 'en') {
      try {
        final translation = await ref.read(translationPipelineProvider.future);
        if (translation != null) {
          englishMessage = await translation.toEnglish(message, studentLanguage);
          translating = true;
        }
      } catch (_) {
        // Translation unavailable — fall through with the original text.
      }
    }

    // Emotional safety check — crisis messages never reach the model
    final safety = _safetyEngine.check(englishMessage);
    if (safety.bypassTutor) {
      state = AsyncData(state.requireValue.copyWith(
        messages: [
          ...state.requireValue.messages,
          ChatMessage(text: safety.supportMessage!, isUser: false),
        ],
        isGenerating: false,
        streamingText: '',
      ));
      return;
    }

    String streamed = '';
    try {
      final response = await pipeline.respond(
        studentMessage: englishMessage,
        safetyNote: safety.tutorNote,
        onToken: (token) {
          // Never show the raw English stream to a translating student —
          // that would defeat "seamless" by flashing the pre-translation
          // answer for the whole generation. A static placeholder still
          // renders the tutor bubble (via streamingText.isNotEmpty in
          // learn_screen.dart) so the UI doesn't look frozen meanwhile.
          if (translating) {
            if (state.requireValue.streamingText.isEmpty) {
              state = AsyncData(state.requireValue.copyWith(streamingText: 'Translating…'));
            }
            return;
          }
          streamed += token;
          state = AsyncData(state.requireValue.copyWith(streamingText: streamed));
        },
      );

      // Translate the English reply back to the student's language —
      // again best-effort; a failure just shows the English text.
      var displayText = response.text;
      String? displayLanguage;
      if (translating) {
        try {
          final translation = await ref.read(translationPipelineProvider.future);
          if (translation != null) {
            displayText = await translation.fromEnglish(response.text, studentLanguage);
            displayLanguage = studentLanguage;
          }
        } catch (_) {
          // Fall back to the English reply.
        }
      }

      final msgs = List<ChatMessage>.from(state.requireValue.messages)
        ..add(ChatMessage(
          text: displayText,
          isUser: false,
          stage: response.stage,
          followUp: response.followUpPrompt,
          translatedLanguage: displayLanguage,
        ));

      state = AsyncData(state.requireValue.copyWith(
        messages: msgs,
        isGenerating: false,
        streamingText: '',
        clearError: true,
      ));

      // Persist session summary to SQLite after each AI response
      _saveSessionSnapshot(pipeline, response, msgs.length);
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

      // Ask the model to actually summarize the conversation (and spot a
      // strength/weakness) rather than just truncating the latest reply —
      // falls back to truncation if analysis fails or is unavailable.
      final analysis = await pipeline.analyzeSession();
      final summary = analysis.summary.isNotEmpty
          ? analysis.summary
          : (response.text.length > 200
              ? '${response.text.substring(0, 200)}…'
              : response.text);

      await db.sessionDao.saveSession(
        studentId: student.id,
        topic: response.topic,
        summary: summary,
        highestStage: response.stage.name,
        messageCount: msgCount,
      );

      if (analysis.strength != null || analysis.weakness != null) {
        await db.studentDao.addInsight(
          student.id,
          strength: analysis.strength,
          weakness: analysis.weakness,
        );
      }
    } catch (_) {
      // Never crash the chat if DB write fails
    }
  }

  void reset() {
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
  if (raw.contains('Ollama') || raw.contains('11434')) {
    return 'Couldn’t reach Ollama. Start Ollama on this computer, then try again.';
  }
  if (raw.contains('ModelLoadException') || raw.contains('failed to load')) {
    return 'The AI model failed to load. Open Settings to check the model, then try again.';
  }
  if (raw.contains('SocketException') || raw.contains('Connection')) {
    return 'Couldn’t connect to the local AI. Check that the model service is running.';
  }
  return 'Couldn’t get an answer just now. Check your AI model in Settings, then try again.';
}

final chatProvider = AsyncNotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
