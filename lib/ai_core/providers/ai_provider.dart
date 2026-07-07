import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../inference/inference_engine.dart';
import '../inference/mock_engine.dart';
import '../inference/ollama_engine.dart';
import '../model/model_manager.dart';
import '../tutor/tutor_pipeline.dart';
import '../tutor/tutor_response.dart';
import '../../curriculum/curriculum_provider.dart';
import '../../db/providers/db_provider.dart';
import '../../safety/emotional_safety.dart';

// ── Model status ────────────────────────────────────────────────────────────

final modelManagerProvider = Provider<ModelManager>((ref) => ModelManager());

final modelInfoProvider = FutureProvider<ModelInfo>((ref) {
  // Skip model file check on web/desktop — uses Ollama or no AI
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return Future.value(const ModelInfo(status: ModelStatus.notInstalled));
  }
  return ref.watch(modelManagerProvider).checkModel();
});

// ── Engine lifecycle ─────────────────────────────────────────────────────────

final inferenceEngineProvider = Provider<InferenceEngine>((ref) {
  return MockEngine();
});

final engineLoadedProvider = FutureProvider<InferenceEngine>((ref) async {
  final isDesktop = !kIsWeb && (
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS);

  // Web: no AI engine available, use mock
  if (kIsWeb) {
    final mock = MockEngine();
    await mock.loadModel('');
    return mock;
  }

  if (isDesktop) {
    // Desktop: try Ollama first, fall back to mock
    final available = await OllamaEngine.isAvailable();
    if (available) {
      final engine = OllamaEngine();
      await engine.loadModel('');
      ref.onDispose(engine.dispose);
      return engine;
    }
    final mock = MockEngine();
    await mock.loadModel('');
    return mock;
  }

  // Android: use on-device model via flutter_gemma
  final modelInfo = await ref.watch(modelInfoProvider.future);
  if (!modelInfo.isReady) {
    final mock = MockEngine();
    await mock.loadModel('');
    return mock;
  }

  final engine = createPlatformEngine();
  await engine.loadModel(modelInfo.path!);
  ref.onDispose(engine.dispose);
  return engine;
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
  });

  final List<ChatMessage> messages;
  final bool isGenerating;
  final String streamingText;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    String? streamingText,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      streamingText: streamingText ?? this.streamingText,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.stage,
    this.followUp,
  });

  final String text;
  final bool isUser;
  final TutorStage? stage;
  final String? followUp;
}

class ChatNotifier extends AsyncNotifier<ChatState> {
  @override
  Future<ChatState> build() async {
    return const ChatState();
  }

  static const _safetyEngine = EmotionalSafetyEngine();

  Future<void> send(String message) async {
    final current = state.valueOrNull ?? const ChatState();
    // Don't let a second question queue up before the first is answered —
    // the pipeline's first await (below) can still be pending on the very
    // first message of a session, leaving a window where the send button
    // hasn't disabled yet.
    if (current.isGenerating) return;

    // Add user message and lock input immediately, before any await, so
    // a quick second tap can't slip through while the pipeline loads.
    state = AsyncData(current.copyWith(
      messages: [...current.messages, ChatMessage(text: message, isUser: true)],
      isGenerating: true,
      streamingText: '',
    ));

    final pipeline = await ref.read(tutorPipelineProvider.future);

    // Emotional safety check — crisis messages never reach the model
    final safety = _safetyEngine.check(message);
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
        studentMessage: message,
        safetyNote: safety.tutorNote,
        onToken: (token) {
          streamed += token;
          state = AsyncData(state.requireValue.copyWith(streamingText: streamed));
        },
      );

      final msgs = List<ChatMessage>.from(state.requireValue.messages)
        ..add(ChatMessage(
          text: response.text,
          isUser: false,
          stage: response.stage,
          followUp: response.followUpPrompt,
        ));

      state = AsyncData(state.requireValue.copyWith(
        messages: msgs,
        isGenerating: false,
        streamingText: '',
      ));

      // Persist session summary to SQLite after each AI response
      _saveSessionSnapshot(response, msgs.length);
    } catch (e) {
      state = AsyncData(state.requireValue.copyWith(
        isGenerating: false,
        streamingText: '',
      ));
    }
  }

  Future<void> _saveSessionSnapshot(TutorResponse response, int msgCount) async {
    try {
      final student = await ref.read(activeStudentProvider.future);
      if (student == null) return;
      final db = ref.read(dbProvider);
      await db.sessionDao.saveSession(
        studentId: student.id,
        topic: response.topic,
        summary: response.text.length > 200
            ? '${response.text.substring(0, 200)}…'
            : response.text,
        highestStage: response.stage.name,
        messageCount: msgCount,
      );
    } catch (_) {
      // Never crash the chat if DB write fails
    }
  }

  void reset() {
    state = const AsyncData(ChatState());
  }
}

final chatProvider = AsyncNotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
