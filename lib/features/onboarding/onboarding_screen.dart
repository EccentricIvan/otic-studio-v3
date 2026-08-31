import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../db/providers/db_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  // Form state
  final _nameController = TextEditingController();
  int? _age;
  String? _grade;
  final String _language = 'en';
  final Set<String> _interests = {};
  String _learningStyle = 'unknown';
  bool _saving = false;
  int? _existingStudentId;

  @override
  void initState() {
    super.initState();
    // If a profile already exists (opened via Settings → Edit profile),
    // prefill the current name and edit that row in place instead of
    // creating a second profile.
    if (!kIsWeb) {
      final existing = ref.read(activeStudentProvider).valueOrNull;
      if (existing != null) {
        _existingStudentId = existing.id;
        _nameController.text = existing.name;
        _age = existing.age;
        _grade = existing.grade;
        _learningStyle = existing.learningStyle;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  static const _pageCount = 1;

  void _next() {
    if (_page == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }
    if (_page < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    _finish();
  }

  void _back() {
    if (_page == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);

    final name = _nameController.text.trim();

    // Always save to SharedPreferences (works on all platforms)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_name', name);

    // Navigate IMMEDIATELY — don't wait for database
    if (mounted) context.go('/');

    // On every native platform (not web), also save to database in background
    if (!kIsWeb) {
      try {
        final existingId = _existingStudentId;
        if (existingId != null) {
          ref.read(studentNotifierProvider.notifier).updateProfile(
            id: existingId,
            name: name,
            age: _age,
            grade: _grade,
            interests: _interests.toList(),
            learningStyle: _learningStyle,
          );
        } else {
          ref.read(studentNotifierProvider.notifier).createProfile(
            name: name,
            age: _age,
            grade: _grade,
            language: _language,
            interests: _interests.toList(),
            learningStyle: _learningStyle,
          );
        }
      } catch (e) {
        debugPrint('Profile save error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)]
                : const [Color(0xFFFFFBEB), Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_pageCount > 1)
                SizedBox(
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _pageCount; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: i == _page ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i <= _page
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_page > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _back,
                          ),
                        ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 16),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _NamePage(controller: _nameController),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _next,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_page < _pageCount - 1 ? 'Next' : 'Start learning'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page 1: Name ──────────────────────────────────────────────────────────────

class _NamePage extends StatelessWidget {
  const _NamePage({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Image.asset(
            'assets/branding/otic-studio-logo.png',
            width: 64,
            height: 64,
            fit: BoxFit.contain,
            semanticLabel: 'Logo',
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to AI Connect Africa',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Your personal offline AI tutor. Everything stays on this device — no internet ever.',
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.5),
          ),
          const SizedBox(height: 24),
          Text(
            "What's your name?",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Enter your name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
        ],
      ),
    );
  }
}

