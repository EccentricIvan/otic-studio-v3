import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }
    if (_page < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref
        .read(studentNotifierProvider.notifier)
        .createProfile(
          name: _nameController.text.trim(),
          age: _age,
          grade: _grade,
          language: _language,
          interests: _interests.toList(),
          learningStyle: _learningStyle,
        );
    if (mounted) context.go('/learn');
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
              // Progress dots
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _page == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _page == i
                            ? AppColors.primary
                            : Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _NamePage(controller: _nameController),
                    _InterestsPage(
                      selected: _interests,
                      onToggle: (s) => setState(
                        () => _interests.contains(s)
                            ? _interests.remove(s)
                            : _interests.add(s),
                      ),
                    ),
                    _StylePage(
                      selected: _learningStyle,
                      onSelect: (s) => setState(() => _learningStyle = s),
                    ),
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
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_page < 2 ? 'Continue' : 'Start learning'),
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
          SizedBox(height: 12),
          Image.asset(
            'assets/branding/otic_logo.png',
            width: 64,
            height: 64,
            fit: BoxFit.contain,
            semanticLabel: 'Logo',
          ),
          SizedBox(height: 16),
          Text(
            'Welcome to Otic Studio',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          SizedBox(height: 6),
          Text(
            'Your personal offline AI tutor. Everything stays on this device — no internet ever.',
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.5),
          ),
          SizedBox(height: 24),
          Text(
            "What's your name?",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 10),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Enter your name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 2: Age + Grade ───────────────────────────────────────────────────────

class _AgePage extends StatelessWidget {
  const _AgePage({
    required this.age,
    required this.grade,
    required this.onAge,
    required this.onGrade,
  });
  final int? age;
  final String? grade;
  final void Function(int?) onAge;
  final void Function(String?) onGrade;

  static const _grades = [
    'Primary 1–4',
    'Primary 5–7',
    'Secondary 1–3',
    'Secondary 4–6',
    'University',
    'Self-learner',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 12),
          Text('About you', style: Theme.of(context).textTheme.headlineLarge),
          SizedBox(height: 6),
          Text(
            'This helps the AI tutor explain things at the right level. You can skip.',
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.5),
          ),
          SizedBox(height: 20),
          Text(
            'How old are you?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: age,
            decoration: InputDecoration(
              hintText: 'Select age (optional)',
            ),
            items: List.generate(
              60,
              (i) => DropdownMenuItem(
                value: i + 5,
                child: Text('${i + 5} years old'),
              ),
            ),
            onChanged: onAge,
          ),
          SizedBox(height: 24),
          Text(
            'What grade/level are you in?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _grades
                .map(
                  (g) => ChoiceChip(
                    label: Text(g),
                    selected: grade == g,
                    onSelected: (_) => onGrade(grade == g ? null : g),
                    selectedColor: AppColors.primary.withValues(alpha: 0.12),
                    side: BorderSide(
                      color: grade == g ? AppColors.primary : Theme.of(context).dividerColor,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Page 3: Interests ─────────────────────────────────────────────────────────

class _InterestsPage extends StatelessWidget {
  const _InterestsPage({required this.selected, required this.onToggle});
  final Set<String> selected;
  final void Function(String) onToggle;

  static const _topics = [
    ('Mathematics', Icons.calculate, Color(0xFF4F46E5)),
    ('Physics', Icons.science, Color(0xFF0EA5E9)),
    ('Biology', Icons.biotech, Color(0xFF10B981)),
    ('Chemistry', Icons.science_outlined, Color(0xFFF59E0B)),
    ('Programming', Icons.code, Color(0xFF6366F1)),
    ('Web Development', Icons.web, Color(0xFF0EA5E9)),
    ('App Development', Icons.phone_android, Color(0xFF6366F1)),
    ('AI & Data', Icons.psychology, Color(0xFF7C3AED)),
    ('Business', Icons.trending_up, Color(0xFFEA580C)),
    ('Agriculture', Icons.grass, Color(0xFF22C55E)),
    ('History', Icons.history_edu, Color(0xFF64748B)),
    ('Geography', Icons.public, Color(0xFF14B8A6)),
    ('English', Icons.menu_book, Color(0xFFEC4899)),
    ('Economics', Icons.account_balance, Color(0xFFF59E0B)),
    ('Arts', Icons.palette, Color(0xFFEAB308)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What topics interest you?',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                SizedBox(height: 6),
                Text(
                  'Pick as many as you like. Otic will personalise your paths.',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.6),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.1,
              children: _topics.map((t) {
                final isSelected = selected.contains(t.$1);
                final color = t.$3;
                return GestureDetector(
                  onTap: () => onToggle(t.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.14)
                          : color.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : color.withValues(alpha: 0.18),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          t.$2,
                          color: isSelected
                              ? color
                              : color.withValues(alpha: 0.72),
                          size: 26,
                        ),
                        SizedBox(height: 6),
                        Text(
                          t.$1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 4: Learning style ────────────────────────────────────────────────────

class _StylePage extends StatelessWidget {
  const _StylePage({required this.selected, required this.onSelect});
  final String selected;
  final void Function(String) onSelect;

  static const _styles = [
    (
      'visual',
      Icons.visibility_outlined,
      'Visual',
      'I learn best from diagrams, examples, and seeing things',
    ),
    (
      'reading',
      Icons.menu_book_outlined,
      'Reading',
      'I learn best by reading explanations and taking notes',
    ),
    (
      'practice',
      Icons.fitness_center_outlined,
      'Practice',
      'I learn best by doing exercises and solving problems',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 12),
          Text(
            'How do you learn best?',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          SizedBox(height: 6),
          Text(
            'The AI tutor adapts its teaching style to suit you.',
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.5),
          ),
          SizedBox(height: 20),
          ..._styles.map((s) {
            final isSelected = selected == s.$1;
            return GestureDetector(
              onTap: () => onSelect(s.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Theme.of(context).dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      s.$2,
                      color: isSelected
                          ? AppColors.primary
                          : Theme.of(context).textTheme.bodyMedium?.color,
                      size: 28,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.$3,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary
                                  : Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            s.$4,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
