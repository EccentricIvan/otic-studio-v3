import '../inference/inference_engine.dart';
import '../../curriculum/curriculum_models.dart';
import '../../curriculum/curriculum_provider.dart';
import 'tutor_response.dart';

/// Implements the AI tutor contract:
///   Answer → Clarify → Practice → Apply → Create → Reflect
///
/// Each student message advances the pipeline one stage.
/// The pipeline resets when the student changes topic.
/// When curriculum content is available, it is injected into the
/// prompt so the model teaches from accurate material.
class TutorPipeline {
  TutorPipeline({
    required this._engine,
    this._curriculum,
  });

  final InferenceEngine _engine;
  final CurriculumService? _curriculum;
  TutorStage _nextStage = TutorStage.answer;
  String _currentTopic = '';
  Lesson? _activeLesson;
  final List<_Turn> _history = [];

  /// Process a student message and stream the tutor response.
  /// [onToken] fires with each new token as it arrives.
  /// [safetyNote] is an extra instruction from the emotional safety engine
  /// (e.g. "student sounds discouraged — encourage first").
  /// Returns the complete [TutorResponse] when generation finishes.
  Future<TutorResponse> respond({
    required String studentMessage,
    void Function(String token)? onToken,
    String? safetyNote,
  }) async {
    final topic = _detectTopic(studentMessage);
    if (topic != _currentTopic) {
      _currentTopic = topic;
      _nextStage = TutorStage.answer;
    }

    // Always search curriculum for the best matching lesson
    final matchedLesson = _curriculum?.findBestMatch(studentMessage);
    if (matchedLesson != null) _activeLesson = matchedLesson;

    final stage = _nextStage;
    final lessonContext =
        _activeLesson != null ? _curriculum?.buildContext(_activeLesson!) : null;
    final prompt = _buildPrompt(studentMessage, stage,
        safetyNote: safetyNote, lessonContext: lessonContext);

    final buffer = StringBuffer();
    final text = await _engine.generate(
      prompt: prompt,
      maxTokens: 400,
      temperature: _temperatureForStage(stage),
      onToken: (token) {
        buffer.write(token);
        onToken?.call(token);
      },
    );

    _history.add(_Turn(role: 'student', text: studentMessage));
    _history.add(_Turn(role: 'tutor', text: text));
    if (_history.length > 20) _history.removeRange(0, 2); // keep last 10 turns

    final followUp = _followUpForStage(stage);
    _advanceStage();

    return TutorResponse(
      stage: stage,
      text: text,
      followUpPrompt: followUp,
      topic: _currentTopic,
    );
  }

  void _advanceStage() {
    const order = TutorStage.values;
    final idx = order.indexOf(_nextStage);
    _nextStage = idx < order.length - 1 ? order[idx + 1] : TutorStage.practice;
  }

  String _buildPrompt(
    String studentMessage,
    TutorStage stage, {
    String? safetyNote,
    String? lessonContext,
  }) {
    final stageHint = {
      TutorStage.answer: 'Explain clearly in 2-3 sentences.',
      TutorStage.clarify: 'Ask one question to check understanding.',
      TutorStage.practice: 'Give one short exercise.',
      TutorStage.apply: 'Give a real-world example.',
      TutorStage.create: 'Ask them to build something small.',
      TutorStage.reflect: 'Ask them to summarise what they learned.',
    }[stage] ?? 'Respond helpfully.';

    final recentHistory = _history.length > 6
        ? _history.sublist(_history.length - 6)
        : _history;
    final historyBlock = recentHistory
        .map((t) => '${t.role == 'tutor' ? 'Tutor' : 'Student'}: ${t.text}')
        .join('\n');

    if (lessonContext != null) {
      // Curriculum already shown — Gemma just adds a brief follow-up
      return '''You are a friendly tutor. The student already sees the lesson content. Add ONE short encouraging sentence and ask if they want a quiz or have questions. Maximum 1-2 sentences. Do not repeat the lesson.
Student: $studentMessage
Tutor:''';
    }

    return '''You are a friendly AI tutor. Be concise and encouraging.
${safetyNote != null ? '$safetyNote\n' : ''}Task: $stageHint
${historyBlock.isNotEmpty ? '$historyBlock\n' : ''}Student: $studentMessage
Tutor:''';
  }

  double _temperatureForStage(TutorStage stage) {
    switch (stage) {
      case TutorStage.answer:
        return 0.5;
      case TutorStage.clarify:
        return 0.6;
      case TutorStage.practice:
        return 0.7;
      case TutorStage.apply:
        return 0.8;
      case TutorStage.create:
        return 0.9;
      case TutorStage.reflect:
        return 0.6;
    }
  }

  String _followUpForStage(TutorStage stage) {
    switch (stage) {
      case TutorStage.answer:
        return 'Do you understand so far, or shall I explain it differently?';
      case TutorStage.clarify:
        return 'Take your time — there are no wrong answers here.';
      case TutorStage.practice:
        return 'Give it a try and tell me your answer.';
      case TutorStage.apply:
        return 'Can you think of another real-life example like this?';
      case TutorStage.create:
        return 'Share what you made or describe your idea.';
      case TutorStage.reflect:
        return 'Great work! Ready to explore the next topic?';
    }
  }

  String _detectTopic(String message) {
    final lower = message.toLowerCase();

    const topicKeywords = <String, List<String>>{
      'mathematics': ['math', 'algebra', 'equation', 'fraction', 'geometry', 'calculus', 'arithmetic', 'percentage', 'ratio', 'number'],
      'physics': ['physics', 'gravity', 'force', 'energy', 'motion', 'electricity', 'magnet', 'wave', 'light', 'newton'],
      'biology': ['biology', 'cell', 'photosynthesis', 'dna', 'gene', 'ecosystem', 'organ', 'evolution', 'species', 'bacteria'],
      'chemistry': ['chemistry', 'atom', 'element', 'reaction', 'acid', 'base', 'molecule', 'compound', 'periodic', 'bond'],
      'programming': ['python', 'code', 'program', 'function', 'variable', 'loop', 'debug', 'algorithm', 'software', 'script'],
      'web_development': ['html', 'css', 'javascript', 'website', 'web dev', 'webpage', 'frontend', 'responsive', 'dom', 'flexbox'],
      'app_development': ['app dev', 'mobile app', 'flutter', 'android', 'ios', 'widget', 'navigation', 'ui design', 'ux', 'deploy'],
      'ai_data': ['ai', 'artificial intelligence', 'machine learning', 'data science', 'neural', 'deep learning', 'model', 'dataset', 'training data'],
      'entrepreneurship': ['business', 'entrepreneur', 'startup', 'marketing', 'sales', 'profit', 'investor', 'revenue', 'branding'],
      'agriculture': ['agriculture', 'farm', 'crop', 'soil', 'irrigation', 'livestock', 'harvest', 'seed', 'fertilizer', 'poultry'],
      'history': ['history', 'war', 'colonial', 'empire', 'revolution', 'civilization', 'ancient', 'medieval', 'independence'],
      'geography': ['geography', 'climate', 'continent', 'river', 'mountain', 'population', 'urban', 'map', 'earthquake', 'volcano'],
      'english_writing': ['writing', 'essay', 'grammar', 'paragraph', 'sentence', 'punctuation', 'vocabulary', 'tense', 'noun', 'verb'],
      'economics': ['economics', 'economy', 'supply', 'demand', 'inflation', 'gdp', 'trade', 'tax', 'price', 'market economy'],
      'arts': ['art', 'painting', 'drawing', 'sculpture', 'color theory', 'sketch', 'design', 'photography', 'creative', 'canvas'],
    };

    String bestTopic = '';
    int bestScore = 0;

    for (final entry in topicKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestTopic = entry.key;
      }
    }

    if (bestScore > 0) return bestTopic;

    return message
        .split(' ')
        .take(3)
        .join('_')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z_]'), '');
  }

  /// Analyzes the recent conversation to produce a real summary (for the
  /// student memory engine's "compressed summary" requirement, instead of
  /// blindly truncating the latest reply) plus an optional detected
  /// strength/weakness. Best-effort — falls back to an empty summary if
  /// generation fails or produces something unparseable.
  Future<SessionAnalysis> analyzeSession() async {
    if (_history.isEmpty) return const SessionAnalysis(summary: '');

    final recent =
        _history.length > 6 ? _history.sublist(_history.length - 6) : _history;
    final convo = recent
        .map((t) => '${t.role == 'tutor' ? 'Tutor' : 'Student'}: ${t.text}')
        .join('\n');

    final prompt = '''Analyze this tutoring conversation briefly.
$convo

Respond in exactly this format:
SUMMARY: <one short sentence, max 20 words, what the student learned or discussed>
STRENGTH: <one short phrase describing something the student did well, or NONE>
WEAKNESS: <one short phrase describing something the student is struggling with, or NONE>''';

    try {
      final raw = await _engine.generate(prompt: prompt, maxTokens: 80, temperature: 0.3);
      return _parseAnalysis(raw);
    } catch (_) {
      return const SessionAnalysis(summary: '');
    }
  }

  SessionAnalysis _parseAnalysis(String raw) {
    String? extract(String label) {
      final match = RegExp('$label:\\s*(.+)', caseSensitive: false).firstMatch(raw);
      final value = match?.group(1)?.trim();
      if (value == null || value.isEmpty || value.toUpperCase().startsWith('NONE')) {
        return null;
      }
      return value;
    }

    final summary = extract('SUMMARY') ??
        (raw.length > 150 ? '${raw.substring(0, 150)}…' : raw);

    return SessionAnalysis(
      summary: summary,
      strength: extract('STRENGTH'),
      weakness: extract('WEAKNESS'),
    );
  }

  /// Reset pipeline (e.g. user starts a new session).
  void reset() {
    _nextStage = TutorStage.answer;
    _currentTopic = '';
    _history.clear();
  }
}

class SessionAnalysis {
  const SessionAnalysis({required this.summary, this.strength, this.weakness});
  final String summary;
  final String? strength;
  final String? weakness;
}

class _Turn {
  _Turn({required this.role, required this.text});
  final String role;
  final String text;
}
