import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../curriculum/curriculum_provider.dart';
import '../../curriculum/curriculum_models.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  static const _icons = <String, IconData>{
    'calculate': Icons.calculate,
    'science': Icons.science,
    'biotech': Icons.biotech,
    'science_outlined': Icons.science_outlined,
    'code': Icons.code,
    'web': Icons.web,
    'phone_android': Icons.phone_android,
    'psychology': Icons.psychology,
    'trending_up': Icons.trending_up,
    'grass': Icons.grass,
    'history_edu': Icons.history_edu,
    'public': Icons.public,
    'menu_book': Icons.menu_book,
    'account_balance': Icons.account_balance,
    'palette': Icons.palette,
  };

  static Color _parseColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(allSubjectsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Learn')),
      body: subjectsAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading subjects: $e')),
        data: (subjects) => GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
          ),
          itemCount: subjects.length,
          itemBuilder: (context, i) {
            final s = subjects[i];
            final color = _parseColor(s.color);
            final icon = _icons[s.icon] ?? Icons.menu_book;
            return _SubjectCard(
              name: s.name,
              icon: icon,
              color: color,
              lessonCount: s.totalLessons,
              onTap: () => context.push('/learn/subject/${s.id}'),
            );
          },
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.name,
    required this.icon,
    required this.color,
    required this.lessonCount,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final Color color;
  final int lessonCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  '$lessonCount lessons',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
