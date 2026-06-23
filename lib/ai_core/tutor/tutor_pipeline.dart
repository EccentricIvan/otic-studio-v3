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
    required InferenceEngine engine,
    CurriculumService? curriculum,
  })  : _engine = engine,
        _curriculum = curriculum;

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
    final historyText = _history
        .map((t) => '${t.role == 'tutor' ? 'Tutor' : 'Student'}: ${t.text}')
        .join('\n');

    return '''You are an expert offline AI tutor for students in under-resourced schools.
You respond in plain, encouraging language. Be concise (2-4 sentences max per stage).
Never use bullet lists. Ask one question at the end. Never say "I am an AI".
${safetyNote != null ? '\n$safetyNote\n' : ''}
${lessonContext != null ? '''IMPORTANT — Use ONLY the following lesson material to teach. Do NOT make up facts.
Base your explanation, examples, and questions on this content:

$lessonContext
''' : 'No specific lesson material available — answer based on your general knowledge.\n'}
Current stage: ${stage.name.toUpperCase()}
Stage instructions:
  answer   → Give a clear, direct explanation based on the lesson material above. Use the examples provided.
  clarify  → Ask one question to check understanding based on the lesson content.
  practice → Give one exercise from the lesson material or similar to the examples above.
  apply    → Describe a real-world scenario using concepts from the lesson.
  create   → Ask the student to make or build something related to the lesson topic.
  reflect  → Ask the student to summarise the key points from the lesson in their own words.

${historyText.isNotEmpty ? 'Previous conversation:\n$historyText\n' : ''}Student: $studentMessage
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

  /// Reset pipeline (e.g. user starts a new session).
  void reset() {
    _nextStage = TutorStage.answer;
    _currentTopic = '';
    _history.clear();
  }
}

class _Turn {
  _Turn({required this.role, required this.text});
  final String role;
  final String text;
}
