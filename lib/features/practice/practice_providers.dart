import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_core/providers/ai_provider.dart';
import '../../db/providers/db_provider.dart';
import '../../gamification/badge_service.dart';
import 'exercise_generator.dart';
import 'exercise_models.dart';
import 'scenario_generator.dart';
import 'scenario_models.dart';

// ── Practice (MCQ) session ────────────────────────────────────────────────────

class PracticeState {
  const PracticeState({
    this.topic = '',
    this.exercise,
    this.selectedOption,
    this.answered = false,
    this.score = 0,
    this.total = 0,
    this.isGenerating = false,
    this.error,
  });

  final String topic;
  final Exercise? exercise;
  final int? selectedOption;
  final bool answered;
  final int score;
  final int total;
  final bool isGenerating;
  final String? error;

  bool get correct =>
      answered && selectedOption == exercise?.correctIndex;

  PracticeState copyWith({
    String? topic,
    Exercise? exercise,
    int? selectedOption,
    bool? answered,
    int? score,
    int? total,
    bool? isGenerating,
    String? error,
    bool clearExercise = false,
    bool clearSelected = false,
    bool clearError = false,
  }) =>
      PracticeState(
        topic: topic ?? this.topic,
        exercise: clearExercise ? null : exercise ?? this.exercise,
        selectedOption:
            clearSelected ? null : selectedOption ?? this.selectedOption,
        answered: answered ?? this.answered,
        score: score ?? this.score,
        total: total ?? this.total,
        isGenerating: isGenerating ?? this.isGenerating,
        error: clearError ? null : error ?? this.error,
      );
}

class PracticeNotifier extends AutoDisposeNotifier<PracticeState> {
  @override
  PracticeState build() => const PracticeState();

  void setTopic(String topic) {
    state = const PracticeState().copyWith(topic: topic);
  }

  Future<void> generate() async {
    if (state.topic.isEmpty) return;
    state = state.copyWith(
        isGenerating: true, clearError: true, clearExercise: true, clearSelected: true, answered: false);
    try {
      final engine = await ref.read(engineLoadedProvider.future);
      final student = await ref.read(activeStudentProvider.future);
      final db = ref.read(dbProvider);
      int mastery = 0;
      if (student != null) {
        final progress = await db.sessionDao.getTopicProgress(student.id);
        mastery = progress
            .where((p) => p.topic == state.topic)
            .fold(0, (_, p) => p.level);
      }
      final exercise = await ExerciseGenerator(engine: engine)
          .generate(topic: state.topic, masteryLevel: mastery);
      state = state.copyWith(
          exercise: exercise, isGenerating: false, clearSelected: true, answered: false);
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
    }
  }

  Future<void> answer(int index) async {
    if (state.answered || state.exercise == null) return;
    final wasCorrect = index == state.exercise!.correctIndex;
    final newScore = wasCorrect ? state.score + 1 : state.score;
    state = state.copyWith(
      selectedOption: index,
      answered: true,
      score: newScore,
      total: state.total + 1,
    );

    final student = await ref.read(activeStudentProvider.future);
    if (student != null) {
      await ref.read(badgeServiceProvider).onPracticeAnswered(student.id, newScore);
    }
  }

  Future<void> next() => generate();

  void reset() {
    state = PracticeState(topic: state.topic);
  }
}

final practiceProvider =
    AutoDisposeNotifierProvider<PracticeNotifier, PracticeState>(
        PracticeNotifier.new);

// ── Apply (scenario) session ──────────────────────────────────────────────────

class ApplyState {
  const ApplyState({
    this.topic = '',
    this.scenario,
    this.response = '',
    this.feedback,
    this.isGeneratingScenario = false,
    this.isEvaluating = false,
    this.error,
    this.scenariosEvaluated = 0,
  });

  final String topic;
  final Scenario? scenario;
  final String response;
  final String? feedback;
  final bool isGeneratingScenario;
  final bool isEvaluating;
  final String? error;
  final int scenariosEvaluated;

  ApplyState copyWith({
    String? topic,
    Scenario? scenario,
    String? response,
    String? feedback,
    bool? isGeneratingScenario,
    bool? isEvaluating,
    String? error,
    int? scenariosEvaluated,
    bool clearScenario = false,
    bool clearFeedback = false,
    bool clearError = false,
  }) =>
      ApplyState(
        topic: topic ?? this.topic,
        scenario: clearScenario ? null : scenario ?? this.scenario,
        response: response ?? this.response,
        feedback: clearFeedback ? null : feedback ?? this.feedback,
        isGeneratingScenario:
            isGeneratingScenario ?? this.isGeneratingScenario,
        isEvaluating: isEvaluating ?? this.isEvaluating,
        error: clearError ? null : error ?? this.error,
        scenariosEvaluated: scenariosEvaluated ?? this.scenariosEvaluated,
      );
}

class ApplyNotifier extends AutoDisposeNotifier<ApplyState> {
  @override
  ApplyState build() => const ApplyState();

  void setTopic(String topic) {
    state = const ApplyState().copyWith(topic: topic);
  }

  void setResponse(String text) {
    state = state.copyWith(response: text, clearFeedback: true);
  }

  Future<void> generateScenario() async {
    if (state.topic.isEmpty) return;
    state = state.copyWith(
        isGeneratingScenario: true,
        clearScenario: true,
        clearFeedback: true,
        clearError: true,
        response: '');
    try {
      final engine = await ref.read(engineLoadedProvider.future);
      final scenario =
          await ScenarioGenerator(engine: engine).generate(topic: state.topic);
      state = state.copyWith(scenario: scenario, isGeneratingScenario: false);
    } catch (e) {
      state = state.copyWith(isGeneratingScenario: false, error: e.toString());
    }
  }

  Future<void> evaluate() async {
    final scenario = state.scenario;
    if (scenario == null || state.response.trim().isEmpty) return;
    state = state.copyWith(isEvaluating: true, clearFeedback: true);
    try {
      final engine = await ref.read(engineLoadedProvider.future);
      final feedback = await ScenarioGenerator(engine: engine).evaluate(
        topic: state.topic,
        situation: scenario.situation,
        challenge: scenario.challenge,
        studentResponse: state.response,
      );
      final newCount = state.scenariosEvaluated + 1;
      state = state.copyWith(
        feedback: feedback,
        isEvaluating: false,
        scenariosEvaluated: newCount,
      );

      final student = await ref.read(activeStudentProvider.future);
      if (student != null) {
        await ref.read(badgeServiceProvider).onApplyEvaluated(student.id, newCount);
      }
    } catch (e) {
      state = state.copyWith(isEvaluating: false, error: e.toString());
    }
  }

  void nextScenario() {
    state = ApplyState(topic: state.topic, scenariosEvaluated: state.scenariosEvaluated);
    generateScenario();
  }
}

final applyProvider =
    AutoDisposeNotifierProvider<ApplyNotifier, ApplyState>(ApplyNotifier.new);
