import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/app_env.dart';
import '../theme/app_theme.dart';
import 'scholar_list_screen.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isTyping = false;
  bool _isLoadingHistory = false;
  String? _currentChatId;

  final List<Map<String, String>> _messages = [];

  final Map<String, String> _initialGreeting = {
    "role": "assistant",
    "content":
    "Assalamu Alaikum! I am your Islamic AI assistant. How can I help you with your queries today?"
  };

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadLatestChat();
    if (!mounted) return;
    if (_currentChatId == null && _messages.isEmpty) {
      _startNewChat();
    }
  }

  void _startNewChat() {
    setState(() {
      _currentChatId = null;
      _messages
        ..clear()
        ..add(Map.from(_initialGreeting));
    });
  }

  Future<void> _loadLatestChat() async {
    if (currentUser == null) {
      if (mounted) _startNewChat();
      return;
    }
    setState(() => _isLoadingHistory = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('ai_chats')
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await _loadChatSession(snapshot.docs.first.id);
      } else if (mounted) {
        _startNewChat();
      }
    } catch (e) {
      debugPrint('Error finding latest chat: $e');
      if (mounted) _startNewChat();
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadChatSession(String chatId) async {
    if (!mounted) return;
    setState(() {
      _currentChatId = chatId;
      _isLoadingHistory = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .collection('ai_chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .get();

      final List<Map<String, String>> loadedMessages = [
        Map.from(_initialGreeting)
      ];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        loadedMessages.add({
          "role": data['role'] ?? "user",
          "content": data['content'] ?? "",
        });
      }

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(loadedMessages);
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Error loading chat history: $e");
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
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

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isTyping) return;

    final userText = _controller.text.trim();
    _controller.clear();

    setState(() {
      _messages.add({"role": "user", "content": userText});
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      if (_currentChatId == null && currentUser != null) {
        String title = userText.length > 30
            ? "${userText.substring(0, 30)}..."
            : userText;

        final chatDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('ai_chats')
            .add({
          'title': title,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        _currentChatId = chatDoc.id;
      }

      if (_currentChatId != null && currentUser != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .collection('ai_chats')
              .doc(_currentChatId)
              .collection('messages')
              .add({
            'role': 'user',
            'content': userText,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('AI chat auto-save error: $e');
        }
      }

      final apiKey = AppEnv.aiApiKey.trim(); // Ensure no hidden spaces
      if (apiKey.isEmpty) {
        throw StateError('missing_api_key');
      }

      debugPrint('🤖 [AI] Sending request to OpenRouter with model: openrouter/auto');
      
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://digitalislamichub.com',
          'X-Title': 'Digital Islamic Hub',
        },
        body: jsonEncode({
          'model': 'openrouter/auto',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an expert Islamic Scholar (Mufti). Answer all user queries strictly based on the Quran and authentic Hadith with references. Use a polite and helpful tone. Always start with Salaam.'
            },
            ..._messages,
          ],
        }),
      ).timeout(const Duration(seconds: 40));

      debugPrint('🤖 AI Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'] as List?;
        if (choices == null || choices.isEmpty) {
           throw Exception('AI returned no response choices.');
        }
        
        final aiText = choices[0]['message']?['content'] as String? ?? '';
        
        if (aiText.isEmpty) {
          throw Exception('AI returned an empty message.');
        }

        if (mounted) {
          setState(() {
            _messages.add({'role': 'assistant', 'content': aiText});
          });
          _scrollToBottom();
        }

        if (_currentChatId != null && currentUser != null && aiText.isNotEmpty) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser!.uid)
                .collection('ai_chats')
                .doc(_currentChatId)
                .collection('messages')
                .add({
              'role': 'assistant',
              'content': aiText,
              'createdAt': FieldValue.serverTimestamp(),
            });

            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser!.uid)
                .collection('ai_chats')
                .doc(_currentChatId)
                .update({'updatedAt': FieldValue.serverTimestamp()});
          } catch (e) {
            debugPrint('AI reply auto-save error: $e');
          }
        }
      } else {
        throw Exception('AI request failed (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ [AI Error Detail] $e');
      if (mounted) {
        String message = 'AI Error: ${e.toString().replaceAll('Exception:', '')}';
        if (e is StateError && e.message == 'missing_api_key') {
          message = 'AI API Key is missing in .env file.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  Future<void> _deleteChatSession(String chatId) async {
    if (currentUser == null) return;
    try {
      final messages = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('ai_chats')
          .doc(chatId)
          .collection('messages')
          .get();

      for (var doc in messages.docs) { await doc.reference.delete(); }
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('ai_chats').doc(chatId).delete();

      if (_currentChatId == chatId) _startNewChat();
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Islamic AI Assistant"),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add_comment_outlined), onPressed: _startNewChat),
        ],
      ),
      drawer: _buildHistoryDrawer(isDark),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: _isLoadingHistory
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["role"] == "user";

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isUser ? (isDark ? AppTheme.accentGreen : AppTheme.primaryLight) : (isDark ? Colors.white.withAlpha(20) : Colors.grey.shade200),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isUser ? 16 : 0),
                            bottomRight: Radius.circular(isUser ? 0 : 16),
                          ),
                        ),
                        child: Text(msg["content"]!, style: TextStyle(color: isUser ? (isDark ? AppTheme.primaryDark : Colors.white) : (isDark ? Colors.white70 : Colors.black87))),
                      ),
                      if (!isUser && index > 0)
                        TextButton.icon(
                          onPressed: () {
                             Navigator.push(context, MaterialPageRoute(builder: (context) => ScholarListScreen(
                               questionData: {'questionText': _messages[index - 1]["content"], 'aiAnswer': msg["content"]},
                             )));
                          },
                          icon: const Icon(Icons.verified_user_outlined, size: 14, color: AppTheme.accentGreen),
                          label: const Text("Verify with Scholar", style: TextStyle(fontSize: 11, color: AppTheme.accentGreen)),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentGreen),
                  ),
                  SizedBox(width: 10),
                  Text("Islamic AI Assistant is typing...", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
          _buildInput(isDark),
        ],
      ),
      ),
    );
  }

  Widget _buildInput(bool isDark) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
          boxShadow: [
            if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "Ask your Islamic query...",
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            Material(
              color: AppTheme.accentGreen,
              borderRadius: BorderRadius.circular(24),
              child: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                onPressed: _sendMessage,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryDrawer(bool isDark) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight),
            child: const Center(child: Text("Chat History", style: TextStyle(color: Colors.white, fontSize: 20))),
          ),
          Expanded(
            child: currentUser == null
                ? const Center(child: Text("Login to see history"))
                : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('ai_chats').orderBy('updatedAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load chat history.'));
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No saved chats yet'));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    return ListTile(
                      title: Text(doc['title'] ?? 'Chat', maxLines: 1),
                      selected: _currentChatId == doc.id,
                      trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _deleteChatSession(doc.id)),
                      onTap: () { Navigator.pop(context); _loadChatSession(doc.id); },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
