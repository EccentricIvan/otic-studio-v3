import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_core/model/model_manager.dart';
import 'ai_core/providers/ai_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/model_setup/model_not_installed_screen.dart';

class OticApp extends ConsumerStatefulWidget {
  const OticApp({super.key});

  @override
  ConsumerState<OticApp> createState() => _OticAppState();
}

class _OticAppState extends ConsumerState<OticApp> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Small delay to let Flutter render the splash first
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _SplashScreen(),
      );
    }

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Otic Studio',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/branding/otic-logo.jpeg',
              width: 80,
              height: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Otic Studio',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF1F5F9),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF4F46E5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gates the Learn screen: shows "model not installed" if no model found.
class ModelGate extends ConsumerWidget {
  const ModelGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelInfo = ref.watch(modelInfoProvider);
    return modelInfo.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => child,
      data: (info) {
        if (info.status == ModelStatus.notInstalled) {
          return ModelNotInstalledScreen(info: info);
        }
        return child;
      },
    );
  }
}
