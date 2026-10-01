import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fllama/fllama.dart';

void main() {
  runApp(const LocalAiApp());
}

class LocalAiApp extends StatelessWidget {
  const LocalAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Local',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080C14),
        cardColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];

  String? _modelPath;
  bool _isModelLoaded = false;
  bool _isGenerating = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickModelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );

    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;

    if (path.toLowerCase().endsWith('.gguf')) {
      setState(() {
        _modelPath = path;
        _isModelLoaded = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحميل النموذج بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      setState(() {
        _modelPath = null;
        _isModelLoaded = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى اختيار ملف بصيغة .gguf'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || !_isModelLoaded || _isGenerating) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _messages.add({'sender': 'ai', 'text': ''});
      _isGenerating = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final req = OpenAiRequest(
        modelPath: _modelPath!,
        messages: [Message(Role.user, text)],
        contextSize: 2048,
        temperature: 0.7,
      );

      String aiResponse = '';

      await fllamaChat(req, (response, token, isDone) {
        if (response.isNotEmpty) {
          aiResponse += response;
          if (mounted) {
            setState(() {
              _messages.last = {'sender': 'ai', 'text': aiResponse};
            });
            _scrollToBottom();
          }
        }
        if (isDone) {
          if (mounted) {
            setState(() => _isGenerating = false);
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.last = {'sender': 'ai', 'text': 'حدث خطأ: $e'};
          _isGenerating = false;
        });
      }
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Local'),
        actions: [
          IconButton(
            tooltip: 'اختر نموذج',
            icon: Icon(
              _isModelLoaded ? Icons.check_circle : Icons.folder_open,
              color: _isModelLoaded ? Colors.greenAccent : Colors.white,
            ),
            onPressed: _isGenerating ? null : _pickModelFile,
          ),
          if (_isModelLoaded)
            IconButton(
              tooltip: 'إلغاء التحميل',
              icon: const Icon(Icons.close, color: Colors.redAccent),
              onPressed: _isGenerating
                  ? null
                  : () {
                      setState(() {
                        _modelPath = null;
                        _isModelLoaded = false;
                        _messages.clear();
                      });
                    },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _emptyState() : _messagesList(),
          ),
          if (_isGenerating)
            const LinearProgressIndicator(
              minHeight: 2,
              color: Colors.blue,
            ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isModelLoaded ? Icons.chat_bubble_outline : Icons.folder_open,
            size: 80,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            _isModelLoaded
                ? 'النموذج جاهز، ابدأ المحادثة'
                : 'اختر نموذجاً بصيغة .gguf للبدء',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg['sender'] == 'user';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? Colors.blue.shade700
                  : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              msg['text'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: const Color(0xFF0F172A),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: _isModelLoaded && !_isGenerating,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالتك',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blue),
              onPressed:
                  (_isModelLoaded && !_isGenerating) ? _sendMessage : null,
            ),
          ],
        ),
      ),
    );
  }
}