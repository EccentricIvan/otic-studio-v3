import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';

class WebDevLabScreen extends ConsumerStatefulWidget {
  const WebDevLabScreen({super.key});

  @override
  ConsumerState<WebDevLabScreen> createState() => _WebDevLabScreenState();
}

class _WebDevLabScreenState extends ConsumerState<WebDevLabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _codeController = TextEditingController();
  WebViewController? _webViewController;
  bool _showPreview = false;

  static const _starterHtml = '''<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      font-family: Arial, sans-serif;
      padding: 20px;
      background: #f0f4f8;
      color: #1a202c;
    }
    h1 { color: #4F46E5; }
    .card {
      background: white;
      border-radius: 12px;
      padding: 20px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      margin-top: 16px;
    }
    button {
      background: #4F46E5;
      color: white;
      border: none;
      padding: 10px 20px;
      border-radius: 8px;
      font-size: 16px;
      cursor: pointer;
      margin-top: 12px;
    }
  </style>
</head>
<body>
  <h1>Hello World!</h1>
  <div class="card">
    <p>Edit this code and tap <b>Run</b> to see your changes!</p>
    <button onclick="alert('You clicked the button!')">Click Me</button>
  </div>

  <script>
    document.querySelector('h1').addEventListener('click', function() {
      this.style.color = this.style.color === 'red' ? '#4F46E5' : 'red';
    });
  </script>
</body>
</html>''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _codeController.text = _starterHtml;
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white);
    _runCode();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _runCode() {
    final html = _codeController.text;
    final encoded = base64Encode(utf8.encode(html));
    _webViewController?.loadRequest(
      Uri.parse('data:text/html;base64,$encoded'),
    );
    setState(() => _showPreview = true);
    _tabController.animateTo(1);
  }

  void _resetCode() {
    _codeController.text = _starterHtml;
    _runCode();
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.code, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Web Dev Lab'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.restart_alt),
            tooltip: 'Reset to starter code',
            onPressed: _resetCode,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.code), text: 'Code'),
            Tab(icon: Icon(Icons.visibility), text: 'Preview'),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _runCode,
        icon: Icon(Icons.play_arrow),
        label: Text('RUN'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CodeEditor(controller: _codeController),
          _Preview(controller: _webViewController),
        ],
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
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Color(0xFFCDD6F4),
          height: 1.5,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          hintText: 'Write your HTML, CSS, and JavaScript here...',
          hintStyle: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Color(0xFF585B70),
          ),
        ),
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.controller});
  final WebViewController? controller;

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.web, size: 48, color: Theme.of(context).hintColor),
            SizedBox(height: 12),
            Text(
              'Tap RUN to see your page',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      );
    }
    return WebViewWidget(controller: controller!);
  }
}
