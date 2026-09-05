import '../inference/inference_engine.dart';
import '../../curriculum/curriculum_provider.dart';
import 'school_math.dart';
import 'tutor_contract.dart';
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
  CurriculumMatch? _activeMatch;
  final List<_Turn> _history = [];
  SchoolMathSolution? _activeMath;
  SchoolMathSolution? _awaitingMath;
  bool _practiceMiss = false;

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
    final continuing = _isContinuingThread(studentMessage);
    final topic = _detectTopic(studentMessage);
    final switched = !continuing &&
        topic.isNotEmpty &&
        _currentTopic.isNotEmpty &&
        topic != _currentTopic;
    if (switched) {
      _currentTopic = topic;
      _nextStage = TutorStage.answer;
      _activeMatch = null;
    } else if (_currentTopic.isEmpty && topic.isNotEmpty) {
      _currentTopic = topic;
    }

    final matched = _curriculum?.findBestMatchDetailed(studentMessage);
    if (matched != null) {
      _activeMatch = matched;
    } else if (switched) {
      _activeMatch = null;
    }

    final stage = _nextStage;

    final mathReply = _respondWithMath(studentMessage, stage);
    if (mathReply != null) {
      onToken?.call(mathReply.text);
      _remember(studentMessage, mathReply.text, math: mathReply.math);
      _advanceStage();
      return mathReply;
    }

    final notes = _activeMatch != null
        ? _curriculum?.buildTutorNotes(_activeMatch!)
        : null;
    final prompt = _buildPrompt(
      studentMessage,
      safetyNote: safetyNote,
      curriculumNotes: notes,
    );

    final buffer = StringBuffer();
    final text = await _engine.generate(
      prompt: prompt,
      maxTokens: 280,
      temperature: 0.25,
      onToken: (token) {
        buffer.write(token);
        onToken?.call(token);
      },
    );

    _remember(studentMessage, text);

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
    String studentMessage, {
    String? safetyNote,
    String? curriculumNotes,
  }) {
    final q = studentMessage.length > 240
        ? '${studentMessage.substring(0, 240)}…'
        : studentMessage;

    final notes = (curriculumNotes == null || curriculumNotes.isEmpty)
        ? 'CURRICULUM: none matched — do not invent a syllabus. Teach at a general school level.'
        : 'CURRICULUM:\n$curriculumNotes';

    return '''$kTutorContract
$notes
${safetyNote != null ? '$safetyNote\n' : ''}${_threadBlock()}CURRENT QUESTION: $q
Tutor:''';
  }

  void _remember(String studentMessage, String tutorText, {SchoolMathSolution? math}) {
    _history.add(_Turn(
      role: 'student',
      text: studentMessage,
      recap: _clip(studentMessage, 120),
    ));
    _history.add(_Turn(
      role: 'tutor',
      text: tutorText,
      recap: _tutorRecap(tutorText, math),
    ));
    if (_history.length > 6) _history.removeRange(0, _history.length - 6);
  }

  String _threadBlock() {
    if (_history.isEmpty) return '';
    final b = StringBuffer();
    b.writeln('THREAD (understanding only — do not copy):');
    for (final t in _history) {
      final line = t.recap.isNotEmpty ? t.recap : _clip(t.text, 80);
      if (t.role == 'student') {
        b.writeln('Student asked: $line');
      } else {
        b.writeln('You already taught: $line');
      }
    }
    b.writeln('Build on that. Write a new reply for CURRENT QUESTION.');
    return b.toString();
  }

  String _tutorRecap(String text, SchoolMathSolution? math) {
    if (math != null) {
      return '${math.answer} — method already shown; do not repeat those steps unless asked';
    }
    final answer = RegExp(
      r'Answer:\s*(.+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (answer != null) {
      return _clip(answer.group(1)!.trim(), 90);
    }
    final one = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _clip(one, 90);
  }

  String _clip(String s, int max) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  bool _isContinuingThread(String message) {
    if (_history.isEmpty) return false;
    if (_isClarifyingFollowUp(message)) return true;
    final t = message.trim().toLowerCase();
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return false;
    if (RegExp(
      r'^(what about|how about|and if|so if|so then|then if|'
      r'compared to|the same|same for|why (do|does|did|is|would)|'
      r'how (does|do|did|is|would) that|does that|is that|and then|'
      r'tell me more|another example|what else|go deeper|and also)\b',
    ).hasMatch(t)) {
      return true;
    }
    if (words.length <= 12 &&
        RegExp(
          r'\b(that|this|those|these|it|they|them|instead|'
          r'the answer|the result|the method|the steps)\b',
        ).hasMatch(t)) {
      return true;
    }
    return false;
  }

  bool _isClarifyingFollowUp(String message) {
    final t = message.trim().toLowerCase().replaceAll(RegExp(r'[?.!]'), '');
    if (t.isEmpty || t.split(RegExp(r'\s+')).length > 10) return false;
    return RegExp(
      r'^(why|how|huh|ok|okay|yes|no|thanks|more|simpler|again|'
      r'please explain|explain more|what do you mean|'
      r"i don'?t understand|continue|an example|example)$",
    ).hasMatch(t);
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
    return '';
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
    _activeMatch = null;
    _history.clear();
    _activeMath = null;
    _awaitingMath = null;
    _practiceMiss = false;
  }

  void _clearMath() {
    _activeMath = null;
    _awaitingMath = null;
    _practiceMiss = false;
  }

  TutorResponse? _respondWithMath(String studentMessage, TutorStage stage) {
    final follow = _mathFollowUp(studentMessage, stage);
    if (follow != null) return follow;

    final solved = solveSchoolMath(studentMessage);
    if (solved == null) return null;

    if (wantsMathHint(studentMessage) && !wantsFullMathSteps(studentMessage)) {
      _activeMath = solved;
      _awaitingMath = solved;
      return TutorResponse(
        stage: stage,
        text: solved.hintMessage,
        followUpPrompt: 'Try it, then tell me your answer.',
        topic: _currentTopic.isEmpty ? 'mathematics' : _currentTopic,
        mathCoach: true,
      );
    }

    return _emitWorked(solved, stage);
  }

  TutorResponse? _mathFollowUp(String studentMessage, TutorStage stage) {
    if (_activeMath == null && _awaitingMath == null) return null;

    if (!isMathCoachingFollowUp(studentMessage)) {
      if (solveSchoolMath(studentMessage) == null &&
          !_isContinuingThread(studentMessage)) {
        _clearMath();
      }
      return null;
    }

    final target = _awaitingMath ?? _activeMath;
    if (target == null) return null;

    if (wantsMathHint(studentMessage)) {
      return TutorResponse(
        stage: stage,
        text: target.hintMessage,
        followUpPrompt: 'Try it, then tell me your answer.',
        topic: 'mathematics',
        mathCoach: true,
      );
    }

    if (wantsFullMathSteps(studentMessage)) {
      final show = _practiceMiss
          ? (_awaitingMath ?? _activeMath)
          : (_activeMath ?? _awaitingMath);
      _practiceMiss = false;
      if (show == null) return null;
      return _emitWorked(show, stage);
    }

    final attempt = extractNumericAttempt(studentMessage);
    if (attempt == null) return null;
    final expected = target.numericAnswer;
    if (expected == null) return null;

    if (nearlyEqual(attempt, expected)) {
      _practiceMiss = false;
      final next = solveSchoolMath(target.practiceQuestion);
      _activeMath = target;
      _awaitingMath = next;
      return TutorResponse(
        stage: TutorStage.practice,
        text: "That's right — ${target.answer}. Here is the method so it sticks:",
        followUpPrompt: next == null
            ? 'Want another problem like this?'
            : 'Your turn — try this: ${target.practiceQuestion}',
        topic: 'mathematics',
        math: target,
        mathCoach: true,
      );
    }

    _practiceMiss = true;
    return TutorResponse(
      stage: TutorStage.practice,
      text: "Not quite. ${target.hintMessage}",
      followUpPrompt: 'Have another go, or ask me to show the full steps.',
      topic: 'mathematics',
      mathCoach: true,
    );
  }

  TutorResponse _emitWorked(SchoolMathSolution solved, TutorStage stage) {
    _activeMath = solved;
    _awaitingMath = solveSchoolMath(solved.practiceQuestion);
    return TutorResponse(
      stage: stage,
      text: solved.fullPlan,
      followUpPrompt: 'Your turn — try this: ${solved.practiceQuestion}',
      topic: _currentTopic.isEmpty ? 'mathematics' : _currentTopic,
      math: solved,
      mathCoach: true,
    );
  }
}

class SessionAnalysis {
  const SessionAnalysis({required this.summary, this.strength, this.weakness});
  final String summary;
  final String? strength;
  final String? weakness;
}

class _Turn {
  _Turn({required this.role, required this.text, this.recap = ''});
  final String role;
  final String text;
  final String recap;
}
