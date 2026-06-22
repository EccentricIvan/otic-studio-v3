import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../db/providers/db_provider.dart';
import '../../shared/widgets/responsive.dart';
import 'exercise_models.dart';
import 'practice_providers.dart';
import 'scenario_models.dart';

// ── Topic list ────────────────────────────────────────────────────────────────

const _topics = [
  'Photosynthesis',
  'Python Programming',
  'Mathematics',
  'Physics',
  'Entrepreneurship',
  'Biology',
  'English Writing',
  'Artificial Intelligence',
  'History',
  'Economics',
  'Chemistry',
  'Geography',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Choose a topic',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allTopics.map((topic) {
              final isSelected = selected == topic;
              return ChoiceChip(
                label: Text(topic),
                selected: isSelected,
                onSelected: (_) => onSelect(topic),
                selectedColor: color.withValues(alpha: 0.15),
                side: BorderSide(color: isSelected ? color : Theme.of(context).dividerColor),
                labelStyle: TextStyle(
                  color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                checkmarkColor: color,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PRACTICE TAB — Multiple choice exercises
// ══════════════════════════════════════════════════════════════════════════════

class _PracticeTab extends ConsumerWidget {
  const _PracticeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(practiceProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopicPicker(
            selected: state.topic,
            color: AppColors.primary,
            onSelect: (t) {
              ref.read(practiceProvider.notifier).setTopic(t);
            },
          ),
          SizedBox(height: 16),
          if (state.topic.isNotEmpty &&
              state.exercise == null &&
              !state.isGenerating)
            _StartCard(
              topic: state.topic,
              color: AppColors.primary,
              icon: Icons.quiz,
              label: 'Generate exercise',
              onTap: () => ref.read(practiceProvider.notifier).generate(),
            ),
          if (state.isGenerating)
            const _LoadingCard(message: 'Creating exercise…'),
          if (state.error != null)
            _ErrorCard(
              message: state.error!,
              onRetry: () => ref.read(practiceProvider.notifier).generate(),
            ),
          if (state.exercise != null)
            _ExerciseCard(
              exercise: state.exercise!,
              state: state,
              onAnswer: (i) => ref.read(practiceProvider.notifier).answer(i),
              onNext: () => ref.read(practiceProvider.notifier).next(),
              onReset: () => ref.read(practiceProvider.notifier).reset(),
            ),
          SizedBox(height: 40),
        ],
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
