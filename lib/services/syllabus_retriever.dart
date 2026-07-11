import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// A single retrieved passage from the syllabus knowledge base.
class SyllabusChunk {
  const SyllabusChunk({
    required this.subject,
    required this.level,
    required this.studentClass,
    required this.term,
    required this.theme,
    required this.topic,
    required this.chunkType,
    required this.source,
    required this.content,
  });

  final String subject;
  final String level;
  final String studentClass;
  final int term;
  final String theme;
  final String topic;
  final String chunkType;
  final String source;
  final String content;
}

/// Retrieves syllabus-grounded content from the bundled FTS5 database
/// (`assets/db/syllabus.db`, built by `tools/syllabus/build_syllabus_db.py`)
/// so the tutor can answer from real curriculum material instead of
/// whatever Gemma happens to know on its own.
class SyllabusRetriever {
  Database? _db;

  static const _assetPath = 'assets/db/syllabus.db';
  static const _dbFileName = 'syllabus.db';

  /// SQLite can't open a database directly out of a Flutter asset bundle,
  /// so the bundled file is copied to the app's documents directory once
  /// and opened read-only from there on every subsequent call.
  Future<void> init() async {
    if (_db != null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, _dbFileName);
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      final bytes = await rootBundle.load(_assetPath);
      await dbFile.create(recursive: true);
      await dbFile.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    }

    _db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  }

  void dispose() {
    _db?.dispose();
    _db = null;
  }

  /// Returns the top [k] chunks matching [query], optionally filtered to a
  /// [studentClass] (e.g. `'S1'`) and/or [subject] (e.g. `'Mathematics'`).
  Future<List<SyllabusChunk>> retrieve(
    String query, {
    String? studentClass,
    String? subject,
    int k = 3,
  }) async {
    await init();
    final db = _db;
    if (db == null) return const [];

    final ftsQuery = _sanitizeForFts(query);
    if (ftsQuery.isEmpty) return const [];

    final whereClauses = <String>[];
    final params = <Object?>[ftsQuery];
    if (studentClass != null) {
      whereClauses.add('chunks.class = ?');
      params.add(studentClass);
    }
    if (subject != null) {
      whereClauses.add('chunks.subject = ?');
      params.add(subject);
    }
    final whereSql =
        whereClauses.isEmpty ? '' : 'AND ${whereClauses.join(' AND ')}';
    params.add(k);

    final rows = db.select(
      '''
      SELECT chunks.subject, chunks.level, chunks.class, chunks.term,
             chunks.theme, chunks.topic, chunks.chunk_type, chunks.source,
             chunks.content
      FROM chunks_fts
      JOIN chunks ON chunks.id = chunks_fts.rowid
      WHERE chunks_fts MATCH ? $whereSql
      ORDER BY rank
      LIMIT ?
      ''',
      params,
    );

    return rows
        .map(
          (row) => SyllabusChunk(
            subject: row['subject'] as String,
            level: row['level'] as String,
            studentClass: row['class'] as String,
            term: row['term'] as int,
            theme: row['theme'] as String,
            topic: row['topic'] as String,
            chunkType: row['chunk_type'] as String,
            source: row['source'] as String,
            content: row['content'] as String,
          ),
        )
        .toList();
  }

  /// Strips punctuation/quotes (which have special meaning in FTS5's query
  /// syntax and would otherwise throw a syntax error) and OR-joins the
  /// remaining terms, so a query that only partially matches the corpus
  /// still surfaces the closest thing available rather than nothing.
  String _sanitizeForFts(String query) {
    final terms = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1)
        .toList();
    return terms.join(' OR ');
  }

  /// Builds a prompt that instructs the model to answer [question] using
  /// only the retrieved [chunks], grounded to [studentClass]'s syllabus.
  String buildGroundedPrompt(
    String question,
    List<SyllabusChunk> chunks, {
    required String studentClass,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        'You are a tutor for a Ugandan $studentClass student following the UNEB curriculum.',
      )
      ..writeln(
        "Using ONLY the syllabus material below, answer the student's question clearly and simply.",
      )
      ..writeln(
        'If the material does not cover the question, say so and give a brief general pointer.',
      )
      ..writeln()
      ..writeln('SYLLABUS MATERIAL:');

    for (final chunk in chunks) {
      buffer
        ..writeln('[${chunk.studentClass} Term ${chunk.term} — ${chunk.topic}]')
        ..writeln(chunk.content)
        ..writeln();
    }

    buffer.writeln('STUDENT QUESTION: $question');
    return buffer.toString();
  }
}
