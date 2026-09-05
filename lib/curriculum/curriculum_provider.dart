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

  Lesson? findBestMatch(String query) => findBestMatchDetailed(query)?.lesson;

  CurriculumMatch? findBestMatchDetailed(String query) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toList();
    if (words.isEmpty) return null;

    CurriculumMatch? best;
    int bestScore = 0;

    for (final subject in _cache.values) {
      for (final unit in subject.units) {
        for (final lesson in unit.lessons) {
          int score = 0;
          final titleLower = lesson.title.toLowerCase();

          for (final word in words) {
            if (_containsWord(titleLower, word)) score += 5;
            for (final term in lesson.keyTerms.keys) {
              final termLower = term.toLowerCase();
              if (termLower == word || _containsWord(termLower, word)) {
                score += 3;
              }
            }
          }

          if (score > bestScore) {
            bestScore = score;
            best = CurriculumMatch(
              subjectName: subject.name,
              unitTitle: unit.title,
              lesson: lesson,
            );
          }
        }
      }
    }

    if (bestScore >= 8) return best;
    return null;
  }

  /// Short notes for the on-device tutor. Keep this tight — long dumps
  /// make CPU prefill slow.
  String buildTutorNotes(CurriculumMatch match) {
    final lesson = match.lesson;
    final buf = StringBuffer()
      ..writeln('Subject: ${match.subjectName}')
      ..writeln('Topic: ${match.unitTitle} / ${lesson.title}');
    if (lesson.keyTerms.isNotEmpty) {
      final terms = lesson.keyTerms.entries.take(3).map((e) => '${e.key}: ${e.value}').join('; ');
      buf.writeln('Definitions: $terms');
    }
    final content = lesson.content.length > 360
        ? '${lesson.content.substring(0, 360)}…'
        : lesson.content;
    buf.writeln(content);
    if (lesson.examples.isNotEmpty) {
      final ex = lesson.examples.first;
      buf.writeln('Example: ${ex.length > 140 ? '${ex.substring(0, 140)}…' : ex}');
    }
    return buf.toString().trim();
  }

  String buildContext(Lesson lesson) {
    final buf = StringBuffer();
    buf.writeln('Topic: ${lesson.title}');
    final content = lesson.content.length > 1600
        ? '${lesson.content.substring(0, 1600)}...'
        : lesson.content;
    buf.writeln(content);
    for (final example in lesson.examples.take(2)) {
      buf.writeln('Example: $example');
    }
    return buf.toString();
  }
}

class CurriculumMatch {
  const CurriculumMatch({
    required this.subjectName,
    required this.unitTitle,
    required this.lesson,
  });

  final String subjectName;
  final String unitTitle;
  final Lesson lesson;
}

final curriculumServiceProvider =
    Provider<CurriculumService>((ref) => CurriculumService());

final allSubjectsProvider = FutureProvider<List<Subject>>((ref) {
  return ref.watch(curriculumServiceProvider).loadAll();
});
