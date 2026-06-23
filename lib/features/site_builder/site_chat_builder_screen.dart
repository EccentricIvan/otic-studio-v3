import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';

class _Template {
  const _Template(this.id, this.name, this.icon, this.fields);
  final String id, name;
  final IconData icon;
  final List<_QField> fields;
}

class _QField {
  const _QField(this.key, this.question, this.defaultValue);
  final String key, question, defaultValue;
}

const _templates = [
  _Template('bakery', '🍞 Bakery / Restaurant', Icons.bakery_dining, [
    _QField('business_name', "What's the name of your business?", 'Sweet Treats Bakery'),
    _QField('tagline', "What's your tagline or slogan?", 'Fresh baked daily with love'),
    _QField('description', 'Describe your business in 1-2 sentences.', 'We bake fresh bread, cakes, and pastries every morning using locally sourced ingredients.'),
    _QField('about', 'Tell me your story — how did you start?', 'Started in 2020 by a family passionate about baking. Every item is made from scratch.'),
    _QField('address', "What's your address?", 'Plot 15, Main Street, Kampala'),
    _QField('phone', "What's your phone number?", '+256 700 123 456'),
  ]),
  _Template('portfolio', '👤 Personal Portfolio', Icons.person, [
    _QField('name', "What's your full name?", 'Alice Nakamya'),
    _QField('title', "What's your title or role?", 'Student Developer & Designer'),
    _QField('about', 'Tell me about yourself (2-3 sentences).', 'I am a passionate student developer learning to build websites and apps.'),
    _QField('skill1', 'Skill #1?', 'HTML & CSS'),
    _QField('skill2', 'Skill #2?', 'JavaScript'),
    _QField('skill3', 'Skill #3?', 'Python'),
    _QField('skill4', 'Skill #4?', 'Flutter'),
    _QField('skill5', 'Skill #5?', 'UI Design'),
    _QField('project1_name', 'Name of your first project?', 'School Website'),
    _QField('project1_desc', 'Describe it briefly.', 'Built a responsive website for my school.'),
    _QField('project2_name', 'Second project name?', 'Weather App'),
    _QField('project2_desc', 'Describe it.', 'A mobile app showing weather forecasts.'),
    _QField('project3_name', 'Third project name?', 'Quiz Game'),
    _QField('project3_desc', 'Describe it.', 'An interactive quiz game across multiple subjects.'),
    _QField('email', "Your email?", 'alice@example.com'),
    _QField('phone', "Your phone?", '+256 700 123 456'),
    _QField('location', "Your location?", 'Kampala, Uganda'),
  ]),
  _Template('school', '🎓 School Website', Icons.school, [
    _QField('school_name', "What's the school name?", 'Bright Future Academy'),
    _QField('motto', "What's the school motto?", 'Excellence Through Education'),
    _QField('description', 'Describe the school in 2-3 sentences.', 'A leading institution providing quality education from primary through secondary level.'),
    _QField('students', 'How many students?', '850'),
    _QField('teachers', 'How many teachers?', '45'),
    _QField('years', 'How many years established?', '15'),
    _QField('pass_rate', "What's the pass rate?", '92%'),
    _QField('address', 'School address?', 'Plot 23, Education Road, Kampala'),
    _QField('phone', 'School phone?', '+256 700 123 456'),
    _QField('email', 'School email?', 'info@brightfuture.ac.ug'),
  ]),
];

// ── Chat messages ────────────────────────────────────────────────────────────

class _ChatMsg {
  const _ChatMsg(this.text, this.isBot);
  final String text;
  final bool isBot;
}

// ── Screen ───────────────────────────────────────────────────────────────────

class SiteChatBuilderScreen extends StatefulWidget {
  const SiteChatBuilderScreen({super.key});

  @override
  State<SiteChatBuilderScreen> createState() => _SiteChatBuilderScreenState();
}

class _SiteChatBuilderScreenState extends State<SiteChatBuilderScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMsg> _messages = [];
  final Map<String, String> _answers = {};

  _Template? _template;
  int _fieldIndex = -1;
  bool _choosingTemplate = true;
  bool _building = false;
  bool _showPreview = false;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _addBot("Hi! I'm going to help you build a website. 🚀\n\nWhat type of site do you want?");
    _addBot("1️⃣ Bakery / Restaurant\n2️⃣ Personal Portfolio\n3️⃣ School Website\n\nJust type the number or name!");
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBot(String text) {
    setState(() => _messages.add(_ChatMsg(text, true)));
    _scrollDown();
  }

  void _addUser(String text) {
    setState(() => _messages.add(_ChatMsg(text, false)));
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _addUser(text);

    if (_choosingTemplate) {
      _handleTemplateChoice(text);
    } else if (_fieldIndex >= 0 && _template != null) {
      _handleFieldAnswer(text);
    }
  }

  void _handleTemplateChoice(String text) {
    final lower = text.toLowerCase();
    _Template? chosen;

    if (lower.contains('1') || lower.contains('bakery') || lower.contains('restaurant') || lower.contains('food')) {
      chosen = _templates[0];
    } else if (lower.contains('2') || lower.contains('portfolio') || lower.contains('personal')) {
      chosen = _templates[1];
    } else if (lower.contains('3') || lower.contains('school') || lower.contains('academy')) {
      chosen = _templates[2];
    }

    if (chosen == null) {
      _addBot("I didn't catch that. Please type 1, 2, or 3:\n\n1️⃣ Bakery\n2️⃣ Portfolio\n3️⃣ School");
      return;
    }

    _template = chosen;
    _choosingTemplate = false;
    _fieldIndex = 0;

    _addBot("Great choice — ${chosen.name}! Let's fill in the details.\n\nI'll ask you one question at a time. Just type your answer or press Enter to use the suggestion.");
    Future.delayed(Duration(milliseconds: 500), () {
      _askCurrentField();
    });
  }

  void _askCurrentField() {
    if (_template == null || _fieldIndex >= _template!.fields.length) return;
    final field = _template!.fields[_fieldIndex];
    _addBot("${field.question}\n\n💡 Suggestion: ${field.defaultValue}");
  }

  void _handleFieldAnswer(String text) {
    final field = _template!.fields[_fieldIndex];

    // Use default if user just sends empty-ish response
    final answer = text.trim().isEmpty || text.trim() == '.' || text.trim().toLowerCase() == 'skip'
        ? field.defaultValue
        : text.trim();

    _answers[field.key] = answer;
    _fieldIndex++;

    if (_fieldIndex >= _template!.fields.length) {
      _addBot("Perfect! All details collected. ✅\n\n🔨 Building your website now...");
      Future.delayed(Duration(milliseconds: 800), () {
        _buildSite();
      });
    } else {
      Future.delayed(Duration(milliseconds: 400), () {
        _askCurrentField();
      });
    }
  }

  Future<void> _buildSite() async {
    setState(() => _building = true);

    var html = await rootBundle.loadString('assets/templates/${_template!.id}.html');

    for (final field in _template!.fields) {
      final value = _answers[field.key] ?? field.defaultValue;
      html = html.replaceAll('{{${field.key}}}', value);
    }

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white);

    final encoded = base64Encode(utf8.encode(html));
    await _webViewController!.loadRequest(Uri.parse('data:text/html;base64,$encoded'));

    _addBot("Your website is ready! 🎉 Tap the preview button below to see it.");

    setState(() {
      _building = false;
      _showPreview = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.chat, size: 20, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Site Builder'),
        ]),
        actions: [
          if (_showPreview)
            TextButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text('Your Website')),
                    body: WebViewWidget(controller: _webViewController!),
                  ),
                ));
              },
              icon: Icon(Icons.visibility, size: 18),
              label: Text('Preview'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_showPreview ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length && _showPreview) {
                  return _PreviewCard(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text('Your Website')),
                          body: WebViewWidget(controller: _webViewController!),
                        ),
                      ));
                    },
                  );
                }
                final msg = _messages[i];
                return _ChatBubble(text: msg.text, isBot: msg.isBot);
              },
            ),
          ),

          // Building indicator
          if (_building)
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Building your site...', style: TextStyle(color: Theme.of(context).hintColor)),
                ],
              ),
            ),

          // Input bar
          if (!_showPreview)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                color: Theme.of(context).colorScheme.surface,
              ),
              padding: EdgeInsets.fromLTRB(16, 10, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _onSend(),
                      decoration: InputDecoration(
                        hintText: _choosingTemplate ? 'Type 1, 2, or 3...' : 'Type your answer...',
                        border: InputBorder.none,
                      ),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _onSend,
                    icon: Icon(Icons.arrow_upward),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Chat bubble ──────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isBot});
  final String text;
  final bool isBot;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isBot
              ? Theme.of(context).colorScheme.surface
              : AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isBot ? 4 : 16),
            topRight: Radius.circular(isBot ? 16 : 4),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: isBot ? Border.all(color: Theme.of(context).dividerColor) : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isBot ? Theme.of(context).colorScheme.onSurface : Colors.white,
            height: 1.5,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ── Preview card ─────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.teachColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.teachColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.teachColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.web, color: AppColors.teachColor),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your website is ready! 🎉', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.teachColor)),
                  SizedBox(height: 2),
                  Text('Tap to see the live preview', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.teachColor),
          ],
        ),
      ),
    );
  }
}
