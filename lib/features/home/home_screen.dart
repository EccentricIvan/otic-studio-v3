import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../db/providers/db_provider.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/learning_mode_card.dart';
import '../../shared/widgets/learning_path_card.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/voice_ask_widget.dart';
import '../learn/path/path_models.dart';
import '../learn/path/path_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/branding/otic_logo.png',
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          semanticLabel: 'Logo',
        ),
        actions: [SizedBox(width: 48)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroSection(),
                SizedBox(height: 32),
                const SectionHeader(
                  title: 'Start Learning',
                  subtitle: 'Choose how you want to learn today',
                ),
                SizedBox(height: 12),
                _LearningModesGrid(),
                SizedBox(height: 32),
                const _RecommendedSection(),
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.practiceColor.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, size: 13, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'Fully Offline · No Internet Required',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Learn anything,\nanywhere',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          SizedBox(height: 10),
          Text(
            'Your AI mentor — always available, always patient, always learning with you.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: 20),
          VoiceAskWidget(
            onSubmit: (query) {
              context.go('/learn?topic=${Uri.encodeComponent(query)}');
            },
          ),
        ],
      ),
    );
  }
}

class _LearningModesGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final modes = [
      const _Mode(
        'Learn',
        'Browse 300 lessons across 15 subjects',
        Icons.menu_book,
        AppColors.learnColor,
        '/learn',
      ),
      const _Mode(
        'Practice',
        'Exercises and quizzes to test knowledge',
        Icons.edit,
        AppColors.practiceColor,
        '/practice',
      ),
      const _Mode(
        'Create',
        'Build projects guided step by step',
        Icons.lightbulb,
        AppColors.createColor,
        '/create',
      ),
      const _Mode(
        'Web Dev Lab',
        'Write HTML, CSS, JS and see it live',
        Icons.code,
        AppColors.practiceColor,
        '/weblab',
      ),
      const _Mode(
        'App Dev Lab',
        'Learn to build mobile apps',
        Icons.phone_android,
        AppColors.primary,
        '/applab',
      ),
      const _Mode(
        'Python Lab',
        'Write and run Python code',
        Icons.terminal,
        Color(0xFF3572A5),
        '/pythonlab',
      ),
      const _Mode(
        'Teach',
        'Explain a topic and get a mastery score',
        Icons.record_voice_over,
        AppColors.teachColor,
        '/teach',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 520 ? 4 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: cols == 4 ? 0.75 : 0.82,
          children: modes
              .map(
                (m) => LearningModeCard(
                  title: m.title,
                  description: m.description,
                  icon: m.icon,
                  color: m.color,
                  onTap: () => context.go(m.path),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _Mode {
  const _Mode(this.title, this.description, this.icon, this.color, this.path);

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String path;
}

// ── Recommended / active paths section ───────────────────────────────────────

class _RecommendedSection extends ConsumerWidget {
  const _RecommendedSection();

  static const _suggestedTopics = [
    ('Artificial Intelligence', Icons.psychology, AppColors.technologyColor),
    ('Entrepreneurship', Icons.trending_up, AppColors.businessColor),
    ('Physics', Icons.science, AppColors.academicColor),
    ('Mathematics', Icons.calculate, AppColors.learnColor),
    ('Biology', Icons.biotech, AppColors.agricultureColor),
    ('English Writing', Icons.edit_note, AppColors.lifeSkillsColor),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(activeStudentProvider);
    final pathsAsync = ref.watch(studentPathsProvider);

    return pathsAsync.when(
      data: (rows) {
        final hasPaths = rows.isNotEmpty;
        final paths = rows.map(parsedFromRow).toList();

        // Personalise suggested topics using student interests
        final student = studentAsync.valueOrNull;
        final interests = student != null
            ? (student.interestsJson.isNotEmpty && student.interestsJson != '[]'
                  ? (student.interestsJson
                        .replaceAll('[', '')
                        .replaceAll(']', '')
                        .replaceAll('"', '')
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList())
                  : <String>[])
            : <String>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPaths) ...[
              SectionHeader(
                title: 'Continue Learning',
                subtitle: 'Pick up where you left off',
                actionLabel: 'View all',
                onAction: () => context.go('/learn'),
              ),
              SizedBox(height: 16),
              ...paths
                  .take(3)
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ActivePathCard(
                        path: p,
                        onTap: () => context.push(
                          '/path/${Uri.encodeComponent(p.topic)}',
                        ),
                      ),
                    ),
                  ),
              SizedBox(height: 32),
            ],
            SectionHeader(
              title: hasPaths ? 'Explore New Topics' : 'Start Your First Path',
              subtitle: interests.isNotEmpty
                  ? 'Based on your interests'
                  : 'Popular paths to get started',
              actionLabel: 'Browse',
              onAction: () => context.go('/learn'),
            ),
            SizedBox(height: 16),
            ..._suggestedTopics
                .where((t) => !rows.any((r) => r.topic == t.$1))
                .take(3)
                .map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LearningPathCard(
                      title: t.$1,
                      category: _category(t.$1),
                      description: _desc(t.$1),
                      icon: t.$2,
                      color: t.$3,
                      lessonCount: 12,
                      onTap: () =>
                          context.push('/path/${Uri.encodeComponent(t.$1)}'),
                    ),
                  ),
                ),
          ],
        );
      },
      loading: () => SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _category(String topic) {
    const map = {
      'Artificial Intelligence': 'Technology',
      'Entrepreneurship': 'Business',
      'Physics': 'Academic',
      'Mathematics': 'Academic',
      'Biology': 'Academic',
      'English Writing': 'Life Skills',
    };
    return map[topic] ?? 'General';
  }

  String _desc(String topic) {
    const map = {
      'Artificial Intelligence': 'Understand how AI works and build models',
      'Entrepreneurship': 'Start and grow a business step by step',
      'Physics': 'Explore forces, energy, and the laws of nature',
      'Mathematics': 'Build foundations from arithmetic to calculus',
      'Biology': 'Discover cells, ecosystems, and the science of life',
      'English Writing': 'Write clearly and confidently in any context',
    };
    return map[topic] ?? 'Build a complete understanding of $topic';
  }
}

class _ActivePathCard extends StatelessWidget {
  const _ActivePathCard({required this.path, required this.onTap});
  final ParsedPath path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    path.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.learnColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(path.progressFraction * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.learnColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: path.progressFraction,
                minHeight: 6,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.learnColor,
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${path.completedLessons} of ${path.totalLessons} lessons complete',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }
}
