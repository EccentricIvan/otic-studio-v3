import 'package:ai_connect_africa/ai_core/inference/dual_model_stream.dart';
import 'package:ai_connect_africa/ai_core/inference/runtime_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('takeFlushableClause', () {
    test('flushes a finished sentence and leaves the rest', () {
      final buf = StringBuffer('Photosynthesis makes food. The next ');
      expect(takeFlushableClause(buf), 'Photosynthesis makes food.');
      expect(buf.toString(), 'The next ');
    });

    test('flushes when the buffer ends on punctuation', () {
      final buf = StringBuffer('Food is made.');
      expect(takeFlushableClause(buf), 'Food is made.');
      expect(buf.toString(), isEmpty);
    });

    test('does not flush a half-sentence', () {
      final buf = StringBuffer('Photosynthesis makes');
      expect(takeFlushableClause(buf), isNull);
      expect(buf.toString(), 'Photosynthesis makes');
    });

    test('flushes on a newline after enough text', () {
      final buf = StringBuffer('A complete clause here\nmore');
      expect(takeFlushableClause(buf), 'A complete clause here');
      expect(buf.toString(), 'more');
    });

    test('flushes a long clause at a word boundary', () {
      final buf = StringBuffer(
        'This clause is long enough that we should cut it at a space '
        'before AfriSLM sees an unfinished token stream leftover',
      );
      final chunk = takeFlushableClause(buf);
      expect(chunk, isNotNull);
      expect(chunk!.contains(' '), isTrue);
      expect(buf.isNotEmpty, isTrue);
    });

    test('does not flush under the character budget without punctuation', () {
      final buf = StringBuffer('a' * (kTranslateFlushChars - 1));
      expect(takeFlushableClause(buf), isNull);
    });
  });

  group('OutboundTranslateStream', () {
    test('pipes English clauses into translated Stream<String> chunks', () async {
      final seen = <String>[];
      final stream = OutboundTranslateStream(
        translate: (english) async => 'SW:$english',
      );
      final sub = stream.chunks.listen(seen.add);

      await stream.addEnglish('Hello there. ');
      await stream.addEnglish('Next idea.');
      final all = await stream.finish();
      await sub.cancel();

      expect(seen, ['SW:Hello there.', 'SW:Next idea.']);
      expect(all, 'SW:Hello there. SW:Next idea.');
    });

    test('keeps a failed clause off the live stream', () async {
      final seen = <String>[];
      final stream = OutboundTranslateStream(
        translate: (english) async {
          if (english.contains('fail')) throw StateError('nope');
          return 'OK:$english';
        },
      );
      final sub = stream.chunks.listen(seen.add);

      await stream.addEnglish('Good sentence. ');
      await stream.addEnglish('This will fail. ');
      final all = await stream.finish();
      await sub.cancel();

      expect(seen, ['OK:Good sentence.']);
      expect(all, 'OK:Good sentence.');
    });

    test('addEnglish awaits the clause translation', () async {
      var finished = false;
      final stream = OutboundTranslateStream(
        translate: (english) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          finished = true;
          return 'X';
        },
      );

      final future = stream.addEnglish('Done. ');
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      await future;
      expect(finished, isTrue);
      await stream.finish();
    });
  });
}
