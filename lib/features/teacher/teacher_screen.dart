import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../db/otic_database.dart';
import '../../db/providers/db_provider.dart';
import '../../features/learn/path/path_provider.dart';
import '../../shared/widgets/responsive.dart';

class TeacherScreen extends ConsumerWidget {
  const TeacherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(activeStudentProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Teacher Portal')),
      body: studentAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (student) {
          if (student == null) {
            return const _NoStudents();
          }
          return _StudentDashboard(student: student);
        },
      ),
    );
  }
}

class _StudentDashboard extends ConsumerWidget {
  const _StudentDashboard({required this.student});
  final Student student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(studentPathsProvider);
    final badgesAsync = ref.watch(earnedBadgesProvider(student.id));
    final sessionsAsync = ref.watch(recentSessionsProvider(student.id));
    final progressAsync = ref.watch(topicProgressProvider(student.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: MaxWidth(
          maxWidth: 900,
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student profile card
          _ProfileCard(student: student),
          SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              Expanded(
                child: pathsAsync.when(
                  data: (rows) => _StatBox(
                    icon: Icons.route,
                    label: 'Paths Started',
                    value: '${rows.length}',
                    color: AppColors.learnColor,
                  ),
                  loading: () => const _StatBox(icon: Icons.route, label: 'Paths', value: '…', color: AppColors.learnColor),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: badgesAsync.when(
                  data: (b) => _StatBox(
                    icon: Icons.emoji_events,
                    label: 'Badges',
                    value: '${b.length}',
                    color: Colors.amber,
                  ),
                  loading: () => const _StatBox(icon: Icons.emoji_events, label: 'Badges', value: '…', color: Colors.amber),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  icon: Icons.local_fire_department,
                  label: 'Streak',
                  value: '${student.streakDays}d',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Learning paths progress
          pathsAsync.when(
            data: (rows) {
              if (rows.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Learning Paths'),
                  ...rows.map((row) => _PathRow(row: row)),
                  SizedBox(height: 16),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Topic mastery
          progressAsync.when(
            data: (progress) {
              if (progress.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Topic Mastery'),
                  ...progress.take(8).map((p) => _MasteryRow(progress: p)),
                  SizedBox(height: 16),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Recent sessions
          sessionsAsync.when(
            data: (sessions) {
              if (sessions.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Recent Sessions'),
                  ...sessions.take(5).map((s) => _SessionRow(session: s)),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          SizedBox(height: 40),
        ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.student});
  final Student student;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.teachColor, Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white24,
            child: Text(
              student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 22),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18)),
                Text(
                  [
                    if (student.grade != null) student.grade!,
                    if (student.age != null) 'Age ${student.age}',
                  ].join(' · '),
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  'Learning style: ${student.learningStyle}',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Icon(Icons.stars, color: Colors.amber, size: 20),
              Text('${student.totalPoints}',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              Text('pts',
                  style: TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({required this.row});
  final dynamic row;

  @override
  Widget build(BuildContext context) {
    final pct = row.totalLessons > 0
        ? row.completedLessons / row.totalLessons
        : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.topic,
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                '${row.completedLessons}/${row.totalLessons}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.learnColor),
              ),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct.toDouble(),
              minHeight: 5,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.learnColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({required this.progress});
  final dynamic progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              progress.topic,
              style: TextStyle(
                  fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (progress.level as int) / 100,
                minHeight: 8,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.practiceColor),
              ),
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              '${progress.level}',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.practiceColor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});
  final dynamic session;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(session.topic,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface)),
              const Spacer(),
              Text(
                '${session.highestStage} · ${session.messageCount} msgs',
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).hintColor),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            session.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _NoStudents extends StatelessWidget {
  const _NoStudents();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, size: 56, color: Theme.of(context).hintColor),
            SizedBox(height: 16),
            Text('No student profiles yet',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              'Students must complete onboarding before their data appears here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
