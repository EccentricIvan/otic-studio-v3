import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';

// Python runs in browser via Brython (Python-to-JS transpiler bundled in HTML)

class _PyLesson {
  const _PyLesson({required this.title, required this.instruction, required this.starterCode, this.hint, this.challenge});
  final String title, instruction, starterCode;
  final String? hint, challenge;
}

const _lessons = [
  _PyLesson(
    title: 'Lesson 1: Hello Python!',
    instruction: 'print() displays text on screen. Try changing the message inside the quotes and tap RUN.',
    starterCode: '''# Your first Python program!
print("Hello World!")
print("My name is Otic")

# Try adding another print() below:
''',
    hint: 'Add: print("I am learning Python!")',
    challenge: 'Print your name and your age on separate lines.',
  ),
  _PyLesson(
    title: 'Lesson 2: Variables',
    instruction: 'Variables store data. Use = to assign a value. Try changing the values and see what prints.',
    starterCode: '''# Variables store information
name = "Alice"
age = 15
subject = "Mathematics"

print("Name:", name)
print("Age:", age)
print("Favourite subject:", subject)

# Try changing the values above!
''',
    hint: 'Try adding: hobby = "coding" and printing it.',
    challenge: 'Create variables for your school name and grade, then print a sentence using them.',
  ),
  _PyLesson(
    title: 'Lesson 3: Math Operations',
    instruction: 'Python does math with +, -, *, /, ** (power), // (integer division), % (remainder). Try the examples.',
    starterCode: '''# Basic math
a = 10
b = 3

print("Add:", a + b)
print("Subtract:", a - b)
print("Multiply:", a * b)
print("Divide:", a / b)
print("Power:", a ** 2)
print("Remainder:", a % b)

# Calculate the area of a rectangle
length = 8
width = 5
area = length * width
print("Area:", area)
''',
    hint: 'Try calculating the perimeter: perimeter = 2 * (length + width)',
    challenge: 'Calculate the area of a circle with radius 7 (use 3.14159 for pi).',
  ),
  _PyLesson(
    title: 'Lesson 4: If/Else Decisions',
    instruction: 'Programs make decisions with if/elif/else. The indented code runs only when the condition is True. Try changing the age.',
    starterCode: '''# Making decisions
age = 16

if age >= 18:
    print("You are an adult")
elif age >= 13:
    print("You are a teenager")
else:
    print("You are a child")

# Grade checker
score = 75

if score >= 80:
    print("Grade: A - Excellent!")
elif score >= 60:
    print("Grade: B - Good!")
elif score >= 40:
    print("Grade: C - Keep trying!")
else:
    print("Grade: F - Study harder!")
''',
    hint: 'Try changing score to different values and see the grade change.',
    challenge: 'Add a check: if score is exactly 100, print "Perfect score!"',
  ),
  _PyLesson(
    title: 'Lesson 5: Loops',
    instruction: 'for loops repeat a set number of times. while loops repeat until a condition is False. Try modifying the ranges.',
    starterCode: '''# For loop - repeat 5 times
print("Counting:")
for i in range(1, 6):
    print(i)

print()

# Loop through a list
fruits = ["apple", "banana", "mango"]
for fruit in fruits:
    print("I like", fruit)

print()

# While loop
count = 1
while count <= 3:
    print("Count is:", count)
    count = count + 1

print("Done!")
''',
    hint: 'Try range(1, 11) to count to 10. Or add more fruits to the list.',
    challenge: 'Write a loop that prints the multiplication table for 7 (7x1=7, 7x2=14, etc).',
  ),
  _PyLesson(
    title: 'Lesson 6: Functions',
    instruction: 'Functions are reusable blocks of code. Define with def, call by name. They can take parameters and return values.',
    starterCode: '''# Define a function
def greet(name):
    print("Hello, " + name + "!")

# Call it
greet("Alice")
greet("Bob")

# Function with return value
def add(a, b):
    return a + b

result = add(5, 3)
print("5 + 3 =", result)

# Function to check even/odd
def is_even(number):
    if number % 2 == 0:
        return "even"
    else:
        return "odd"

print("7 is", is_even(7))
print("10 is", is_even(10))
''',
    hint: 'Try creating a function multiply(a, b) that returns a * b.',
    challenge: 'Write a function called factorial(n) that calculates n! (e.g., factorial(5) = 120).',
  ),
  _PyLesson(
    title: 'Lesson 7: Lists',
    instruction: 'Lists store multiple items in order. Access by index (starting at 0). Add with append(), remove with remove().',
    starterCode: '''# Create a list
scores = [85, 92, 78, 95, 88]
print("All scores:", scores)
print("First score:", scores[0])
print("Last score:", scores[-1])
print("How many:", len(scores))

# Add and remove
scores.append(91)
print("After adding 91:", scores)

# List operations
print("Highest:", max(scores))
print("Lowest:", min(scores))
print("Average:", sum(scores) / len(scores))

# Sort
scores.sort()
print("Sorted:", scores)

# Loop through
print("\\nAll scores:")
for s in scores:
    print(" -", s)
''',
    hint: 'Try scores.reverse() after sorting to see descending order.',
    challenge: 'Create a list of 5 student names, sort them alphabetically, and print each with a number (1. Alice, 2. Bob...).',
  ),
  _PyLesson(
    title: 'Lesson 8: Build a Quiz Game',
    instruction: 'Combine everything! This quiz game uses variables, lists, loops, functions, and if/else. Customize the questions!',
    starterCode: '''# Quiz Game!
print("=== Python Quiz Game ===")
print()

score = 0
total = 0

def ask(question, options, correct):
    global score, total
    total = total + 1
    print("Q" + str(total) + ": " + question)
    for i in range(len(options)):
        letter = chr(65 + i)  # A, B, C, D
        print("  " + letter + ") " + options[i])
    print("  Answer: " + chr(65 + correct))
    # Auto-answer for demo (in real app, user would input)
    score = score + 1
    print("  Correct!\\n")

# Questions
ask(
    "What does print() do?",
    ["Sends to printer", "Displays text on screen", "Saves a file", "Nothing"],
    1
)

ask(
    "Which is a valid variable name?",
    ["1name", "my-var", "student_age", "class"],
    2
)

ask(
    "What does len() return?",
    ["The last item", "The first item", "The number of items", "Nothing"],
    2
)

ask(
    "How do you start a function?",
    ["function:", "def:", "fun:", "define:"],
    1
)

# Results
print("=" * 30)
print("Score:", score, "/", total)
percent = int(score / total * 100)
print("Percentage:", str(percent) + "%")

if percent == 100:
    print("Perfect! You are a Python master!")
elif percent >= 75:
    print("Great job! Keep learning!")
else:
    print("Keep practising! You will get there!")
''',
    hint: 'Add your own question using the ask() function.',
    challenge: 'Modify the game to actually track wrong answers and show which ones the user got wrong at the end.',
  ),
];

// ── HTML wrapper that runs Python in browser via Brython ──

String _buildPythonHtml(String code) {
  final escaped = code
      .replaceAll('\\', '\\\\')
      .replaceAll('`', '\\`')
      .replaceAll('\$', '\\\$');

  return '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="https://cdn.jsdelivr.net/npm/brython@3/brython.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/brython@3/brython_stdlib.js"></script>
<style>
  body { background: #1E1E2E; color: #CDD6F4; font-family: monospace; padding: 16px; margin: 0; }
  #output { white-space: pre-wrap; font-size: 14px; line-height: 1.6; }
  .error { color: #F38BA8; }
  .header { color: #89B4FA; margin-bottom: 12px; font-size: 12px; }
</style>
</head>
<body onload="brython({debug:0})">
<div class="header">>>> Python Output</div>
<div id="output"></div>
<script type="text/python">
from browser import document
import sys
import io

class WebOutput:
    def __init__(self):
        self.data = ""
    def write(self, text):
        self.data += str(text)
        document["output"].html = self.data.replace("\\n", "<br>")
    def flush(self):
        pass

sys.stdout = WebOutput()
sys.stderr = WebOutput()

try:
    exec("""$escaped""")
except Exception as e:
    document["output"].html += '<span class="error">Error: ' + str(e) + '</span>'
</script>
</body>
</html>''';
}

// ── Screen ───────────────────────────────────────────────────────────────────

class PythonLabScreen extends ConsumerStatefulWidget {
  const PythonLabScreen({super.key});

  @override
  ConsumerState<PythonLabScreen> createState() => _PythonLabScreenState();
}

class _PythonLabScreenState extends ConsumerState<PythonLabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _codeController = TextEditingController();
  WebViewController? _webViewController;
  int _currentLesson = 0;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _codeController.text = _lessons[0].starterCode;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Color(0xFF1E1E2E));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _runCode() {
    final html = _buildPythonHtml(_codeController.text);
    final encoded = base64Encode(utf8.encode(html));
    _webViewController?.loadRequest(Uri.parse('data:text/html;base64,$encoded'));
    _tabController.animateTo(1);
  }

  void _loadLesson(int index) {
    setState(() {
      _currentLesson = index;
      _showHint = false;
      _codeController.text = _lessons[index].starterCode;
    });
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lessons[_currentLesson];

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.terminal, size: 20, color: Color(0xFF3572A5)),
          SizedBox(width: 8),
          Text('Python Lab'),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.list),
            tooltip: 'All lessons',
            onPressed: () => _showLessonPicker(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(icon: Icon(Icons.code), text: 'Code'), Tab(icon: Icon(Icons.terminal), text: 'Output')],
          indicatorColor: Color(0xFF3572A5),
          labelColor: Color(0xFF3572A5),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _runCode,
        icon: Icon(Icons.play_arrow),
        label: Text('RUN'),
        backgroundColor: Color(0xFF3572A5),
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(children: [
            _InstructionBar(
              lesson: lesson,
              index: _currentLesson,
              total: _lessons.length,
              showHint: _showHint,
              onToggleHint: () => setState(() => _showHint = !_showHint),
              onNext: _currentLesson < _lessons.length - 1 ? () => _loadLesson(_currentLesson + 1) : null,
              onPrev: _currentLesson > 0 ? () => _loadLesson(_currentLesson - 1) : null,
            ),
            Expanded(child: _CodeEditor(controller: _codeController)),
          ]),
          _webViewController != null
              ? WebViewWidget(controller: _webViewController!)
              : Center(child: Text('Tap RUN to see output', style: TextStyle(color: Theme.of(context).hintColor))),
        ],
      ),
    );
  }

  void _showLessonPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: _lessons.length,
        itemBuilder: (_, i) {
          final l = _lessons[i];
          final isCurrent = i == _currentLesson;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isCurrent ? Color(0xFF3572A5) : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text('${i + 1}', style: TextStyle(color: isCurrent ? Colors.white : Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
            ),
            title: Text(l.title, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
            subtitle: Text(l.instruction, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () { Navigator.pop(ctx); _loadLesson(i); },
          );
        },
      ),
    );
  }
}

// ── Shared widgets (same pattern as Web Dev Lab) ─────────────────────────────

class _InstructionBar extends StatelessWidget {
  const _InstructionBar({required this.lesson, required this.index, required this.total, required this.showHint, required this.onToggleHint, this.onNext, this.onPrev});
  final _PyLesson lesson;
  final int index, total;
  final bool showHint;
  final VoidCallback onToggleHint;
  final VoidCallback? onNext, onPrev;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(child: Text(lesson.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF3572A5)))),
            Text('${index + 1}/$total', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(lesson.instruction, style: TextStyle(fontSize: 13, height: 1.5, color: Theme.of(context).colorScheme.onSurface)),
        ),
        if (showHint && lesson.hint != null)
          Container(
            margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFF3572A5).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF3572A5).withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.lightbulb, size: 14, color: Color(0xFF3572A5)), SizedBox(width: 6), Text('Hint', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF3572A5)))]),
              SizedBox(height: 4),
              Text(lesson.hint!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
              if (lesson.challenge != null) ...[
                SizedBox(height: 8),
                Row(children: [Icon(Icons.emoji_events, size: 14, color: AppColors.createColor), SizedBox(width: 6), Text('Challenge', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.createColor))]),
                SizedBox(height: 4),
                Text(lesson.challenge!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
              ],
            ]),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(children: [
            if (onPrev != null) _Btn(icon: Icons.arrow_back, label: 'Prev', onTap: onPrev!),
            if (onPrev != null) SizedBox(width: 8),
            _Btn(icon: showHint ? Icons.lightbulb : Icons.lightbulb_outline, label: showHint ? 'Hide' : 'Hint', onTap: onToggleHint),
            Spacer(),
            if (onNext != null) _Btn(icon: Icons.arrow_forward, label: 'Next', onTap: onNext!, primary: true),
          ]),
        ),
        Divider(height: 1),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon; final String label; final VoidCallback onTap; final bool primary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary ? Color(0xFF3572A5) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: primary ? null : Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: primary ? Colors.white : Theme.of(context).colorScheme.onSurface),
          SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary ? Colors.white : Theme.of(context).colorScheme.onSurface)),
        ]),
      ),
    );
  }
}

class _CodeEditor extends StatelessWidget {
  const _CodeEditor({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF1E1E2E),
      child: TextField(
        controller: controller,
        maxLines: null,
        expands: true,
        style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFFCDD6F4), height: 1.5),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          hintText: 'Write your Python code here...',
          hintStyle: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFF585B70)),
        ),
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
      ),
    );
  }
}
