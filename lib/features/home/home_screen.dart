import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../db/providers/db_provider.dart';

final _desktopNameProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('student_name') ?? 'Learner';
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String name;
    if (kIsWeb) {
      name = ref.watch(_desktopNameProvider).valueOrNull ?? 'Learner';
    } else {
      final studentAsync = ref.watch(activeStudentProvider);
      name = studentAsync.valueOrNull?.name ?? 'Learner';
    }

    final ac = AppColors.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/branding/otic-studio-logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Connect Africa',
                          style: TextStyle(
                            fontFamily: 'Saira',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: ac.textPrimary,
                          ),
                        ),
                        Text(
                          'Learn, Create & Build',
                          style: TextStyle(fontSize: 13, color: ac.textHint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: ac.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ac.border),
                  boxShadow: ac.softShadow(ac.isDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $name!',
                      style: TextStyle(
                        fontFamily: 'Saira',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ac.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'What would you like to do today?',
                      style: TextStyle(fontSize: 13, color: ac.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const _SectionLabel('LEARN'),
              const SizedBox(height: 12),
              const Row(
                children: [
                  _IconCard(
                    icon: Icons.menu_book_rounded,
                    label: 'Subjects',
                    color: AppColors.learnColor,
                    route: '/learn',
                  ),
                  _IconCard(
                    icon: Icons.quiz_rounded,
                    label: 'Practice',
                    color: AppColors.practiceColor,
                    route: '/practice',
                  ),
                  _IconCard(
                    icon: Icons.chat_rounded,
                    label: 'AI Chat',
                    color: AppColors.primary,
                    route: '/chat',
                  ),
                  _IconCard(
                    icon: Icons.school_rounded,
                    label: 'Teach',
                    color: AppColors.teachColor,
                    route: '/teach',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const _SectionLabel('CREATE'),
              const SizedBox(height: 12),
              const Row(
                children: [
                  _IconCard(
                    icon: Icons.web_rounded,
                    label: 'Site Builder',
                    color: AppColors.createColor,
                    route: '/sitechat',
                  ),
                  _IconCard(
                    icon: Icons.code_rounded,
                    label: 'Web Dev',
                    color: AppColors.practiceColor,
                    route: '/weblab',
                  ),
                  _IconCard(
                    icon: Icons.terminal_rounded,
                    label: 'Python',
                    color: AppColors.accentDeep,
                    route: '/pythonlab',
                  ),
                  _IconCard(
                    icon: Icons.phone_android_rounded,
                    label: 'App Dev',
                    color: AppColors.learnColor,
                    route: '/applab',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const _SectionLabel('MORE'),
              const SizedBox(height: 12),
              const Row(
                children: [
                  _IconCard(
                    icon: Icons.folder_rounded,
                    label: 'Projects',
                    color: AppColors.secondary,
                    route: '/projects',
                  ),
                  _IconCard(
                    icon: Icons.emoji_events_rounded,
                    label: 'Badges',
                    color: AppColors.gold,
                    route: '/achievements',
                  ),
                  _IconCard(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Certs',
                    color: AppColors.primaryLight,
                    route: '/certificates',
                  ),
                  _IconCard(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    color: AppColors.lifeSkillsColor,
                    route: '/settings',
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: ac.textHint,
      ),
    );
  }
}

class _IconCard extends StatelessWidget {
  const _IconCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });
  final IconData icon;
  final String label;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () => context.push(route),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ac.border),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: ac.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
