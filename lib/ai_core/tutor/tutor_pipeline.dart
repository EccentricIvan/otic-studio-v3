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
      _activeLesson = _curriculum?.findBestMatch(studentMessage);
    }

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
${lessonContext != null ? 'USE THIS REFERENCE MATERIAL to teach accurately:\n$lessonContext\n' : ''}
Current stage: ${stage.name.toUpperCase()}
Stage instructions:
  answer   → Give a clear, direct explanation using the reference material above.
  clarify  → Ask one question to check understanding.
  practice → Give one short exercise or challenge based on the material.
  apply    → Describe a real-world scenario where this applies.
  create   → Ask the student to make or build something small.
  reflect  → Ask the student to summarise what they learned in their own words.

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
    if (lower.contains('python') ||
        lower.contains('code') ||
        lower.contains('program'))
      return 'programming';
    if (lower.contains('math') ||
        lower.contains('algebra') ||
        lower.contains('equation'))
      return 'mathematics';
    if (lower.contains('physics') ||
        lower.contains('gravity') ||
        lower.contains('force'))
      return 'physics';
    if (lower.contains('biology') ||
        lower.contains('cell') ||
        lower.contains('photosynthesis'))
      return 'biology';
    if (lower.contains('business') ||
        lower.contains('entrepreneur') ||
        lower.contains('market'))
      return 'business';
    if (lower.contains('history') ||
        lower.contains('war') ||
        lower.contains('colonial'))
      return 'history';
    if (lower.contains('agriculture') ||
        lower.contains('farm') ||
        lower.contains('crop'))
      return 'agriculture';
    if (lower.contains('ai') ||
        lower.contains('machine learning') ||
        lower.contains('data'))
      return 'ai_data';
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
