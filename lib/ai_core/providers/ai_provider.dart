import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../cloud/cloud_api_settings.dart';
import '../inference/dual_model_stream.dart';
import '../inference/inference_engine.dart';
import '../inference/llama_cpp_engine.dart';
import '../inference/mock_engine.dart';
import '../inference/openai_compatible_engine.dart';
import '../model/bundled_model_bootstrap.dart';
import '../model/model_manager.dart';
import '../translate/afrislm_model_manager.dart';
import '../translate/drift_translation_store.dart';
import '../translate/translation_pipeline.dart';
import '../translate/translation_quality.dart';
import '../tutor/tutor_pipeline.dart';
import '../tutor/tutor_response.dart';
import '../tutor/school_math.dart';
import '../tutor/school_math_l10n.dart';
import '../../curriculum/curriculum_provider.dart';
import '../../l10n/app_locale.dart';
import '../../l10n/language_provider.dart';
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
  try {
    final bootstrap = BundledModelBootstrap(
      chatManager: ref.watch(modelManagerProvider),
      translateManager: ref.watch(translateModelManagerProvider),
    );
    return await bootstrap.ensureExtracted();
  } catch (e, st) {
    debugPrint('bundledModelsBootstrapProvider failed: $e\n$st');
    return const BundledModelBootstrapResult(
      chatReady: false,
      translateReady: false,
      extractedAnything: false,
      error: 'bootstrap failed',
    );
  }
});

final modelInfoProvider = FutureProvider<ModelInfo>((ref) async {
  // LiteRT-LM runs the same .litertlm chat model on Android, Windows, and
  // Linux — only the browser build has nowhere to run a local model at all.
  if (kIsWeb) {
    return const ModelInfo(status: ModelStatus.notInstalled);
  }
  try {
    final bootstrap = await ref.watch(bundledModelsBootstrapProvider.future);
    // Served straight from the APK - there is no file on disk to stat, and
    // deliberately so: extracting one would store the same ~600 MB twice.
    if (bootstrap.chatBundledInApk) {
      return const ModelInfo(
        status: ModelStatus.ready,
        path: ModelManager.bundledChatModelPath,
        platform: 'Android (LiteRT-LM, in APK)',
      );
    }
    return ref.watch(modelManagerProvider).checkModel();
  } catch (e, st) {
    debugPrint('modelInfoProvider failed: $e\n$st');
    return const ModelInfo(status: ModelStatus.notInstalled);
  }
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

  try {
    return await _loadEngine(ref, demo);
  } catch (e, st) {
    debugPrint('engineLoadedProvider failed: $e\n$st');
    return demo(DemoReason.loadFailed);
  }
});

Future<InferenceEngine> _loadEngine(
  Ref ref,
  Future<InferenceEngine> Function(DemoReason reason) demo,
) async {
  // Prefer cloud API when the student enables it and pastes a key.
  CloudApiConfig cloud;
  try {
    cloud = await ref.watch(cloudApiSettingsProvider.future);
  } catch (e) {
    debugPrint('cloudApiSettingsProvider failed: $e');
    cloud = const CloudApiConfig();
  }
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
    // Reading the model in place out of the APK is the memory-cheap path
    // but depends on the native runtime accepting an asset file
    // descriptor. If it refuses, fall back to a real file - that costs a
    // second ~600 MB on disk, so it only happens after an in-place load
    // has actually failed.
    if (modelInfo.path == ModelManager.bundledChatModelPath) {
      try {
        final path = await BundledModelBootstrap(
          chatManager: ref.watch(modelManagerProvider),
          translateManager: ref.watch(translateModelManagerProvider),
        ).materializeChatModel();
        final engine = createPlatformEngine();
        await engine.loadModel(path);
        ref.onDispose(engine.dispose);
        return engine;
      } catch (_) {
        // Fall through to demo mode below.
      }
    }
    return demo(DemoReason.loadFailed);
  }
}

// ── Translation (AfriSLM) ────────────────────────────────────────────────────

final translateModelInfoProvider = FutureProvider<ModelInfo>((ref) async {
  if (kIsWeb) {
    return const ModelInfo(status: ModelStatus.notInstalled);
  }
  try {
    await ref.watch(bundledModelsBootstrapProvider.future);
    return ref.watch(translateModelManagerProvider).checkModel();
  } catch (e, st) {
    debugPrint('translateModelInfoProvider failed: $e\n$st');
    return const ModelInfo(status: ModelStatus.notInstalled);
  }
});

/// Null when translation isn't available (web, no GGUF installed, or
/// llama.cpp failed to load) — translation is always a soft-fail feature,
/// never something that blocks the chat itself.
final translateEngineLoadedProvider = FutureProvider<InferenceEngine?>((ref) async {
  if (kIsWeb) return null;

  final modelInfo = await ref.watch(translateModelInfoProvider.future);
  if (!modelInfo.isReady) {
    // Silent until now, and the likeliest reason replies come back in
    // English: the GGUF is still the one model extracted on first launch.
    debugPrint(
      'TRANSLATION OFF: translate model not ready '
      '(status=${modelInfo.status}, path=${modelInfo.path}).',
    );
    return null;
  }

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

  // The cache is keyed per model file, so a re-quantized or upgraded GGUF
  // misses rather than serving rows the previous model wrote.
  final modelInfo = await ref.watch(translateModelInfoProvider.future);
  final modelTag = modelInfo.path == null
      ? 'unknown'
      : modelTagFor(
          path: modelInfo.path!,
          sizeBytes: modelInfo.sizeBytes ?? 0,
        );

  return TranslationPipeline(
    engine,
    store: kIsWeb ? null : DriftTranslationStore(ref.watch(dbProvider)),
    modelTag: modelTag,
  );
});

/// Student's learning-language code (`en` if unknown).
///
/// Returning 'en' short-circuits every translation call before the pipeline
/// is even consulted, so a null student (guest, or a profile that has not
/// loaded yet when the first message lands) looks exactly like "translation
/// is broken" from the outside. Log what actually resolved.
///
/// An explicit in-session choice ([languageOverrideProvider]) wins over the
/// stored profile — that is the only way a guest gets a language at all, and
/// it means the model routing agrees with the labels on screen the instant
/// the picker moves, without waiting on the DB write.
///
/// Stays async even though [appLanguageProvider] is synchronous: awaiting the
/// profile is what stops the *first* message of a session being sent
/// untranslated because the student row had not loaded yet.
Future<String> studentLanguageCode(Ref ref) async {
  final override = ref.read(languageOverrideProvider);
  if (override != null) return override;
  try {
    final student = await ref.read(activeStudentProvider.future);
    if (student == null) {
      debugPrint('TRANSLATION OFF: no active student, defaulting to English.');
      return 'en';
    }
    return student.language;
  } catch (e) {
    debugPrint('TRANSLATION OFF: could not read active student: $e');
    return 'en';
  }
}

/// Best-effort: local-language student text → English for the tutor.
///
/// Pass [langCode] when the caller has already resolved the language for this
/// turn, so one exchange cannot be read in one language and answered in
/// another if the student switches mid-generation.
Future<String> localizeOutgoing(Ref ref, String text, {String? langCode}) async {
  final lang = langCode ?? await studentLanguageCode(ref);
  if (lang == 'en' || text.trim().isEmpty) return text;
  try {
    final pipeline = await ref.read(translationPipelineProvider.future);
    if (pipeline == null) {
      debugPrint('TRANSLATION OFF: no pipeline (in: $lang -> en).');
      return text;
    }
    return await pipeline.toEnglish(text, lang);
  } catch (e) {
    debugPrint('TRANSLATION FAILED (in: $lang -> en): $e');
    return text;
  }
}

/// [localizeIncoming] with the outcome attached, so a caller can tell a real
/// translation from a fallback to English.
///
/// The plain [localizeIncoming] cannot: it returns a String either way, and
/// that ambiguity is exactly how a failed translation used to reach students
/// looking like a working one. Chat uses this; screens that have nowhere to
/// show the distinction keep the simpler wrapper.
Future<TranslationOutcome> localizeIncomingDetailed(
  Ref ref,
  String englishText, {
  TokenCallback? onToken,
  String? langCode,
}) async {
  final lang = langCode ?? await studentLanguageCode(ref);
  if (lang == 'en' || englishText.trim().isEmpty) {
    return TranslationOutcome.passthrough(englishText);
  }
  try {
    final pipeline = await ref.read(translationPipelineProvider.future);
    if (pipeline == null) {
      debugPrint('TRANSLATION OFF: no pipeline (out: en -> $lang).');
      return TranslationOutcome(
        text: englishText,
        translated: false,
        failure: 'translation model unavailable',
      );
    }
    return await pipeline.fromEnglishDetailed(
      englishText,
      lang,
      onToken: onToken,
    );
  } catch (e) {
    debugPrint('TRANSLATION FAILED (out: en -> $lang): $e');
    return TranslationOutcome(
      text: englishText,
      translated: false,
      failure: '$e',
    );
  }
}

/// Best-effort: English tutor text → student's learning language.
Future<String> localizeIncoming(
  Ref ref,
  String englishText, {
  TokenCallback? onToken,
  String? langCode,
}) async {
  final outcome = await localizeIncomingDetailed(
    ref,
    englishText,
    onToken: onToken,
    langCode: langCode,
  );
  return outcome.text;
}

/// Translates a reply and its follow-up prompt.
///
/// This previously returned [followUp] untranslated, so follow-up questions
/// stayed in English even when everything above them was localized.
/// [TranslationPipeline.fromEnglishPair] now translates each part in its own
/// call — AfriSLM was trained on single-text translation, and the labelled
/// two-part prompt this used to send was off-distribution enough that the
/// reply regularly came back unparseable and fell through to English.
Future<(TranslationOutcome, TranslationOutcome)> localizeIncomingPairDetailed(
  Ref ref,
  String reply,
  String followUp, {
  String? langCode,
}) async {
  final lang = langCode ?? await studentLanguageCode(ref);
  if (lang == 'en') {
    return (
      TranslationOutcome.passthrough(reply),
      TranslationOutcome.passthrough(followUp),
    );
  }
  try {
    final pipeline = await ref.read(translationPipelineProvider.future);
    if (pipeline == null) {
      debugPrint('TRANSLATION OFF: no pipeline (pair: en -> $lang).');
      const failure = 'translation model unavailable';
      return (
        TranslationOutcome(text: reply, translated: false, failure: failure),
        TranslationOutcome(text: followUp, translated: false, failure: failure),
      );
    }
    return await pipeline.fromEnglishPairDetailed(reply, followUp, lang);
  } catch (e) {
    debugPrint('TRANSLATION FAILED (pair: en -> $lang): $e');
    return (
      TranslationOutcome(text: reply, translated: false, failure: '$e'),
      TranslationOutcome(text: followUp, translated: false, failure: '$e'),
    );
  }
}

/// Text-only wrapper for [localizeIncomingPairDetailed].
Future<(String, String)> localizeIncomingPair(
  Ref ref,
  String reply,
  String followUp, {
  String? langCode,
}) async {
  final (r, f) =
      await localizeIncomingPairDetailed(ref, reply, followUp, langCode: langCode);
  return (r.text, f.text);
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
    this.translationFailure,
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

  /// Set when the student is learning in a non-English language but this
  /// reply could not be translated, so what they are reading is English.
  ///
  /// Without this the fallback is invisible: the reply simply arrives in
  /// English and looks like the tutor chose to answer that way. Carrying the
  /// reason lets the UI say "shown in English — translation unavailable"
  /// instead of silently lying by omission.
  final String? translationFailure;

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

    // Own the thread locally. A 2+ minute dual-model turn can outlive a
    // ChatNotifier rebuild (AsyncNotifier.build() returns an empty
    // ChatState), and re-reading state.messages at the end then drops the
    // student's bubble — that is what the live Swahili e2e just showed.
    final thread = <ChatMessage>[
      ...current.messages,
      ChatMessage(text: message, isUser: true),
    ];
    state = AsyncData(current.copyWith(
      messages: List<ChatMessage>.from(thread),
      isGenerating: true,
      streamingText: '',
      clearError: true,
    ));

    final TutorPipeline pipeline;
    try {
      pipeline = await ref.read(tutorPipelineProvider.future);
    } catch (e) {
      thread.add(ChatMessage(
        text: _friendlyAiError(e),
        isUser: false,
        isError: true,
      ));
      state = AsyncData(state.requireValue.copyWith(
        messages: List<ChatMessage>.from(thread),
        isGenerating: false,
        streamingText: '',
        errorMessage: _friendlyAiError(e),
      ));
      return;
    }

    // Resolved before generation, not after: it decides whether the raw
    // English tokens may be shown at all, and it pins the outbound
    // AfriSLM language for this turn so a mid-stream picker flip cannot
    // tear the reply across two locales.
    final lang = await studentLanguageCode(ref);

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

    OutboundTranslateStream? outbound;
    StreamSubscription<String>? outboundSub;

    // Behind-the-scenes translation: the tutor pipeline (topic detection,
    // curriculum matching, stage tracking) always runs in English. If the
    // student writes in another language, translate their message to
    // English here and translate the reply back below — best-effort, so a
    // translation hiccup degrades to "answer in English" rather than
    // failing the whole turn. Follow-up prompts are static UI strings
    // (instant) so they are not sent through the translation model.
    final englishMessage = await localizeOutgoing(ref, message, langCode: lang);

    // Emotional safety check — crisis messages never reach the model
    final safety = _safetyEngine.check(englishMessage);
    if (safety.bypassTutor) {
      thread.add(ChatMessage(
        text: await localizeIncoming(
          ref,
          safety.supportMessage!,
          langCode: lang,
        ),
        isUser: false,
      ));
      state = AsyncData(state.requireValue.copyWith(
        messages: List<ChatMessage>.from(thread),
        isGenerating: false,
        streamingText: '',
      ));
      return;
    }

    // English students see Qwen tokens live. Everyone else sees AfriSLM
    // clauses as they flush — never the English draft. Without a
    // translation engine we keep the old silent buffer so English cannot
    // flash in a Swahili session.
    if (lang != 'en') {
      final translate = await ref.read(translationPipelineProvider.future);
      if (translate != null) {
        outbound = OutboundTranslateStream(
          translate: (english) async {
            final outcome =
                await translate.fromEnglishDetailed(english, lang);
            if (!outcome.translated) {
              throw StateError(outcome.failure ?? 'not translated');
            }
            return outcome.text;
          },
        );
        outboundSub = outbound.chunks.listen((_) {
          streamBuf = outbound!.translatedSoFar;
          flushStream(force: true);
        });
      }
    }

    Future<void> onTok(String token) async {
      if (outbound != null) {
        // Await the clause flush so AfriSLM runs while LiteRT's
        // `await for` is paused (sequential swap).
        await outbound.addEnglish(token);
        return;
      }
      if (lang == 'en') {
        streamBuf += token;
        flushStream();
      }
    }

    try {
      final response = await pipeline.respond(
        studentMessage: englishMessage,
        safetyNote: safety.tutorNote,
        onToken: onTok,
      );

      var reply = streamBuf.trim().isNotEmpty ? streamBuf : response.text;
      if (lang == 'en') flushStream(force: true);

      var followUp = response.followUpPrompt;
      String? translatedLanguage;
      String? translationFailure;
      var math = response.math;

      if (lang != 'en' && math != null) {
        if (outbound != null) {
          await outbound.finish();
          await outboundSub?.cancel();
          outboundSub = null;
        }
        // Worked steps: translate titles/"why" only. Never send formulas
        // or the numeric answer through AfriSLM.
        try {
          math = await localizeSchoolMath(
            math,
            translate: (english) async {
              final o = await localizeIncomingDetailed(
                ref,
                english,
                langCode: lang,
              );
              return o.translated ? o.text : english;
            },
          );
          translatedLanguage = lang;
        } catch (e) {
          debugPrint('TRANSLATION FAILED for math steps (en -> $lang): $e');
        }
        if (response.text.trimLeft().startsWith('Step')) {
          reply = '';
        } else if (response.text.trim().isNotEmpty) {
          final intro = await localizeIncomingDetailed(
            ref,
            response.text,
            langCode: lang,
          );
          reply = intro.text;
          if (intro.translated) translatedLanguage = lang;
        }
        if (followUp.isNotEmpty && !hasUiString(lang, followUp)) {
          followUp = (await localizeIncomingDetailed(
            ref,
            followUp,
            langCode: lang,
          )).text;
        }
      } else if (outbound != null) {
        // Clauses already hit AfriSLM as Qwen tokens arrived. Finish the
        // tail (no trailing punctuation) and do not re-translate the
        // whole paragraph — that would double the GGUF load.
        //
        // Engines that skip onToken (scripted tests, some LiteRT paths)
        // still return the full English from generate(). Feed that once
        // so AfriSLM is not skipped.
        if (!outbound.sawEnglish && response.text.trim().isNotEmpty) {
          await outbound.addEnglish(response.text);
        }
        reply = await outbound.finish();
        streamBuf = reply;
        await outboundSub?.cancel();
        outboundSub = null;
        if (reply.isEmpty) {
          reply = response.text;
          translationFailure = 'translation failed';
        } else {
          translatedLanguage = lang;
          flushStream(force: true);
        }
        if (followUp.isNotEmpty && !hasUiString(lang, followUp)) {
          final fu = await localizeIncomingDetailed(
            ref,
            followUp,
            langCode: lang,
          );
          followUp = fu.text;
        }
      } else if (lang != 'en') {
        // Math replies used to be excluded here, which left every
        // school-math answer in English. The worked steps and formulas are
        // rendered separately by WorkedSolution and stay language-neutral;
        // it is the prose around them that has to be translated.
        try {
          // Follow-ups are usually static strings that the l10n tables
          // already cover, and a table lookup is both instant and better
          // than a 0.8B model. Only the interpolated ones (for example
          // "Your turn - try this: ...") miss, and those go to the model
          // alongside the reply in a single call.
          final TranslationOutcome replyOutcome;
          if (followUp.isNotEmpty && !hasUiString(lang, followUp)) {
            final pair = await localizeIncomingPairDetailed(
              ref,
              reply,
              followUp,
              langCode: lang,
            );
            replyOutcome = pair.$1;
            reply = pair.$1.text;
            followUp = pair.$2.text;
          } else {
            replyOutcome =
                await localizeIncomingDetailed(ref, reply, langCode: lang);
            reply = replyOutcome.text;
          }
          // Record what actually happened rather than assuming success. A
          // failure here means the student is about to read English, and
          // the UI has to be able to say so.
          if (replyOutcome.translated) {
            translatedLanguage = lang;
          } else {
            translationFailure = replyOutcome.failure ?? 'translation failed';
          }
        } catch (e) {
          debugPrint('TRANSLATION FAILED for chat reply (en -> $lang): $e');
          translationFailure = '$e';
        }
      }

      thread.add(ChatMessage(
        text: reply,
        isUser: false,
        stage: response.stage,
        followUp: followUp,
        translatedLanguage: translatedLanguage,
        translationFailure: translationFailure,
        math: math,
        mathCoach: response.mathCoach,
      ));

      state = AsyncData(state.requireValue.copyWith(
        messages: List<ChatMessage>.from(thread),
        isGenerating: false,
        streamingText: '',
        clearError: true,
      ));

      // Persist session summary after the student already sees the reply.
      unawaited(_saveSessionSnapshot(pipeline, response, thread.length));
    } catch (e) {
      await outboundSub?.cancel();
      final friendly = _friendlyAiError(e);
      thread.add(ChatMessage(text: friendly, isUser: false, isError: true));
      state = AsyncData(state.requireValue.copyWith(
        messages: List<ChatMessage>.from(thread),
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
    unawaited(
      ref.read(engineLoadedProvider).valueOrNull?.resetSession() ??
          Future<void>.value(),
    );
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
