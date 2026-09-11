import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
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
    _startNewChat();
    _loadLatestChat(); // 🚀 Automatically load most recent chat
  }

  void _startNewChat() {
    setState(() {
      _currentChatId = null;
      _messages.clear();
      _messages.add(Map.from(_initialGreeting));
    });
  }

  Future<void> _loadLatestChat() async {
    if (currentUser == null) return;
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
      }
    } catch (e) {
      debugPrint("Error finding latest chat: $e");
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
      }

      final apiKey = dotenv.env['AI_API_KEY'] ?? "";
      final response = await http.post(
        Uri.parse("https://openrouter.ai/api/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
          "HTTP-Referer": "https://digitalislamichub.com",
        },
        body: jsonEncode({
          "model": "google/learnlm-1.5-pro-experimental:free",
          "messages": [
            {
              "role": "system",
              "content": "You are an expert Islamic Scholar (Mufti). Answer all user queries strictly based on the Quran and authentic Hadith with references."
            },
            ..._messages,
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiText = data['choices'][0]['message']['content'];

        if (mounted) {
          setState(() {
            _messages.add({"role": "assistant", "content": aiText});
          });
          _scrollToBottom();
        }

        if (_currentChatId != null && currentUser != null) {
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
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connection error. Please try again.")),
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
      body: Column(
        children: [
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
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
            const Padding(padding: EdgeInsets.all(10), child: Text("Scholar is typing...", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey))),
          _buildInput(isDark),
        ],
      ),
    );
  }

  Widget _buildInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(hintText: "Ask something...", border: InputBorder.none),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(icon: const Icon(Icons.send, color: AppTheme.accentGreen), onPressed: _sendMessage),
        ],
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
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
}
