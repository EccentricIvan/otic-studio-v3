import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'curriculum_models.dart';

class CurriculumService {
  final Map<String, Subject> _cache = {};

  static const _subjects = [
    'mathematics',
    'physics',
    'biology',
    'chemistry',
    'programming',
    'ai_and_data',
    'entrepreneurship',
    'agriculture',
    'history',
    'geography',
    'english_writing',
    'economics',
    'arts',
    'web_development',
    'app_development',
    'ignite_ai',
  ];

  Future<List<Subject>> loadAll() async {
    if (_cache.length == _subjects.length) return _cache.values.toList();
    for (final id in _subjects) {
      if (!_cache.containsKey(id)) {
        try {
          final json = await rootBundle.loadString('assets/curriculum/$id.json');
          final data = jsonDecode(json) as Map<String, dynamic>;
          _cache[id] = Subject.fromJson(data);
        } catch (_) {}
      }
    }
    return _cache.values.toList();
  }

  Future<Subject?> load(String subjectId) async {
    if (_cache.containsKey(subjectId)) return _cache[subjectId];
    try {
      final json =
          await rootBundle.loadString('assets/curriculum/$subjectId.json');
      final data = jsonDecode(json) as Map<String, dynamic>;
      final subject = Subject.fromJson(data);
      _cache[subjectId] = subject;
      return subject;
    } catch (_) {
      return null;
    }
  }

  Lesson? findLesson(String subjectId, String query) {
    final subject = _cache[subjectId];
    if (subject == null) return null;
    final q = query.toLowerCase();
    for (final unit in subject.units) {
      for (final lesson in unit.lessons) {
        if (lesson.title.toLowerCase().contains(q)) return lesson;
        for (final term in lesson.keyTerms.keys) {
          if (_containsWord(q, term.toLowerCase())) return lesson;
        }
      }
    }
    return null;
  }

  /// True if [word] appears in [text] as a whole word (not mid-word, e.g.
  /// "tell" must not match inside "intelligence").
  bool _containsWord(String text, String word) {
    return RegExp('\\b${RegExp.escape(word)}').hasMatch(text);
  }

  Lesson? findBestMatch(String query) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toList();
    if (words.isEmpty) return null;

    Lesson? best;
    int bestScore = 0;

    for (final subject in _cache.values) {
      for (final unit in subject.units) {
        for (final lesson in unit.lessons) {
          int score = 0;
          final titleLower = lesson.title.toLowerCase();

          // Only match against title and key terms — NOT content.
          // Word-boundary matching, not raw substring: a plain .contains()
          // check let query words match mid-word (e.g. "tell" inside
          // "inTELLigence"), causing unrelated lessons to win.
          for (final word in words) {
            if (_containsWord(titleLower, word)) score += 5;
            for (final term in lesson.keyTerms.keys) {
              final termLower = term.toLowerCase();
              if (termLower == word || _containsWord(termLower, word)) score += 3;
            }
          }

          if (score > bestScore) {
            bestScore = score;
            best = lesson;
          }
        }
      }
    }

    // Only return if title/keyterm match is strong
    if (bestScore >= 8) return best;
    return null;
  }

  String buildContext(Lesson lesson) {
    final buf = StringBuffer();
    buf.writeln('Topic: ${lesson.title}');
    // Trim content to ~500 chars to keep prompt small for on-device models
    final content = lesson.content.length > 500
        ? '${lesson.content.substring(0, 500)}...'
        : lesson.content;
    buf.writeln(content);
    if (lesson.examples.isNotEmpty) {
      buf.writeln('Example: ${lesson.examples.first}');
    }
    return buf.toString();
  }
}

final curriculumServiceProvider =
    Provider<CurriculumService>((ref) => CurriculumService());

final allSubjectsProvider = FutureProvider<List<Subject>>((ref) {
  return ref.watch(curriculumServiceProvider).loadAll();
});
