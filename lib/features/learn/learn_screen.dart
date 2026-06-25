import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../ai_core/providers/ai_provider.dart';
import '../../ai_core/tutor/tutor_response.dart';
import '../../core/theme/app_colors.dart';
import '../../curriculum/curriculum_models.dart';
import '../../curriculum/curriculum_provider.dart';
import '../../shared/widgets/responsive.dart';
import 'path/path_models.dart';
import 'path/path_provider.dart';

class _ChatEntry {
  const _ChatEntry({required this.text, required this.isUser, this.lesson});
  final String text;
  final bool isUser;
  final Lesson? lesson;
}

class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key, this.initialTopic});
  final String? initialTopic;

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialTopic != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatProvider.notifier).send(widget.initialTopic!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Lesson? _lastLesson;
  final List<_ChatEntry> _entries = [];

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    // Add user message
    setState(() => _entries.add(_ChatEntry(text: text, isUser: true)));

    // Search curriculum for matching lesson
    final curriculum = ref.read(curriculumServiceProvider);
    final lesson = curriculum.findBestMatch(text);

    if (lesson != null) {
      // Show lesson card first
      setState(() {
        _lastLesson = lesson;
        _entries.add(_ChatEntry(text: '', isUser: false, lesson: lesson));
      });
    }

    // Always send to Gemma — it adds a short follow-up
    ref.read(chatProvider.notifier).send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final engineAsync = ref.watch(engineLoadedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Learn'),
        actions: [
          if (kDebugMode)
            engineAsync.when(
              data: (engine) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  avatar: Icon(
                    Icons.memory,
                    size: 14,
                    color: AppColors.teachColor,
                  ),
                  label: Text(
                    engine.backendLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.teachColor,
                    ),
                  ),
                  backgroundColor: AppColors.teachColor.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: AppColors.teachColor.withValues(alpha: 0.3),
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
              loading: () => Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'New session',
            onPressed: () => ref.read(chatProvider.notifier).reset(),
          ),
        ],
      ),
      body: MaxWidth(
        child: Column(
          children: [
            Expanded(
              child: chat.when(
                loading: () => Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (state) {
                  if (_entries.isEmpty && state.messages.isEmpty) {
                    return _EmptyState(
                      onTopic: (t) {
                        _controller.text = t;
                        _send();
                      },
                    );
                  }

                  // Merge our entries with any Gemma responses
                  final allItems = <_ChatEntry>[..._entries];

                  // Add Gemma messages that aren't already in our list
                  for (final msg in state.messages) {
                    final alreadyExists = allItems.any((e) => e.text == msg.text && e.isUser == msg.isUser);
                    if (!alreadyExists) {
                      allItems.add(_ChatEntry(text: msg.text, isUser: msg.isUser));
                    }
                  }

                  final showStreaming = state.isGenerating && state.streamingText.isNotEmpty;

                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: allItems.length + (showStreaming ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= allItems.length) {
                        return _TutorBubble(
                          text: state.streamingText,
                          stage: null,
                          followUp: null,
                          isStreaming: true,
                        );
                      }

                      final entry = allItems[i];

                      // Lesson card from curriculum
                      if (entry.lesson != null) {
                        return _LessonCard(lesson: entry.lesson!);
                      }

                      // User bubble
                      if (entry.isUser) return _UserBubble(text: entry.text);

                      // Gemma response
                      return _TutorBubble(
                        text: entry.text,
                        stage: null,
                        followUp: null,
                        isStreaming: false,
                      );
                    },
                  );
                },
              ),
            ),
            _InputBar(
              controller: _controller,
              onSend: _send,
              isLoading: chat.valueOrNull?.isGenerating ?? false,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active paths horizontal strip ────────────────────────────────────────────

class _ActivePathsStrip extends ConsumerWidget {
  const _ActivePathsStrip({required this.onPathTap});
  final void Function(String topic) onPathTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(studentPathsProvider);
    return pathsAsync.when(
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        final paths = rows.map(parsedFromRow).toList();
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.route, size: 14, color: Theme.of(context).hintColor),
                  SizedBox(width: 6),
                  Text(
                    'MY PATHS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              SizedBox(
                height: 82,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: paths.length,
                  separatorBuilder: (_, __) => SizedBox(width: 10),
                  itemBuilder: (_, i) => _PathChip(
                    path: paths[i],
                    onTap: () => onPathTap(paths[i].topic),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PathChip extends StatelessWidget {
  const _PathChip({required this.path, required this.onTap});
  final ParsedPath path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              path.topic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: cs.onSurface,
              ),
            ),
            SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: path.progressFraction,
                minHeight: 5,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.learnColor,
                ),
              ),
            ),
            SizedBox(height: 4),
            Text(
              '${path.completedLessons}/${path.totalLessons} lessons',
              style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chat bubbles ──────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(color: Colors.white, height: 1.5),
        ),
      ),
    );
  }
}

class _TutorBubble extends StatelessWidget {
  const _TutorBubble({
    required this.text,
    required this.stage,
    required this.followUp,
    required this.isStreaming,
  });

  final String text;
  final TutorStage? stage;
  final String? followUp;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/branding/otic-logo.jpeg',
                    width: 13,
                    height: 13,
                    fit: BoxFit.contain,
                    semanticLabel: 'Logo',
                  ),
                  SizedBox(width: 4),
                  Text(
                    _label(stage!),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
            ),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    text.isEmpty ? '…' : text,
                    style: TextStyle(
                      color: cs.onSurface,
                      height: 1.6,
                    ),
                  ),
                ),
                if (isStreaming) ...[
                  SizedBox(width: 8),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (followUp != null && !isStreaming)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                followUp!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            SizedBox(height: 12),
        ],
      ),
    );
  }

  String _label(TutorStage s) {
    switch (s) {
      case TutorStage.answer:
        return 'AI Tutor - Answer';
      case TutorStage.clarify:
        return 'AI Tutor - Check understanding';
      case TutorStage.practice:
        return 'AI Tutor - Practice';
      case TutorStage.apply:
        return 'AI Tutor - Apply it';
      case TutorStage.create:
        return 'AI Tutor - Create';
      case TutorStage.reflect:
        return 'AI Tutor - Reflect';
    }
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.isLoading,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        color: Theme.of(context).colorScheme.surface,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Ask Otic anything...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
            ),
          ),
          SizedBox(width: 8),
          isLoading
              ? Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : IconButton.filled(
                  onPressed: onSend,
                  icon: Icon(Icons.arrow_upward),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Empty / starter state ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onTopic});
  final void Function(String) onTopic;

  static const _starter = 'Ask me anything';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4F46E5).withValues(alpha: 0.2),
                  Color(0xFF0EA5E9).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Color(0xFF4F46E5).withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Image.asset(
                'assets/branding/otic-logo.jpeg',
                fit: BoxFit.contain,
                semanticLabel: 'Logo',
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'AI Chat',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Ask questions, get explanations, and explore any topic with your AI tutor.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
          ),
          SizedBox(height: 28),
          InkWell(
            onTap: () => onTopic(_starter),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF4F46E5).withValues(alpha: 0.15),
                    Color(0xFF0EA5E9).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Color(0xFF4F46E5).withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Color(0xFF4F46E5)),
                  SizedBox(width: 8),
                  Text('Start a conversation', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lesson card shown in chat ────────────────────────────────────────────────

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.practiceColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(lesson.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text('Curriculum', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Text(
              lesson.content.length > 300 ? '${lesson.content.substring(0, 300)}...' : lesson.content,
              style: TextStyle(fontSize: 13, height: 1.6, color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          if (lesson.examples.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 6),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.createColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.createColor.withValues(alpha: 0.12)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Example', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.createColor)),
                  SizedBox(height: 4),
                  Text(lesson.examples.first, style: TextStyle(fontSize: 12, height: 1.4, color: Theme.of(context).colorScheme.onSurface)),
                ]),
              ),
            ),
          if (lesson.keyTerms.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(14, 2, 14, 12),
              child: Wrap(
                spacing: 6, runSpacing: 6,
                children: lesson.keyTerms.keys.take(4).map((term) => Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(term, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
