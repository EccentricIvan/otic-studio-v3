import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ai_core/cloud/cloud_api_settings.dart';
import '../../ai_core/providers/ai_provider.dart';
import '../../core/app_info_provider.dart';
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
    final packageInfoAsync = ref.watch(packageInfoProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: MaxWidth(
        maxWidth: 760,
        child: ListView(
          children: [
            // ── AI Model ─────────────────────────────────────────────────────
            _Section('AI Model', [
              ref.watch(aiStatusProvider).when(
                loading: () => const ListTile(
                  leading: Icon(Icons.memory, color: AppColors.primary),
                  title: Text('Checking AI…'),
                ),
                error: (_, __) => const ListTile(
                  leading: Icon(Icons.memory, color: Colors.red),
                  title: Text('AI check failed'),
                  subtitle: Text('Try restarting the app'),
                ),
                data: (status) => ListTile(
                  leading: Icon(
                    status.isDemo ? Icons.info_outline : Icons.memory,
                    color: status.isDemo
                        ? Colors.orange
                        : AppColors.teachColor,
                  ),
                  title: Text(
                    status.isDemo
                        ? 'Demo mode'
                        : (status.backendLabel?.startsWith('Cloud') == true
                            ? 'Cloud AI ready'
                            : 'Local AI ready'),
                  ),
                  subtitle: Text(
                    status.isDemo
                        ? status.detail
                        : (status.backendLabel ?? status.detail),
                  ),
                  isThreeLine: status.isDemo,
                  trailing: Icon(
                    status.isDemo ? Icons.warning_amber : Icons.check_circle,
                    color: status.isDemo ? Colors.orange : AppColors.teachColor,
                  ),
                ),
              ),
              modelAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (info) => ListTile(
                  leading: Icon(
                    Icons.sd_storage_outlined,
                    color: info.isReady ? AppColors.teachColor : Colors.orange,
                  ),
                  title: const Text('On-device Gemma file'),
                  subtitle: Text(
                    info.isReady
                        ? 'Installed · ${info.platform ?? 'Android'}'
                        : 'Not installed — transfer via USB (Android)',
                  ),
                  trailing: info.isReady
                      ? const Icon(
                          Icons.check_circle,
                          color: AppColors.teachColor,
                        )
                      : const Icon(Icons.warning_amber, color: Colors.orange),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: const Text('How AI works here'),
                subtitle: const Text(
                  'Optional Cloud API key gives live answers online. '
                  'Otherwise Android uses on-device Gemma and desktop uses Ollama. '
                  'If none are ready, demo answers are labeled clearly.',
                ),
                isThreeLine: true,
              ),
            ]),

            // ── Cloud AI (optional) ──────────────────────────────────────────
            _Section('Cloud AI (optional)', [
              ref.watch(cloudApiSettingsProvider).when(
                loading: () => const ListTile(title: Text('Loading…')),
                error: (_, __) => const ListTile(title: Text('Could not load cloud settings')),
                data: (cfg) => SwitchListTile(
                  secondary: Icon(
                    Icons.cloud_outlined,
                    color: cfg.isConfigured
                        ? AppColors.teachColor
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('Use cloud API for chat'),
                  subtitle: Text(
                    cfg.isConfigured
                        ? 'On · ${cfg.model} · key saved on this device'
                        : 'Off — add an API key for live OpenAI-compatible answers',
                  ),
                  value: cfg.enabled && cfg.apiKey.isNotEmpty,
                  onChanged: (on) async {
                    if (on && cfg.apiKey.isEmpty) {
                      await _editCloudApi(context, ref, cfg);
                      return;
                    }
                    await ref
                        .read(cloudApiSettingsProvider.notifier)
                        .save(cfg.copyWith(enabled: on));
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.vpn_key_outlined, color: AppColors.primary),
                title: const Text('API key & model'),
                subtitle: const Text(
                  'Free: Groq (recommended). Also OpenRouter, Together, or OpenAI',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final cfg = await ref.read(cloudApiSettingsProvider.future);
                  if (!context.mounted) return;
                  await _editCloudApi(context, ref, cfg);
                },
              ),
            ]),

            // ── Student ───────────────────────────────────────────────────────
            _Section('Student Profile', [
              studentAsync.when(
                loading: () => const ListTile(title: Text('Loading…')),
                error: (_, __) => const ListTile(title: Text('Error')),
                data: (student) => ListTile(
                  leading: Icon(
                    Icons.person_outline,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                title: const Text('Edit profile'),
                subtitle: const Text(
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
                        leading: const Icon(
                          Icons.local_fire_department,
                          color: Colors.orange,
                        ),
                        title: Text('${student.streakDays} day streak'),
                        subtitle: const Text(
                          'Keep learning daily to grow your streak',
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.stars, color: Colors.amber),
                        title: Text('${student.totalPoints} points earned'),
                        subtitle: const Text(
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
                title: const Text('Theme'),
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
                title: const Text('Version'),
                subtitle: Text(
                  packageInfoAsync.when(
                    data: (info) => 'Version ${info.version} (build ${info.buildNumber})',
                    loading: () => 'Loading…',
                    error: (_, __) => 'Unknown',
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.wifi_off, color: AppColors.primary),
                title: const Text('Offline mode'),
                subtitle: const Text('100% offline — no internet required'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teachColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
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
                  Icons.groups_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: const Text('Teacher dashboard'),
                subtitle: const Text(
                  'See learners on this device, topic progress, and sessions',
                ),
                onTap: () => context.go('/teacher'),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).hintColor,
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.admin_panel_settings,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: const Text('Admin dashboard'),
                subtitle: const Text(
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
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Reset all data',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text(
                  'Deletes student profile, progress, and sessions',
                ),
                onTap: () => _confirmReset(context, ref),
              ),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'This permanently deletes your student profile, all progress, paths, badges, and session history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything'),
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

Future<void> _editCloudApi(
  BuildContext context,
  WidgetRef ref,
  CloudApiConfig initial,
) async {
  final keyCtrl = TextEditingController(text: initial.apiKey);
  final urlCtrl = TextEditingController(text: initial.baseUrl);
  final modelCtrl = TextEditingController(text: initial.model);
  var enabled = initial.enabled || initial.apiKey.isEmpty;

  final saved = await showDialog<CloudApiConfig>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Cloud AI API'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Uses an OpenAI-compatible chat API for live answers. '
                    'Needs internet. The key is stored only on this device.\n\n'
                    'Free option: sign up at console.groq.com, create an API key, '
                    'and use base URL https://api.groq.com/openai/v1 with model '
                    'llama-3.3-70b-versatile.',
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable cloud AI'),
                    value: enabled,
                    onChanged: (v) => setLocal(() => enabled = v),
                  ),
                  TextField(
                    controller: keyCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API key',
                      hintText: 'gsk_… from console.groq.com',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://api.groq.com/openai/v1',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: modelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      hintText: 'llama-3.3-70b-versatile',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  initial.copyWith(apiKey: '', enabled: false),
                ),
                child: const Text('Clear'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  CloudApiConfig(
                    apiKey: keyCtrl.text.trim(),
                    baseUrl: urlCtrl.text.trim().isEmpty
                        ? 'https://api.groq.com/openai/v1'
                        : urlCtrl.text.trim(),
                    model: modelCtrl.text.trim().isEmpty
                        ? 'llama-3.3-70b-versatile'
                        : modelCtrl.text.trim(),
                    enabled: enabled && keyCtrl.text.trim().isNotEmpty,
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  keyCtrl.dispose();
  urlCtrl.dispose();
  modelCtrl.dispose();

  if (saved != null) {
    await ref.read(cloudApiSettingsProvider.notifier).save(saved);
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
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }
}
