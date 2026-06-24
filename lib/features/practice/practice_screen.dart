import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../curriculum/curriculum_models.dart';
import '../../curriculum/curriculum_provider.dart';
import '../../db/providers/db_provider.dart';
import '../../shared/widgets/responsive.dart';
import 'exercise_models.dart';
import 'practice_providers.dart';
import 'scenario_models.dart';

// ── Topic list ────────────────────────────────────────────────────────────────

const _topics = [
  'Mathematics',
  'Physics',
  'Biology',
  'Chemistry',
  'Programming',
  'Web Development',
  'App Development',
  'AI & Data',
  'Entrepreneurship',
  'Agriculture',
  'History',
  'Geography',
  'English Writing',
  'Economics',
  'Arts',
  'Project Ignite AI',
];

// ── Root screen ───────────────────────────────────────────────────────────────

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Practice'),
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.quiz_outlined), text: 'Practice'),
              Tab(icon: Icon(Icons.explore_outlined), text: 'Apply'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        body: const MaxWidth(
          child: TabBarView(children: [_PracticeTab(), _ApplyTab()]),
        ),
      ),
    );
  }
}

// ── Shared topic picker ───────────────────────────────────────────────────────

class _TopicPicker extends ConsumerWidget {
  const _TopicPicker({
    required this.selected,
    required this.onSelect,
    required this.color,
  });

  final String selected;
  final void Function(String) onSelect;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Merge student interests with fixed topic list
    final studentAsync = ref.watch(activeStudentProvider);
    final studentInterests =
        studentAsync.valueOrNull?.interestsJson
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    final allTopics = [
      ...studentInterests.where((i) => !_topics.contains(i)),
      ..._topics,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: DropdownButtonFormField<String>(
        value: selected.isEmpty ? null : selected,
        decoration: InputDecoration(
          labelText: 'Choose a topic',
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: color, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        dropdownColor: Theme.of(context).colorScheme.surface,
        isExpanded: true,
        hint: Text('Select a topic', style: TextStyle(color: Theme.of(context).hintColor)),
        items: allTopics
            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
            .toList(),
        onChanged: (v) {
          if (v != null) onSelect(v);
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PRACTICE TAB — Multiple choice exercises
// ══════════════════════════════════════════════════════════════════════════════

class _PracticeTab extends ConsumerStatefulWidget {
  const _PracticeTab();

  @override
  ConsumerState<_PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends ConsumerState<_PracticeTab> {
  String _selectedTopic = '';
  List<QuizQuestion> _questions = [];
  int _currentQ = 0;
  int? _selectedAnswer;
  int _score = 0;
  int _total = 0;
  bool _answered = false;

  void _loadQuestions(String topic) async {
    final curriculum = ref.read(curriculumServiceProvider);
    await curriculum.loadAll();

    final subjectId = _topicToSubjectId(topic);
    final subject = await curriculum.load(subjectId);
    if (subject == null) return;

    final allQuiz = <QuizQuestion>[];
    for (final unit in subject.units) {
      for (final lesson in unit.lessons) {
        allQuiz.addAll(lesson.quiz);
      }
    }
    allQuiz.shuffle();

    setState(() {
      _selectedTopic = topic;
      _questions = allQuiz.take(10).toList();
      _currentQ = 0;
      _selectedAnswer = null;
      _answered = false;
      _score = 0;
      _total = 0;
    });
  }

  String _topicToSubjectId(String topic) {
    final map = {
      'Mathematics': 'mathematics', 'Physics': 'physics', 'Biology': 'biology',
      'Chemistry': 'chemistry', 'Programming': 'programming',
      'Web Development': 'web_development', 'App Development': 'app_development',
      'AI & Data': 'ai_and_data', 'Entrepreneurship': 'entrepreneurship',
      'Agriculture': 'agriculture', 'History': 'history', 'Geography': 'geography',
      'English Writing': 'english_writing', 'Economics': 'economics', 'Arts': 'arts', 'Project Ignite AI': 'ignite_ai',
    };
    return map[topic] ?? topic.toLowerCase().replaceAll(' ', '_');
  }

  void _answer(int index) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      _total++;
      if (index == _questions[_currentQ].correct) _score++;
    });
  }

  void _next() {
    if (_currentQ < _questions.length - 1) {
      setState(() {
        _currentQ++;
        _selectedAnswer = null;
        _answered = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedTopic.isEmpty) {
      return SingleChildScrollView(
        child: Column(
          children: [
            _TopicPicker(
              selected: _selectedTopic,
              color: AppColors.primary,
              onSelect: _loadQuestions,
            ),
            SizedBox(height: 40),
          ],
        ),
      );
    }

    if (_questions.isEmpty) {
      return Center(child: Text('No questions found for $_selectedTopic'));
    }

    // Done
    if (_currentQ >= _questions.length - 1 && _answered) {
      final allDone = _total == _questions.length;
      if (allDone) {
        return _QuizResult(
          score: _score,
          total: _questions.length,
          onRestart: () => _loadQuestions(_selectedTopic),
          onChangeTopic: () => setState(() { _selectedTopic = ''; _questions = []; }),
        );
      }
    }

    final q = _questions[_currentQ];
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(_selectedTopic, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
              Spacer(),
              Text('${_currentQ + 1}/${_questions.length}', style: TextStyle(color: Theme.of(context).hintColor)),
            ],
          ),
          SizedBox(height: 4),
          LinearProgressIndicator(
            value: (_currentQ + 1) / _questions.length,
            backgroundColor: Theme.of(context).dividerColor,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
          SizedBox(height: 8),
          Text('Score: $_score/$_total', style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
          SizedBox(height: 20),

          // Question
          Text(q.question, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4, color: Theme.of(context).colorScheme.onSurface)),
          SizedBox(height: 16),

          // Options
          ...q.options.asMap().entries.map((e) {
            final oi = e.key;
            final option = e.value;
            final isSelected = _selectedAnswer == oi;
            final isCorrect = oi == q.correct;

            Color borderColor = Theme.of(context).dividerColor;
            Color bgColor = Colors.transparent;

            if (_answered) {
              if (isCorrect) {
                borderColor = AppColors.teachColor;
                bgColor = AppColors.teachColor.withValues(alpha: 0.08);
              } else if (isSelected) {
                borderColor = Colors.red;
                bgColor = Colors.red.withValues(alpha: 0.06);
              }
            } else if (isSelected) {
              borderColor = AppColors.primary;
              bgColor = AppColors.primary.withValues(alpha: 0.06);
            }

            return GestureDetector(
              onTap: () => _answer(oi),
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Text(String.fromCharCode(65 + oi), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    SizedBox(width: 12),
                    Expanded(child: Text(option, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface))),
                    if (_answered && isCorrect) Icon(Icons.check_circle, size: 18, color: AppColors.teachColor),
                    if (_answered && isSelected && !isCorrect) Icon(Icons.cancel, size: 18, color: Colors.red),
                  ],
                ),
              ),
            );
          }),

          // Explanation
          if (_answered) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_selectedAnswer == q.correct ? AppColors.teachColor : Colors.red).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(q.explanation, style: TextStyle(fontSize: 13, height: 1.4, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _next,
                icon: Icon(Icons.arrow_forward),
                label: Text(_currentQ < _questions.length - 1 ? 'Next Question' : 'See Results'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizResult extends StatelessWidget {
  const _QuizResult({required this.score, required this.total, required this.onRestart, required this.onChangeTopic});
  final int score, total;
  final VoidCallback onRestart, onChangeTopic;

  @override
  Widget build(BuildContext context) {
    final percent = (score / total * 100).round();
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$score/$total', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: AppColors.teachColor)),
            Text('$percent%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.teachColor)),
            SizedBox(height: 8),
            Text(
              percent >= 80 ? 'Excellent!' : percent >= 60 ? 'Good job!' : 'Keep practicing!',
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
            ),
            SizedBox(height: 24),
            FilledButton.icon(onPressed: onRestart, icon: Icon(Icons.refresh), label: Text('Try Again'), style: FilledButton.styleFrom(backgroundColor: AppColors.primary)),
            SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onChangeTopic, icon: Icon(Icons.swap_horiz), label: Text('Change Subject')),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.state,
    required this.onAnswer,
    required this.onNext,
    required this.onReset,
  });

  final Exercise exercise;
  final PracticeState state;
  final void Function(int) onAnswer;
  final VoidCallback onNext;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.stars,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Score: ${state.score}/${state.total}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onReset,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Reset',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Question
          Text(
            exercise.question,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          SizedBox(height: 20),

          // Options
          ...exercise.options.asMap().entries.map(
            (e) => _OptionButton(
              label: _letter(e.key),
              text: e.value,
              index: e.key,
              state: state,
              onTap: () => onAnswer(e.key),
            ),
          ),

          // Feedback
          if (state.answered) ...[
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: state.correct
                    ? AppColors.teachColor.withValues(alpha: 0.08)
                    : Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.correct
                      ? AppColors.teachColor.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    state.correct ? Icons.check_circle : Icons.cancel,
                    color: state.correct ? AppColors.teachColor : Colors.red,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.correct ? 'Correct!' : 'Not quite.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: state.correct
                                ? AppColors.teachColor
                                : Colors.red,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          exercise.explanation,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNext,
                icon: Icon(Icons.arrow_forward),
                label: Text('Next question'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _letter(int i) => ['A', 'B', 'C', 'D'][i];
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.text,
    required this.index,
    required this.state,
    required this.onTap,
  });

  final String label;
  final String text;
  final int index;
  final PracticeState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color borderColor = Theme.of(context).dividerColor;
    Color bgColor = Theme.of(context).colorScheme.surface;
    Color textColor = Theme.of(context).colorScheme.onSurface;

    if (state.answered) {
      if (index == state.exercise!.correctIndex) {
        borderColor = AppColors.teachColor;
        bgColor = AppColors.teachColor.withValues(alpha: 0.07);
        textColor = AppColors.teachColor;
      } else if (index == state.selectedOption) {
        borderColor = Colors.red;
        bgColor = Colors.red.withValues(alpha: 0.05);
        textColor = Colors.red;
      }
    } else if (index == state.selectedOption) {
      borderColor = AppColors.primary;
      bgColor = AppColors.primary.withValues(alpha: 0.07);
      textColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: state.answered ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: borderColor,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: textColor, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// APPLY TAB — Real-world scenarios
// ══════════════════════════════════════════════════════════════════════════════

class _ApplyTab extends ConsumerStatefulWidget {
  const _ApplyTab();

  @override
  ConsumerState<_ApplyTab> createState() => _ApplyTabState();
}

class _ApplyTabState extends ConsumerState<_ApplyTab> {
  final _responseController = TextEditingController();

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(applyProvider);

    // Sync text controller when state resets
    ref.listen(applyProvider, (prev, next) {
      if (next.response.isEmpty && _responseController.text.isNotEmpty) {
        _responseController.clear();
      }
    });

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopicPicker(
            selected: state.topic,
            color: AppColors.primary,
            onSelect: (t) {
              ref.read(applyProvider.notifier).setTopic(t);
            },
          ),
          SizedBox(height: 16),

          if (state.topic.isNotEmpty &&
              state.scenario == null &&
              !state.isGeneratingScenario)
            _StartCard(
              topic: state.topic,
              color: AppColors.primary,
              icon: Icons.explore,
              label: 'Give me a scenario',
              onTap: () => ref.read(applyProvider.notifier).generateScenario(),
            ),

          if (state.isGeneratingScenario)
            const _LoadingCard(message: 'Creating scenario…'),

          if (state.error != null)
            _ErrorCard(
              message: state.error!,
              onRetry: () =>
                  ref.read(applyProvider.notifier).generateScenario(),
            ),

          if (state.scenario != null)
            _ScenarioCard(
              scenario: state.scenario!,
              state: state,
              responseController: _responseController,
              onResponseChanged: (t) =>
                  ref.read(applyProvider.notifier).setResponse(t),
              onSubmit: () => ref.read(applyProvider.notifier).evaluate(),
              onNext: () => ref.read(applyProvider.notifier).nextScenario(),
            ),

          SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.state,
    required this.responseController,
    required this.onResponseChanged,
    required this.onSubmit,
    required this.onNext,
  });

  final Scenario scenario;
  final ApplyState state;
  final TextEditingController responseController;
  final void Function(String) onResponseChanged;
  final VoidCallback onSubmit;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Situation card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.place,
                      size: 15,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'SCENARIO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  scenario.situation,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Challenge question
          Text(
            scenario.challenge,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          SizedBox(height: 16),

          // Response input
          if (state.feedback == null) ...[
            TextField(
              controller: responseController,
              onChanged: onResponseChanged,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe what you would do and why…',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: state.isEvaluating
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: state.response.trim().isEmpty
                          ? null
                          : onSubmit,
                      icon: Icon(Icons.send),
                      label: Text('Submit my response'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
            ),
          ],

          // Feedback
          if (state.feedback != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'AI Feedback',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    state.feedback!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNext,
                icon: Icon(Icons.refresh),
                label: Text('New scenario'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared utility widgets ────────────────────────────────────────────────────

class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.topic,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String topic;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            SizedBox(height: 14),
            Text(
              topic,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: FilledButton.styleFrom(backgroundColor: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(message, style: TextStyle(color: Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            TextButton(onPressed: onRetry, child: Text('Retry')),
          ],
        ),
      ),
    );
  }
}
