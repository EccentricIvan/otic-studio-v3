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
  _Template('hotel', '🏨 Hotel / Lodge', Icons.hotel, [
    _QField('hotel_name', "What's the hotel name?", 'Grand Savanna Hotel'),
    _QField('tagline', "Your tagline?", 'Luxury meets African hospitality'),
    _QField('description', 'Describe the hotel.', 'A premier luxury hotel offering world-class accommodation with stunning views and exceptional service.'),
    _QField('price_standard', "Standard room price?", '150,000 UGX'),
    _QField('price_deluxe', "Deluxe suite price?", '350,000 UGX'),
    _QField('price_presidential', "Presidential suite price?", '800,000 UGX'),
    _QField('address', "Hotel address?", 'Plot 45, Kampala Road'),
    _QField('phone', "Phone number?", '+256 700 123 456'),
    _QField('email', "Email?", 'reservations@grandsavanna.com'),
  ]),
  _Template('fitness', '💪 Gym / Fitness', Icons.fitness_center, [
    _QField('gym_name', "What's the gym name?", 'Iron Forge Fitness'),
    _QField('tagline', "Your tagline?", 'Forge your best self'),
    _QField('description', 'Describe your gym.', 'A modern fitness center with top equipment, expert trainers, and a motivating atmosphere.'),
    _QField('price_basic', "Basic membership price?", '80,000 UGX'),
    _QField('price_premium', "Premium membership price?", '150,000 UGX'),
    _QField('price_student', "Student price?", '50,000 UGX'),
    _QField('address', "Gym address?", 'Plot 12, Industrial Area, Kampala'),
    _QField('phone', "Phone number?", '+256 700 123 456'),
    _QField('hours', "Opening hours?", 'Mon-Sat: 5AM - 10PM, Sun: 7AM - 6PM'),
  ]),
  _Template('salon', '💇 Salon / Spa', Icons.spa, [
    _QField('salon_name', "What's the salon name?", 'Glow Beauty Salon'),
    _QField('tagline', "Your tagline?", 'Where beauty meets elegance'),
    _QField('description', 'Describe your salon.', 'A premium beauty salon offering hair, nails, facials, and makeup services in a relaxing atmosphere.'),
    _QField('price_hair', "Hair styling price?", '30,000 UGX'),
    _QField('price_nails', "Manicure/pedicure price?", '25,000 UGX'),
    _QField('price_facial', "Facial treatment price?", '40,000 UGX'),
    _QField('price_makeup', "Makeup price?", '50,000 UGX'),
    _QField('about', 'Why should people choose you?', 'Expert stylists with 10+ years experience using premium products in a relaxing, modern space.'),
    _QField('hours_weekday', "Weekday hours?", '8AM - 7PM'),
    _QField('hours_saturday', "Saturday hours?", '8AM - 8PM'),
    _QField('hours_sunday', "Sunday hours?", '10AM - 5PM'),
    _QField('address', "Salon address?", 'Plot 8, Acacia Avenue, Kampala'),
    _QField('phone', "Phone number?", '+256 700 123 456'),
  ]),
  _Template('church', '⛪ Church / Ministry', Icons.church, [
    _QField('church_name', "What's the church name?", 'Grace Community Church'),
    _QField('motto', "Church motto?", 'Faith, Hope, and Love'),
    _QField('description', 'Describe the church.', 'A welcoming community of believers growing together in faith, serving our community with love.'),
    _QField('verse', "A favourite Bible verse?", 'For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you.'),
    _QField('verse_ref', "Verse reference?", 'Jeremiah 29:11'),
    _QField('time_sunday', "Sunday service time?", '9:00 AM & 11:00 AM'),
    _QField('time_bible', "Bible study time?", 'Wednesday 6:00 PM'),
    _QField('time_youth', "Youth service time?", 'Friday 5:00 PM'),
    _QField('address', "Church address?", 'Plot 20, Jinja Road, Kampala'),
    _QField('phone', "Phone number?", '+256 700 123 456'),
    _QField('email', "Email?", 'info@gracecommunity.org'),
  ]),
  _Template('realtor', '🏠 Real Estate', Icons.house, [
    _QField('company_name', "Company name?", 'Prime Properties Uganda'),
    _QField('tagline', "Your tagline?", 'Finding your perfect home'),
    _QField('description', 'Describe your company.', 'Uganda\'s trusted real estate agency helping families find their dream homes for over 10 years.'),
    _QField('prop1_name', "Property 1 name?", 'Modern Villa in Munyonyo'),
    _QField('prop1_beds', "Bedrooms?", '4'),
    _QField('prop1_baths', "Bathrooms?", '3'),
    _QField('prop1_size', "Size?", '2,500 sqft'),
    _QField('prop1_price', "Price?", '450M UGX'),
    _QField('prop1_location', "Location?", 'Munyonyo, Kampala'),
    _QField('prop2_name', "Property 2 name?", 'Apartment in Kololo'),
    _QField('prop2_beds', "Bedrooms?", '2'),
    _QField('prop2_baths', "Bathrooms?", '2'),
    _QField('prop2_size', "Size?", '1,200 sqft'),
    _QField('prop2_price', "Price?", '180M UGX'),
    _QField('prop2_location', "Location?", 'Kololo, Kampala'),
    _QField('prop3_name', "Property 3 name?", 'Family Home in Ntinda'),
    _QField('prop3_beds', "Bedrooms?", '3'),
    _QField('prop3_baths', "Bathrooms?", '2'),
    _QField('prop3_size', "Size?", '1,800 sqft'),
    _QField('prop3_price', "Price?", '280M UGX'),
    _QField('prop3_location', "Location?", 'Ntinda, Kampala'),
    _QField('properties_sold', "Total properties sold?", '500+'),
    _QField('years_exp', "Years experience?", '12'),
    _QField('clients', "Happy clients?", '1,200+'),
    _QField('address', "Office address?", 'Plot 5, Bombo Road, Kampala'),
    _QField('phone', "Phone?", '+256 700 123 456'),
    _QField('email', "Email?", 'info@primeproperties.ug'),
  ]),
  _Template('techstartup', '🚀 Tech Startup', Icons.rocket_launch, [
    _QField('company_name', "Company name?", 'NexaFlow'),
    _QField('tagline', "Your tagline?", 'Simplify everything. Build anything.'),
    _QField('feat1_title', "Feature 1 title?", 'Lightning Fast'),
    _QField('feat1_desc', "Feature 1 description?", 'Built for speed. Our platform loads in under 1 second.'),
    _QField('feat2_title', "Feature 2 title?", 'Bank-Level Security'),
    _QField('feat2_desc', "Feature 2 description?", 'End-to-end encryption protects your data at all times.'),
    _QField('feat3_title', "Feature 3 title?", 'Easy Integration'),
    _QField('feat3_desc', "Feature 3 description?", 'Connect with 100+ tools your team already uses.'),
    _QField('feat4_title', "Feature 4 title?", 'Global Scale'),
    _QField('feat4_desc', "Feature 4 description?", 'Serve millions of users across every continent.'),
    _QField('stat_users', "Number of users?", '50K+'),
    _QField('stat_countries', "Countries?", '30+'),
    _QField('stat_uptime', "Uptime?", '99.9%'),
    _QField('cta_text', "Call to action text?", 'Join thousands of teams already using NexaFlow to build better products faster.'),
    _QField('email', "Contact email?", 'hello@nexaflow.io'),
  ]),
  _Template('ngo', '🌍 NGO / Charity', Icons.volunteer_activism, [
    _QField('org_name', "Organization name?", 'Hope Foundation Uganda'),
    _QField('tagline', "Your tagline?", 'Building brighter futures together'),
    _QField('mission_title', "Mission headline?", 'Our Mission'),
    _QField('mission', "Mission statement?", 'Empowering communities through education, healthcare, and sustainable development across East Africa.'),
    _QField('impact1_num', "Impact stat 1 number?", '15,000+'),
    _QField('impact1_label', "Impact stat 1 label?", 'Lives Changed'),
    _QField('impact2_num', "Impact stat 2 number?", '50+'),
    _QField('impact2_label', "Impact stat 2 label?", 'Communities'),
    _QField('impact3_num', "Impact stat 3 number?", '8'),
    _QField('impact3_label', "Impact stat 3 label?", 'Years Active'),
    _QField('prog1_name', "Program 1 name?", 'Education for All'),
    _QField('prog1_desc', "Program 1 description?", 'Scholarships and school supplies for 5,000 children in rural communities.'),
    _QField('prog2_name', "Program 2 name?", 'Clean Water Initiative'),
    _QField('prog2_desc', "Program 2 description?", 'Building wells and water purification systems in 30 villages.'),
    _QField('prog3_name', "Program 3 name?", 'Youth Skills Training'),
    _QField('prog3_desc', "Program 3 description?", 'Teaching digital skills, tailoring, and agriculture to 2,000 young people.'),
    _QField('donate_text', "Donation appeal text?", 'Every contribution helps us reach more communities. Together we can make a lasting difference.'),
    _QField('address', "Office address?", 'Plot 15, Buganda Road, Kampala'),
    _QField('phone', "Phone?", '+256 700 123 456'),
    _QField('email', "Email?", 'info@hopefoundation.org'),
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
    _addBot("1️⃣ Bakery / Restaurant\n2️⃣ Hotel / Lodge\n3️⃣ Gym / Fitness\n4️⃣ Salon / Spa\n5️⃣ Church / Ministry\n6️⃣ Real Estate\n7️⃣ Tech Startup\n8️⃣ NGO / Charity\n9️⃣ Personal Portfolio\n🔟 School Website\n\nJust type the number or name!");
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

    final matchers = <int, List<String>>{
      0: ['1', 'bakery', 'restaurant', 'food', 'cafe'],
      1: ['2', 'hotel', 'lodge', 'guest house', 'accommodation'],
      2: ['3', 'gym', 'fitness', 'workout'],
      3: ['4', 'salon', 'spa', 'beauty', 'hair'],
      4: ['5', 'church', 'ministry', 'chapel', 'worship'],
      5: ['6', 'real estate', 'property', 'realtor', 'house'],
      6: ['7', 'tech', 'startup', 'saas', 'software'],
      7: ['8', 'ngo', 'charity', 'foundation', 'nonprofit'],
      8: ['9', 'portfolio', 'personal', 'resume', 'cv'],
      9: ['10', 'school', 'academy', 'college', 'education'],
    };

    for (final entry in matchers.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          chosen = _templates[entry.key];
          break;
        }
      }
      if (chosen != null) break;
    }

    if (chosen == null) {
      _addBot("I didn't catch that. Please type a number (1-10) or the name:\n\n1 Bakery  2 Hotel  3 Gym  4 Salon  5 Church\n6 Real Estate  7 Tech  8 NGO  9 Portfolio  10 School");
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
