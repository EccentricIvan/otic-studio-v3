import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_connect_africa/ai_core/inference/inference_engine.dart';
import 'package:ai_connect_africa/ai_core/providers/ai_provider.dart';
import 'package:ai_connect_africa/ai_core/translate/supported_languages.dart';
import 'package:ai_connect_africa/ai_core/translate/translation_pipeline.dart';
import 'package:ai_connect_africa/ai_core/tutor/tutor_pipeline.dart';
import 'package:ai_connect_africa/db/providers/db_provider.dart';
import 'package:ai_connect_africa/l10n/language_provider.dart';

/// One recorded call to an engine, kept together with its system prompt:
/// that is where TranslationPipeline states the direction of the
/// translation ("You are a professional X to Y translator").
class _Call {
  _Call(this.prompt, this.system);
  final String prompt;
  final String? system;
}

/// Engine fake whose reply depends on the call, so a translated string is
/// distinguishable from the original. One canned response cannot prove the
/// text on screen came out of the translator rather than past it.
class _ScriptedEngine extends InferenceEngine {
  _ScriptedEngine(this._reply);

  final String Function(String prompt, String? system) _reply;
  final List<_Call> calls = [];

  @override
  bool get isReady => true;

  @override
  String get backendLabel => 'Scripted';

  @override
  Future<void> loadModel(String modelPath) async {}

  @override
  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    TokenCallback? onToken,
    String? systemPrompt,
  }) async {
    calls.add(_Call(prompt, systemPrompt));
    return _reply(prompt, systemPrompt);
  }

  @override
  Future<void> dispose() async {}
}

const _tutorReply = 'Photosynthesis is how a plant makes food from sunlight.';

/// Tags each leg of the round trip so assertions can tell them apart:
/// `<lang>` -> English yields `[EN] translated`, English -> `<lang>` yields
/// `[<Lang>] translated`.
String _translateReply(String prompt, String? system) {
  final match = RegExp(r'professional (.+?) to (.+?) translator')
      .firstMatch(system ?? '');
  final to = match?.group(2) ?? '?';
  return '[${to == 'English' ? 'EN' : to}] translated';
}

/// Student text that must not look like English to [looksLikeEnglish] —
/// otherwise the inbound leg is skipped by design and these tests would be
/// asserting the wrong path.
const _studentMessage = 'Nnyonnyola photosynthesis mu bumanyirivu';

typedef _Harness = ({
  ProviderContainer container,
  _ScriptedEngine tutor,
  _ScriptedEngine translate,
});

_Harness _harness(String languageCode) {
  final tutor = _ScriptedEngine((_, __) => _tutorReply);
  final translate = _ScriptedEngine(_translateReply);

  final container = ProviderContainer(
    overrides: [
      // No profile: guests exercise the same path, and it keeps the database
      // out of the test (the session snapshot returns early without one).
      activeStudentProvider.overrideWith((ref) async => null),
      tutorPipelineProvider.overrideWith(
        (ref) async => TutorPipeline(engine: tutor, curriculum: null),
      ),
      translationPipelineProvider.overrideWith(
        (ref) async => TranslationPipeline(translate),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(languageOverrideProvider.notifier).adoptSaved(languageCode);
  return (container: container, tutor: tutor, translate: translate);
}

void main() {
  final foreign = supportedLanguages.where((l) => l.code != 'en').toList();

  group('chat round trip', () {
    for (final lang in foreign) {
      test('${lang.name} (${lang.code}): both legs run', () async {
        final h = _harness(lang.code);
        await h.container.read(chatProvider.notifier).send(_studentMessage);

        // Leg 1 — the student's words go out as <language> -> English, and
        // the tutor is prompted with the result.
        final inbound = h.translate.calls
            .where((c) => (c.system ?? '').contains(
                'professional ${lang.promptName} to English translator'))
            .toList();
        expect(inbound, hasLength(1),
            reason: '${lang.code}: student message was not translated to '
                'English before reaching the tutor');
        expect(inbound.single.prompt, contains(_studentMessage));

        expect(h.tutor.calls, hasLength(1));
        expect(h.tutor.calls.single.prompt, contains('[EN] translated'),
            reason: '${lang.code}: the tutor was prompted with something '
                'other than the English translation');
        expect(h.tutor.calls.single.prompt, isNot(contains(_studentMessage)),
            reason: '${lang.code}: raw local-language text reached the tutor');

        // Leg 2 — the English reply goes back as English -> <language>, and
        // that translation is what the student is shown.
        final outbound = h.translate.calls
            .where((c) => (c.system ?? '').contains(
                'professional English to ${lang.promptName} translator'))
            .toList();
        expect(outbound, isNotEmpty,
            reason: '${lang.code}: tutor reply was never translated back');
        expect(outbound.first.prompt, contains(_tutorReply));

        final messages = h.container.read(chatProvider).requireValue.messages;
        expect(messages, hasLength(2));
        expect(messages.first.isUser, isTrue);
        expect(messages.first.text, _studentMessage,
            reason: 'the student sees their own words, not a translation');
        expect(messages.last.text, '[${lang.promptName}] translated',
            reason: '${lang.code}: the reply on screen is not the translated '
                'one');
      });
    }

    test('every supported language is covered above', () {
      // 19 AfriSLM pairs plus Kirundi (`rn`), which routes through Kinyarwanda.
      expect(foreign, hasLength(20));
    });

    test('English asks for no translation at all', () async {
      final h = _harness('en');
      await h.container
          .read(chatProvider.notifier)
          .send('Explain photosynthesis');

      expect(h.translate.calls, isEmpty);
      expect(h.container.read(chatProvider).requireValue.messages.last.text,
          _tutorReply);
    });

    // Documented asymmetry: the outbound leg always runs, the inbound leg is
    // skipped when the student's text trips looksLikeEnglish(). Students
    // often type English while the UI is in another language, and a round
    // trip on text that is already English is the slowest call in the turn.
    test('an English-looking message skips only the inbound leg', () async {
      final h = _harness('sw');
      await h.container
          .read(chatProvider.notifier)
          .send('What is the sum of the angles in a triangle?');

      expect(
        h.translate.calls
            .where((c) => (c.system ?? '').contains('to English translator')),
        isEmpty,
        reason: 'English-looking text should not be sent through AfriSLM',
      );
      expect(
        h.translate.calls.where(
            (c) => (c.system ?? '').contains('English to Swahili translator')),
        isNotEmpty,
        reason: 'the reply must still come back in Swahili',
      );
    });

    // Translation is best-effort everywhere: a dead translator degrades to
    // English rather than failing the turn.
    test('a missing translator leaves the chat working in English', () async {
      final tutor = _ScriptedEngine((_, __) => _tutorReply);
      final container = ProviderContainer(overrides: [
        activeStudentProvider.overrideWith((ref) async => null),
        tutorPipelineProvider.overrideWith(
          (ref) async => TutorPipeline(engine: tutor, curriculum: null),
        ),
        translationPipelineProvider.overrideWith((ref) async => null),
      ]);
      addTearDown(container.dispose);
      container.read(languageOverrideProvider.notifier).adoptSaved('yo');

      await container.read(chatProvider.notifier).send(_studentMessage);

      final messages = container.read(chatProvider).requireValue.messages;
      expect(messages.last.text, _tutorReply);
      expect(messages.last.isError, isFalse);
    });
  });
}
