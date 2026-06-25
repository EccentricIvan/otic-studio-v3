import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../db/providers/db_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(activeStudentProvider);
    final name = studentAsync.valueOrNull?.name ?? 'Learner';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Image.asset('assets/branding/otic-studio-logo.png', width: 40, height: 40, fit: BoxFit.contain),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Otic Studio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                        Text('Learn, Create & Build', style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Welcome
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4F46E5).withValues(alpha: 0.12), Color(0xFF0EA5E9).withValues(alpha: 0.06)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Color(0xFF4F46E5).withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome, $name!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                    SizedBox(height: 4),
                    Text('What would you like to do today?', style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
                  ],
                ),
              ),
              SizedBox(height: 28),

              // LEARN section
              _SectionLabel('LEARN'),
              SizedBox(height: 12),
              Row(
                children: [
                  _IconCard(icon: Icons.menu_book, label: 'Subjects', color: Color(0xFF6366F1), route: '/learn'),
                  _IconCard(icon: Icons.quiz, label: 'Practice', color: Color(0xFF0EA5E9), route: '/practice'),
                  _IconCard(icon: Icons.chat, label: 'AI Chat', color: Color(0xFF8B5CF6), route: '/chat'),
                  _IconCard(icon: Icons.school, label: 'Teach', color: Color(0xFF10B981), route: '/teach'),
                ],
              ),
              SizedBox(height: 28),

              // CREATE section
              _SectionLabel('CREATE'),
              SizedBox(height: 12),
              Row(
                children: [
                  _IconCard(icon: Icons.web, label: 'Site Builder', color: Color(0xFF14B8A6), route: '/sitechat'),
                  _IconCard(icon: Icons.code, label: 'Web Dev', color: Color(0xFF0EA5E9), route: '/weblab'),
                  _IconCard(icon: Icons.terminal, label: 'Python', color: Color(0xFF3572A5), route: '/pythonlab'),
                  _IconCard(icon: Icons.phone_android, label: 'App Dev', color: Color(0xFF6366F1), route: '/applab'),
                ],
              ),
              SizedBox(height: 28),

              // MORE section
              _SectionLabel('MORE'),
              SizedBox(height: 12),
              Row(
                children: [
                  _IconCard(icon: Icons.folder, label: 'Projects', color: Color(0xFFF59E0B), route: '/projects'),
                  _IconCard(icon: Icons.emoji_events, label: 'Badges', color: Color(0xFFEF4444), route: '/achievements'),
                  _IconCard(icon: Icons.workspace_premium, label: 'Certs', color: Color(0xFFEC4899), route: '/certificates'),
                  _IconCard(icon: Icons.settings, label: 'Settings', color: Color(0xFF64748B), route: '/settings'),
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
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: Theme.of(context).hintColor,
      ),
    );
  }
}

class _IconCard extends StatelessWidget {
  const _IconCard({required this.icon, required this.label, required this.color, required this.route});
  final IconData icon;
  final String label;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.push(route),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0.5)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
