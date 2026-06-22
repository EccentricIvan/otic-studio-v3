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
          if (q.contains(term.toLowerCase())) return lesson;
        }
      }
    }
    return null;
  }

  Lesson? findBestMatch(String query) {
    final q = query.toLowerCase();
    for (final subject in _cache.values) {
      for (final unit in subject.units) {
        for (final lesson in unit.lessons) {
          if (lesson.title.toLowerCase().contains(q)) return lesson;
          if (lesson.content.toLowerCase().contains(q)) return lesson;
          for (final term in lesson.keyTerms.keys) {
            if (q.contains(term.toLowerCase())) return lesson;
          }
        }
      }
    }
    return null;
  }

  String buildContext(Lesson lesson) {
    final buf = StringBuffer();
    buf.writeln('=== LESSON: ${lesson.title} ===');
    buf.writeln(lesson.content);
    if (lesson.examples.isNotEmpty) {
      buf.writeln('\nEXAMPLES:');
      for (final ex in lesson.examples) {
        buf.writeln('- $ex');
      }
    }
    if (lesson.keyTerms.isNotEmpty) {
      buf.writeln('\nKEY TERMS:');
      for (final entry in lesson.keyTerms.entries) {
        buf.writeln('- ${entry.key}: ${entry.value}');
      }
    }
    return buf.toString();
  }
}

final curriculumServiceProvider =
    Provider<CurriculumService>((ref) => CurriculumService());

final allSubjectsProvider = FutureProvider<List<Subject>>((ref) {
  return ref.watch(curriculumServiceProvider).loadAll();
});
