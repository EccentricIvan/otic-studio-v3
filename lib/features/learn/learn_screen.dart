import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ai_core/providers/ai_provider.dart';
import '../../ai_core/tutor/tutor_response.dart';
import '../../core/theme/app_colors.dart';
import '../../curriculum/curriculum_models.dart';
import '../../curriculum/curriculum_provider.dart';
import '../../shared/widgets/responsive.dart';

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
        _sendText(widget.initialTopic!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Lesson cards keyed by the exact user message text that matched them, so
  // they can be inserted right after that question in the render below —
  // rather than kept in a separate list that has to be merged with the chat
  // provider's messages (which broke ordering once 2+ turns were in flight:
  // both questions landed together, followed by both answers).
  final Map<String, Lesson> _lessonForMessage = {};

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _sendText(text);
  }

  void _sendText(String text) {
    // Wait for the current answer before accepting the next question.
    if (ref.read(chatProvider).valueOrNull?.isGenerating ?? false) return;
    _controller.clear();

    final curriculum = ref.read(curriculumServiceProvider);
    final lesson = curriculum.findBestMatch(text);
    if (lesson != null) _lessonForMessage[text] = lesson;

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
        title: const Text('Learn'),
        actions: [
          if (kDebugMode)
            engineAsync.when(
              data: (engine) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  avatar: const Icon(
                    Icons.memory,
                    size: 14,
                    color: AppColors.teachColor,
                  ),
                  label: Text(
                    engine.backendLabel,
                    style: const TextStyle(
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
              loading: () => const Padding(
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
            icon: const Icon(Icons.refresh),
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (state) {
                  if (state.messages.isEmpty) {
                    return _EmptyState(
                      onTopic: (t) {
                        _controller.text = t;
                        _send();
                      },
                    );
                  }

                  // Build the timeline straight from the chat provider's
                  // messages — the actual chronological order of the
                  // conversation — and slot each lesson card in right after
                  // the question that matched it.
                  final allItems = <_ChatEntry>[];
                  for (final msg in state.messages) {
                    allItems.add(_ChatEntry(text: msg.text, isUser: msg.isUser));
                    if (msg.isUser) {
                      final lesson = _lessonForMessage[msg.text];
                      if (lesson != null) {
                        allItems.add(_ChatEntry(text: '', isUser: false, lesson: lesson));
                      }
                    }
                  }

                  final showStreaming = state.isGenerating && state.streamingText.isNotEmpty;

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        decoration: const BoxDecoration(
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
          style: const TextStyle(color: Colors.white, height: 1.5),
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
                    'assets/branding/otic-studio-logo.png',
                    width: 13,
                    height: 13,
                    fit: BoxFit.contain,
                    semanticLabel: 'Logo',
                  ),
                  const SizedBox(width: 4),
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
                  const SizedBox(width: 8),
                  const SizedBox(
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
            const SizedBox(height: 12),
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
              decoration: const InputDecoration(
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
          const SizedBox(width: 8),
          isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : IconButton.filled(
                  onPressed: onSend,
                  icon: const Icon(Icons.arrow_upward),
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
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF4F46E5).withValues(alpha: 0.2),
                  const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Image.asset(
                'assets/branding/otic-studio-logo.png',
                fit: BoxFit.contain,
                semanticLabel: 'Logo',
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'AI Chat',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ask questions, get explanations, and explore any topic with your AI tutor.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 28),
          InkWell(
            onTap: () => onTopic(_starter),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
              ),
              child: const Row(
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
      margin: const EdgeInsets.only(bottom: 12),
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(lesson.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Curriculum', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Text(
              lesson.content.length > 300 ? '${lesson.content.substring(0, 300)}...' : lesson.content,
              style: TextStyle(fontSize: 13, height: 1.6, color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          if (lesson.examples.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.createColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.createColor.withValues(alpha: 0.12)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Example', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.createColor)),
                  const SizedBox(height: 4),
                  Text(lesson.examples.first, style: TextStyle(fontSize: 12, height: 1.4, color: Theme.of(context).colorScheme.onSurface)),
                ]),
              ),
            ),
          if (lesson.keyTerms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
              child: Wrap(
                spacing: 6, runSpacing: 6,
                children: lesson.keyTerms.keys.take(4).map((term) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(term, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
