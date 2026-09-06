import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../db/otic_database.dart';
import '../../db/providers/db_provider.dart';
import '../../features/learn/path/path_models.dart';
import '../../features/learn/path/path_provider.dart';
import '../../l10n/app_locale.dart';
import '../../shared/widgets/studio_page.dart';

final _desktopNameProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('student_name') ?? 'Learner';
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String name;
    Student? student;
    if (kIsWeb) {
      name = ref.watch(_desktopNameProvider).valueOrNull ?? 'Learner';
    } else {
      final studentAsync = ref.watch(activeStudentProvider);
      student = studentAsync.valueOrNull;
      name = student?.name ?? 'Learner';
    }

    final paths = ref.watch(studentPathsProvider).valueOrNull ?? const [];
    final parsedPaths = paths.map(parsedFromRow).toList();
    final continuePath = _pickContinuePath(parsedPaths);
    final lessonsCompleted =
        parsedPaths.fold<int>(0, (sum, p) => sum + p.completedLessons);
    final lessonsTotal =
        parsedPaths.fold<int>(0, (sum, p) => sum + p.totalLessons);
    final overallProgress =
        lessonsTotal == 0 ? 0.0 : lessonsCompleted / lessonsTotal;
    final todayDone = continuePath?.completedLessons ?? 0;
    final todayGoal = continuePath == null
        ? 5
        : (continuePath.totalLessons == 0 ? 5 : continuePath.totalLessons)
            .clamp(1, 5);
    final todayProgress =
        (todayDone.clamp(0, todayGoal)) / todayGoal;

    final bottomPad = MediaQuery.paddingOf(context).bottom + 100;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudioPageHeader(
                title: trFill(context, 'Hello, {name}!', {'name': name}),
                subtitle: tr(context, 'Keep learning, keep growing'),
                showNotifications: true,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              _JourneyHeroCard(
                name: name,
                progress: todayProgress,
                completed: todayDone.clamp(0, todayGoal),
                goal: todayGoal,
                onContinue: () => _openContinue(context, continuePath),
              ),
              const SizedBox(height: 16),
              _StatsRow(
                streakDays: student?.streakDays ?? 0,
                lessonsCompleted: lessonsCompleted,
                points: student?.totalPoints ?? 0,
                overallProgress: overallProgress,
              ),
              const SizedBox(height: 28),
              StudioSectionHeader(
                title: tr(context, 'Learn'),
                onAction: () => context.go('/learn'),
              ),
              const SizedBox(height: 14),
              const _LearnGrid(),
              const SizedBox(height: 28),
              StudioSectionHeader(
                title: tr(context, 'Continue Learning'),
                onAction: () => context.go('/learn'),
              ),
              const SizedBox(height: 14),
              _ContinueLearningCard(
                path: continuePath,
                onTap: () => _openContinue(context, continuePath),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static ParsedPath? _pickContinuePath(List<ParsedPath> paths) {
    if (paths.isEmpty) return null;
    final inProgress = paths.where((p) => p.progressFraction < 1).toList();
    if (inProgress.isEmpty) return paths.first;
    inProgress.sort((a, b) => b.completedLessons.compareTo(a.completedLessons));
    return inProgress.first;
  }

  static void _openContinue(BuildContext context, ParsedPath? path) {
    if (path == null) {
      context.go('/learn');
      return;
    }
    context.push('/path/${Uri.encodeComponent(path.topic)}');
  }
}

class _JourneyHeroCard extends StatelessWidget {
  const _JourneyHeroCard({
    required this.name,
    required this.progress,
    required this.completed,
    required this.goal,
    required this.onContinue,
  });

  final String name;
  final double progress;
  final int completed;
  final int goal;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ac.isDark
              ? const [Color(0xFF1A2E44), Color(0xFF152536)]
              : const [Color(0xFFE8F4FF), Color(0xFFF5FAFF)],
        ),
        border: Border.all(color: ac.border),
        boxShadow: ac.softShadow(ac.isDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 11,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'YOUR LEARNING JOURNEY'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: AppColors.primary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trFill(context, 'Welcome, {name}!', {'name': name}),
                      style: TextStyle(
                        fontFamily: 'Saira',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: ac.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        context,
                        'Great to have you back. Keep building your future, one lesson at a time.',
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: ac.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr(context, "Today's Progress"),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ac.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: AppColors.primary
                                  .withValues(alpha: 0.15),
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          trFill(
                            context,
                            '{completed} / {goal} lessons',
                            {
                              'completed': '$completed',
                              'goal': '$goal',
                            },
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ac.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tr(context, 'Continue Learning'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/illustrations/home-secondary-learner.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 12,
                    child: Text(
                      tr(context, 'Better Skills,\nBrighter Future'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Saira',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.streakDays,
    required this.lessonsCompleted,
    required this.points,
    required this.overallProgress,
  });

  final int streakDays;
  final int lessonsCompleted;
  final int points;
  final double overallProgress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF8A3D),
            iconBg: const Color(0xFFFFF0E6),
            value: '$streakDays',
            label: tr(context, 'Day Streak'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF2EBB6E),
            iconBg: const Color(0xFFE8F8EF),
            value: '$lessonsCompleted',
            label: tr(context, 'Lessons Completed'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.star_rounded,
            iconColor: AppColors.primary,
            iconBg: const Color(0xFFE8F3FC),
            value: '$points',
            label: tr(context, 'Points'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFF2EBB6E),
            iconBg: const Color(0xFFE8F8EF),
            value: '${(overallProgress * 100).round()}%',
            label: tr(context, 'Overall Progress'),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: ac.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ac.border),
        boxShadow: ac.softShadow(ac.isDark),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ac.isDark ? iconColor.withValues(alpha: 0.18) : iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Saira',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ac.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: ac.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnGrid extends StatelessWidget {
  const _LearnGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      _LearnItem(
        title: tr(context, 'Subjects'),
        subtitle: tr(context, 'Explore your courses'),
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF3B8FE8),
        background: const Color(0xFFE8F2FF),
        route: '/learn',
      ),
      _LearnItem(
        title: tr(context, 'Practice'),
        subtitle: tr(context, 'Sharpen your skills'),
        icon: Icons.fact_check_rounded,
        color: const Color(0xFF2EBB6E),
        background: const Color(0xFFE8F8EF),
        route: '/practice',
      ),
      _LearnItem(
        title: tr(context, 'AI Chat'),
        subtitle: tr(context, 'Get instant help'),
        icon: Icons.smart_toy_rounded,
        color: const Color(0xFF7B6CF6),
        background: const Color(0xFFF0EDFF),
        route: '/chat',
      ),
      _LearnItem(
        title: tr(context, 'Teach'),
        subtitle: tr(context, 'Share your knowledge'),
        icon: Icons.school_rounded,
        color: const Color(0xFF2EB8A0),
        background: const Color(0xFFE6F8F4),
        route: '/teach',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, i) => _LearnTile(item: items[i]),
    );
  }
}

class _LearnItem {
  const _LearnItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.background,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color background;
  final String route;
}

class _LearnTile extends StatelessWidget {
  const _LearnTile({required this.item});

  final _LearnItem item;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: ac.isDark ? item.color.withValues(alpha: 0.14) : item.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => context.push(item.route),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: item.color, size: 28),
              const Spacer(),
              Text(
                item.title,
                style: TextStyle(
                  fontFamily: 'Saira',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ac.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: ac.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: item.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({required this.path, required this.onTap});

  final ParsedPath? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final title = path?.title ?? tr(context, 'Start a learning path');
    final subtitle = path == null
        ? tr(context, 'Pick a subject and begin your first lesson')
        : _chapterLabel(path!);
    final done = path?.completedLessons ?? 0;
    final total = path?.totalLessons == 0 ? 5 : (path?.totalLessons ?? 5);
    final progress = total == 0 ? 0.0 : done / total;
    final tag = path?.topic ?? tr(context, 'Learn');

    return Material(
      color: ac.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ac.border),
            boxShadow: ac.softShadow(ac.isDark),
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5BB3F5), AppColors.accentDeep],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 10,
                      right: 8,
                      child: CustomPaint(
                        size: const Size(28, 28),
                        painter: _TrianglePainter(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      right: 10,
                      child: Text(
                        tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Saira',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ac.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: ac.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trFill(
                        context,
                        '{done} / {total} lessons',
                        {'done': '$done', 'total': '$total'},
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ac.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _chapterLabel(ParsedPath path) {
    for (var u = 0; u < path.units.length; u++) {
      final unit = path.units[u];
      for (var l = 0; l < unit.lessons.length; l++) {
        if (!unit.lessons[l].isCompleted) {
          return 'Chapter ${u + 1}: ${unit.title}';
        }
      }
    }
    if (path.units.isEmpty) return path.description;
    return 'Chapter ${path.units.length}: ${path.units.last.title}';
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
