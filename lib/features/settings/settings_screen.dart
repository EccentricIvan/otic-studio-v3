import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ai_core/providers/ai_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../db/providers/db_provider.dart';
import '../../shared/widgets/responsive.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(activeStudentProvider);
    final modelAsync = ref.watch(modelInfoProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: MaxWidth(
        maxWidth: 760,
        child: ListView(
          children: [
            // ── AI Model ─────────────────────────────────────────────────────
            _Section('AI Model', [
              modelAsync.when(
                loading: () => ListTile(
                  leading: Icon(Icons.memory, color: AppColors.primary),
                  title: Text('Checking model…'),
                ),
                error: (_, __) => ListTile(
                  leading: Icon(Icons.memory, color: Colors.red),
                  title: Text('Model check failed'),
                ),
                data: (info) => ListTile(
                  leading: Icon(
                    Icons.memory,
                    color: info.isReady ? AppColors.teachColor : Colors.orange,
                  ),
                  title: Text('Gemma 3 1B'),
                  subtitle: Text(
                    info.isReady
                        ? 'Installed · ${info.platform ?? ''}'
                        : 'Not installed — transfer via USB',
                  ),
                  trailing: info.isReady
                      ? Icon(
                          Icons.check_circle,
                          color: AppColors.teachColor,
                        )
                      : Icon(Icons.warning_amber, color: Colors.orange),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text('Model location'),
                subtitle: Text('Use the model folder on Windows or Android'),
                isThreeLine: true,
              ),
            ]),

            // ── Student ───────────────────────────────────────────────────────
            _Section('Student Profile', [
              studentAsync.when(
                loading: () => ListTile(title: Text('Loading…')),
                error: (_, __) => ListTile(title: Text('Error')),
                data: (student) => ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      student != null && student.name.isNotEmpty
                          ? student.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(student?.name ?? 'No profile'),
                  subtitle: Text(
                    student != null
                        ? [
                            if (student.grade != null) student.grade!,
                            'Style: ${student.learningStyle}',
                            '${student.totalPoints} points',
                          ].join(' · ')
                        : 'Complete onboarding to start',
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text('Edit profile'),
                subtitle: Text(
                  'Update your interests and learning style',
                ),
                onTap: () => context.go('/onboarding'),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ]),

            // ── Streak & Points ───────────────────────────────────────────────
            studentAsync.when(
              data: (student) => student != null
                  ? _Section('Progress', [
                      ListTile(
                        leading: Icon(
                          Icons.local_fire_department,
                          color: Colors.orange,
                        ),
                        title: Text('${student.streakDays} day streak'),
                        subtitle: Text(
                          'Keep learning daily to grow your streak',
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.stars, color: Colors.amber),
                        title: Text('${student.totalPoints} points earned'),
                        subtitle: Text(
                          'Points grow as you complete lessons and earn badges',
                        ),
                      ),
                    ])
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Theme ────────────────────────────────────────────────────────
            _Section('Appearance', [
              ListTile(
                leading: Icon(
                  Icons.brightness_6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text('Theme'),
                subtitle: Text(
                  ref.watch(themeModeProvider) == ThemeMode.dark
                      ? 'Dark'
                      : ref.watch(themeModeProvider) == ThemeMode.light
                          ? 'Light'
                          : 'System',
                ),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.settings_suggest, size: 18),
                    ),
                  ],
                  selected: {ref.watch(themeModeProvider)},
                  onSelectionChanged: (s) =>
                      ref.read(themeModeProvider.notifier).set(s.first),
                  showSelectedIcon: false,
                ),
              ),
            ]),

            // ── App ──────────────────────────────────────────────────────────
            _Section('App', [
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text('Version'),
                subtitle: Text('Version 1.0.0'),
              ),
              ListTile(
                leading: Icon(Icons.wifi_off, color: AppColors.primary),
                title: Text('Offline mode'),
                subtitle: Text('100% offline — no internet required'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teachColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teachColor,
                    ),
                  ),
                ),
              ),
            ]),

            // ── Admin ────────────────────────────────────────────────────────
            _Section('Administration', [
              ListTile(
                leading: Icon(
                  Icons.admin_panel_settings,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text('Admin dashboard'),
                subtitle: Text(
                  'Device info, model status, profiles, update management',
                ),
                onTap: () => context.go('/admin'),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ]),

            // ── Danger zone ───────────────────────────────────────────────────
            _Section('Data', [
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  'Reset all data',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: Text(
                  'Deletes student profile, progress, and sessions',
                ),
                onTap: () => _confirmReset(context, ref),
              ),
            ]),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset all data?'),
        content: Text(
          'This permanently deletes your student profile, all progress, paths, badges, and session history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete everything'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      // Go to onboarding which will recreate the profile
      if (context.mounted) context.go('/onboarding');
    });
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...children,
        Divider(height: 1),
      ],
    );
  }
}
