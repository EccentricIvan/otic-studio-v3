import 'dart:async';

import 'runtime_config.dart';

/// Pulls a finished clause off [buf] so AfriSLM sees real sentences, not
/// half-tokens. Token-by-token translation of a 0.8B model is unreadable.
String? takeFlushableClause(StringBuffer buf) {
  final s = buf.toString();
  if (s.isEmpty) return null;

  final sentence = RegExp(r'^[\s\S]*?[.!?…]["”)]*(?:\s+|$)').firstMatch(s);
  if (sentence != null && RegExp(r'[.!?…]').hasMatch(sentence.group(0)!)) {
    final chunk = sentence.group(0)!;
    buf
      ..clear()
      ..write(s.substring(chunk.length));
    final trimmed = chunk.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  final nl = s.indexOf('\n');
  if (nl >= 8) {
    final chunk = s.substring(0, nl).trim();
    buf
      ..clear()
      ..write(s.substring(nl + 1));
    return chunk.isEmpty ? null : chunk;
  }

  if (s.length >= kTranslateFlushChars) {
    final cut = s.lastIndexOf(RegExp(r'\s'), kTranslateFlushChars);
    if (cut > 16) {
      final chunk = s.substring(0, cut).trim();
      buf
        ..clear()
        ..write(s.substring(cut + 1));
      return chunk.isEmpty ? null : chunk;
    }
    final chunk = s.trim();
    buf.clear();
    return chunk.isEmpty ? null : chunk;
  }
  return null;
}

/// Sequential stream: English tokens in → translated clauses out.
///
/// [addEnglish] returns a [Future] that completes after any flushed clause
/// has been translated. The brain's `await for` token loop awaits that
/// future, so AfriSLM and Qwen never decode in the same window.
class OutboundTranslateStream {
  OutboundTranslateStream({
    required this._translate,
  });

  final Future<String> Function(String english) _translate;
  final StringBuffer _english = StringBuffer();
  final StringBuffer _translated = StringBuffer();
  final _out = StreamController<String>.broadcast();
  Future<void> _chain = Future.value();

  Stream<String> get chunks => _out.stream;

  String get translatedSoFar => _translated.toString().trim();

  bool get sawEnglish => _sawEnglish;
  bool _sawEnglish = false;

  Future<void> addEnglish(String token) async {
    if (token.isEmpty) return;
    _sawEnglish = true;
    _english.write(token);
    final ready = takeFlushableClause(_english);
    if (ready != null) await _enqueue(ready);
  }

  Future<String> finish() async {
    final rest = _english.toString().trim();
    _english.clear();
    if (rest.isNotEmpty) await _enqueue(rest);
    await _chain;
    if (!_out.isClosed) await _out.close();
    return translatedSoFar;
  }

  Future<void> _enqueue(String englishClause) {
    final done = Completer<void>();
    _chain = _chain.then((_) async {
      try {
        final out = (await _translate(englishClause)).trim();
        if (out.isEmpty) return;
        if (_translated.isNotEmpty) _translated.write(' ');
        _translated.write(out);
        if (!_out.isClosed) _out.add(out);
      } catch (_) {
        // Keep English off the live stream.
      } finally {
        if (!done.isCompleted) done.complete();
      }
    });
    return done.future;
  }
}
