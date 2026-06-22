import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_core/providers/ai_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../db/otic_database.dart';
import '../../db/providers/db_provider.dart';
import '../../gamification/badge_service.dart';
import '../../shared/widgets/responsive.dart';
import 'package:drift/drift.dart' show Value;

// ── Project types ─────────────────────────────────────────────────────────────

const _projectTypes = [
  _PType('Essay', Icons.article, 'Write a structured essay'),
  _PType('Business Plan', Icons.trending_up, 'Plan a business idea'),
  _PType('Experiment', Icons.science, 'Design a science experiment'),
  _PType('Story', Icons.menu_book, 'Write a creative story'),
  _PType('Code Plan', Icons.code, 'Plan an app or program'),
  _PType('Other', Icons.lightbulb, 'Any creation project'),
];

class _PType {
  const _PType(this.label, this.icon, this.hint);
  final String label;
  final IconData icon;
  final String hint;
}

// ── State ─────────────────────────────────────────────────────────────────────

class _CreateState {
  const _CreateState({
    this.projectType = '',
    this.topic = '',
    this.messages = const [],
    this.isGenerating = false,
    this.streamingText = '',
    this.savedProjectId,
  });

  final String projectType;
  final String topic;
  final List<_Msg> messages;
  final bool isGenerating;
  final String streamingText;
  final int? savedProjectId;

  bool get started => messages.isNotEmpty;

  _CreateState copyWith({
    String? projectType,
    String? topic,
    List<_Msg>? messages,
    bool? isGenerating,
    String? streamingText,
    int? savedProjectId,
  }) => _CreateState(
    projectType: projectType ?? this.projectType,
    topic: topic ?? this.topic,
    messages: messages ?? this.messages,
    isGenerating: isGenerating ?? this.isGenerating,
    streamingText: streamingText ?? this.streamingText,
    savedProjectId: savedProjectId ?? this.savedProjectId,
  );
}

class _Msg {
  const _Msg({required this.text, required this.isUser});
  final String text;
  final bool isUser;
}

class _CreateNotifier extends AutoDisposeNotifier<_CreateState> {
  @override
  _CreateState build() => const _CreateState();

  void setType(String t) => state = state.copyWith(projectType: t);
  void setTopic(String t) => state = state.copyWith(topic: t);

  Future<void> start() async {
    if (state.projectType.isEmpty || state.topic.isEmpty) return;
    final intro =
        'I want to create a ${state.projectType} about ${state.topic}.';
    await _send(intro);
  }

  Future<void> send(String text) => _send(text);

  Future<void> _send(String userText) async {
    final msgs = [...state.messages, _Msg(text: userText, isUser: true)];
    state = state.copyWith(
      messages: msgs,
      isGenerating: true,
      streamingText: '',
    );

    try {
      final engine = await ref.read(engineLoadedProvider.future);
      final history = state.messages
          .map((m) => '${m.isUser ? 'Student' : 'Tutor'}: ${m.text}')
          .join('\n');

      final prompt =
          '''You are a creative project mentor.
Help the student build a ${state.projectType} about "${state.topic}".
Guide them one step at a time: plan → draft → review.
Ask one clear question or give one clear instruction. Be encouraging.
Keep responses concise (3-5 sentences max).

${history.isNotEmpty ? 'Conversation so far:\n$history\n' : ''}Student: $userText
Tutor:''';

      String streamed = '';
      final response = await engine.generate(
        prompt: prompt,
        maxTokens: 350,
        temperature: 0.8,
        onToken: (t) {
          streamed += t;
          state = state.copyWith(streamingText: streamed);
        },
      );

      state = state.copyWith(
        messages: [
          ...state.messages,
          _Msg(text: response, isUser: false),
        ],
        isGenerating: false,
        streamingText: '',
      );
    } catch (_) {
      state = state.copyWith(isGenerating: false, streamingText: '');
    }
  }

  Future<void> saveProject(BuildContext context) async {
    final student = await ref.read(activeStudentProvider.future);
    if (student == null) return;

    final db = ref.read(dbProvider);
    final stepsJson = jsonEncode(
      state.messages
          .map((m) => {'role': m.isUser ? 'user' : 'otic', 'text': m.text})
          .toList(),
    );

    final title = '${state.projectType}: ${state.topic}';
    final id = await db.projectDao.saveProject(
      StudentProjectsCompanion.insert(
        studentId: student.id,
        title: title,
        topic: state.topic,
        projectType: state.projectType.toLowerCase().replaceAll(' ', '_'),
        stepsJson: Value(stepsJson),
        status: const Value('complete'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );

    state = state.copyWith(savedProjectId: id);

    // Award badge
    final badges = await ref
        .read(badgeServiceProvider)
        .onProjectSaved(student.id);
    ref.invalidate(studentProjectsProvider(student.id));

    if (context.mounted) {
      final badgeMsg = badges.isNotEmpty
          ? '\n🏅 Badge earned: ${badges.first.name}!'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Project saved!$badgeMsg'),
          backgroundColor: AppColors.teachColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

final _createProvider =
    AutoDisposeNotifierProvider<_CreateNotifier, _CreateState>(
      _CreateNotifier.new,
    );

// ── Screen ────────────────────────────────────────────────────────────────────

class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _topicController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _topicController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    final state = ref.watch(_createProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.started ? '${state.projectType}: ${state.topic}' : 'Create',
        ),
        actions: [
          if (state.started && state.savedProjectId == null)
            TextButton.icon(
              onPressed: state.isGenerating
                  ? null
                  : () =>
                        ref.read(_createProvider.notifier).saveProject(context),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          if (state.started)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'New project',
              onPressed: () => ref.invalidate(_createProvider),
            ),
        ],
      ),
      body: state.started
          ? _ChatView(
              state: state,
              scrollController: _scrollController,
              messageController: _messageController,
              onScrollToBottom: _scrollToBottom,
            )
          : _SetupView(topicController: _topicController),
    );
  }
}

// ── Setup view ────────────────────────────────────────────────────────────────

class _SetupView extends ConsumerWidget {
  const _SetupView({required this.topicController});
  final TextEditingController topicController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_createProvider);

    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 700 ? 3 : 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            Text(
              'What do you want to create?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 6),
            Text(
              'Your AI mentor will guide you step by step.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            const Text(
              'Project type',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.4,
              children: _projectTypes.map((pt) {
                final selected = state.projectType == pt.label;
                return GestureDetector(
                  onTap: () =>
                      ref.read(_createProvider.notifier).setType(pt.label),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : Theme.of(context).dividerColor,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          pt.icon,
                          size: 18,
                          color: selected
                              ? AppColors.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            pt.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: selected
                                  ? AppColors.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            const Text('Topic', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            TextField(
              controller: topicController,
              onChanged: ref.read(_createProvider.notifier).setTopic,
              decoration: InputDecoration(
                hintText: 'e.g. climate change, entrepreneurship, gravity…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),
            SizedBox(height: 12),
            if (state.projectType.isEmpty || state.topic.trim().isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  state.projectType.isEmpty
                      ? 'Pick a project type above to get started'
                      : 'Enter a topic to get started',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    state.projectType.isNotEmpty &&
                        state.topic.trim().isNotEmpty
                    ? () => ref.read(_createProvider.notifier).start()
                    : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Start creating'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chat view ─────────────────────────────────────────────────────────────────

class _ChatView extends ConsumerWidget {
  const _ChatView({
    required this.state,
    required this.scrollController,
    required this.messageController,
    required this.onScrollToBottom,
  });

  final _CreateState state;
  final ScrollController scrollController;
  final TextEditingController messageController;
  final VoidCallback onScrollToBottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCount =
        state.messages.length +
        (state.isGenerating && state.streamingText.isNotEmpty ? 1 : 0);

    return MaxWidth(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: allCount,
              itemBuilder: (_, i) {
                if (i == state.messages.length) {
                  return _Bubble(
                    text: state.streamingText,
                    isUser: false,
                    streaming: true,
                  );
                }
                final m = state.messages[i];
                return _Bubble(
                  text: m.text,
                  isUser: m.isUser,
                  streaming: false,
                );
              },
            ),
          ),
          if (state.savedProjectId != null)
            Container(
              color: AppColors.teachColor.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.teachColor,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Project saved!',
                    style: TextStyle(
                      color: AppColors.teachColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          _InputBar(
            controller: messageController,
            isLoading: state.isGenerating,
            onSend: (text) {
              messageController.clear();
              ref.read(_createProvider.notifier).send(text);
              onScrollToBottom();
            },
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.isUser,
    required this.streaming,
  });
  final String text;
  final bool isUser;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: isUser ? null : Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                text.isEmpty ? '…' : text,
                style: TextStyle(
                  color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
            ),
            if (streaming) ...[
              const SizedBox(width: 6),
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool isLoading;
  final void Function(String) onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        color: Theme.of(context).colorScheme.surface,
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (t) {
                if (t.trim().isNotEmpty) onSend(t.trim());
              },
              decoration: const InputDecoration(
                hintText: 'Reply...',
                border: InputBorder.none,
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          isLoading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : IconButton.filled(
                  onPressed: () {
                    final t = controller.text.trim();
                    if (t.isNotEmpty) onSend(t);
                  },
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
