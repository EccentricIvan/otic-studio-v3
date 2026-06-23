import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../db/providers/db_provider.dart';
import '../../features/achievements/achievements_screen.dart';
import '../../features/admin/admin_screen.dart';
import '../../features/certificates/certificates_screen.dart';
import '../../features/collaborate/collaborate_screen.dart';
import '../../features/create/create_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/app_dev_lab/app_dev_lab_screen.dart';
import '../../features/curriculum_browser/lesson_screen.dart';
import '../../features/python_lab/python_lab_screen.dart';
import '../../features/curriculum_browser/subjects_screen.dart';
import '../../features/curriculum_browser/units_screen.dart';
import '../../features/learn/learn_screen.dart';
import '../../features/learn/path/path_detail_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/practice/practice_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/teach/teach_screen.dart';
import '../../features/teacher/teacher_screen.dart';
import '../../features/site_builder/site_builder_screen.dart';
import '../../features/web_dev_lab/web_dev_lab_screen.dart';
import '../../features/website/website_builder_screen.dart';
import '../../shared/widgets/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// Provider-aware router so the redirect can read [hasProfileProvider].
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    redirect: (context, state) async {
      if (state.matchedLocation == '/onboarding') return null;
      try {
        final hasProfile = await ref.read(hasProfileProvider.future);
        if (!hasProfile) return '/onboarding';
      } catch (_) {
        return '/onboarding';
      }
      return null;
    },
    routes: [
      // Onboarding is outside the shell (no nav bar/sidebar)
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/learn', builder: (_, __) => const SubjectsScreen()),
          GoRoute(
            path: '/learn/subject/:id',
            builder: (_, state) => UnitsScreen(
              subjectId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: '/learn/subject/:id/lesson/:unit/:lesson',
            builder: (_, state) => LessonScreen(
              subjectId: state.pathParameters['id'] ?? '',
              unitIndex: int.tryParse(state.pathParameters['unit'] ?? '0') ?? 0,
              lessonIndex: int.tryParse(state.pathParameters['lesson'] ?? '0') ?? 0,
            ),
          ),
          GoRoute(path: '/chat', builder: (_, state) {
            final topic = state.uri.queryParameters['topic'];
            return ModelGate(child: LearnScreen(initialTopic: topic));
          }),
          GoRoute(
            path: '/path/:topic',
            builder: (_, state) => PathDetailScreen(
              topic: Uri.decodeComponent(state.pathParameters['topic'] ?? ''),
            ),
          ),
          GoRoute(path: '/practice', builder: (_, __) => const PracticeScreen()),
          GoRoute(path: '/create', builder: (_, __) => const CreateScreen()),
          GoRoute(path: '/weblab', builder: (_, __) => const WebDevLabScreen()),
          GoRoute(path: '/applab', builder: (_, __) => const AppDevLabScreen()),
          GoRoute(path: '/sitebuilder', builder: (_, __) => const SiteBuilderScreen()),
          GoRoute(path: '/pythonlab', builder: (_, __) => const PythonLabScreen()),
          GoRoute(path: '/website', builder: (_, __) => const WebsiteBuilderScreen()),
          GoRoute(path: '/projects', builder: (_, __) => const ProjectsScreen()),
          GoRoute(path: '/achievements', builder: (_, __) => const AchievementsScreen()),
          GoRoute(path: '/certificates', builder: (_, __) => const CertificatesScreen()),
          GoRoute(path: '/collaborate', builder: (_, __) => const CollaborateScreen()),
          GoRoute(path: '/teach', builder: (_, __) => const TeachScreen()),
          GoRoute(path: '/teacher', builder: (_, __) => const TeacherScreen()),
          GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
});

// Keep a simple non-provider router for backwards compat during build
final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/learn', builder: (_, __) => const SubjectsScreen()),
        GoRoute(
          path: '/learn/subject/:id',
          builder: (_, state) => UnitsScreen(subjectId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: '/learn/subject/:id/lesson/:unit/:lesson',
          builder: (_, state) => LessonScreen(
            subjectId: state.pathParameters['id'] ?? '',
            unitIndex: int.tryParse(state.pathParameters['unit'] ?? '0') ?? 0,
            lessonIndex: int.tryParse(state.pathParameters['lesson'] ?? '0') ?? 0,
          ),
        ),
        GoRoute(path: '/chat', builder: (_, state) {
          final topic = state.uri.queryParameters['topic'];
          return LearnScreen(initialTopic: topic);
        }),
        GoRoute(path: '/applab', builder: (_, __) => const AppDevLabScreen()),
          GoRoute(path: '/sitebuilder', builder: (_, __) => const SiteBuilderScreen()),
          GoRoute(path: '/pythonlab', builder: (_, __) => const PythonLabScreen()),
        GoRoute(
          path: '/path/:topic',
          builder: (_, state) => PathDetailScreen(
            topic: Uri.decodeComponent(state.pathParameters['topic'] ?? ''),
          ),
        ),
        GoRoute(path: '/practice', builder: (_, __) => const PracticeScreen()),
        GoRoute(path: '/create', builder: (_, __) => const CreateScreen()),
        GoRoute(path: '/weblab', builder: (_, __) => const WebDevLabScreen()),
        GoRoute(path: '/website', builder: (_, __) => const WebsiteBuilderScreen()),
        GoRoute(path: '/projects', builder: (_, __) => const ProjectsScreen()),
        GoRoute(path: '/achievements', builder: (_, __) => const AchievementsScreen()),
        GoRoute(path: '/certificates', builder: (_, __) => const CertificatesScreen()),
        GoRoute(path: '/collaborate', builder: (_, __) => const CollaborateScreen()),
        GoRoute(path: '/teacher', builder: (_, __) => const TeacherScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
  ],
);
