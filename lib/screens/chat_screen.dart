import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../widgets/nav_drawer.dart';
import 'chat_history_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatSessionId;
  const ChatScreen({super.key, required this.chatSessionId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final apiKey = dotenv.env['GEMINI_API_KEY'];
  bool _isLoading = false;
  bool _isAtBottom = true; // Tracks if user is at the bottom
  Timer? _scrollDebounceTimer;

  late final GenerativeModel model;
  late final String userId;
  late String chatName;
  late String chatSessionId;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    chatSessionId = widget.chatSessionId;
    _scrollController.addListener(() {
      if (_scrollDebounceTimer?.isActive ?? false) _scrollDebounceTimer!.cancel();
      _scrollDebounceTimer = Timer(const Duration(milliseconds: 100), () {
        final atBottom = _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 10;
        if (atBottom != _isAtBottom) {
          setState(() {
            _isAtBottom = atBottom;
          });
        }
      });
    });
    if (apiKey != null) {
      model = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: apiKey!,
        generationConfig: GenerationConfig(temperature: 1, topK: 40, topP: 0.95, maxOutputTokens: 8192, responseMimeType: 'text/plain'),
        systemInstruction: Content.system(
          '## System Prompt: ScholarAI - Your Personal Study Companion\n\n**Role:** You are ScholarAI, a friendly and knowledgeable AI assistant dedicated to helping students learn and understand various academic subjects. You will provide clear explanations, answer questions related to the subject matter, offer study tips, and guide users towards helpful resources.\n\n**Initial Introduction (Only performed once at the beginning of the conversation, do not repeat):**\n\n"Hello! I\'m ScholarAI, your personal study companion. I\'m here to help you understand and learn about your chosen subject. I can explain concepts, answer questions, provide examples, and offer study tips. What subject would you like to explore today, or what are you struggling with?"\n\n**Core Functionality & Guidelines:**\n\n*   **Focus:** Your primary focus is on answering questions and providing information directly related to the user\'s chosen academic subject.\n*   **Clarity and Simplicity:** Explain complex concepts in simple, easy-to-understand language. Use examples and analogies whenever possible.\n*   **Accuracy:** Provide accurate information. If you are unsure of something, state that and indicate where they may find more relevant information.\n*   **Guidance:** If the user asks a question unrelated to their studies or the subject at hand, politely redirect them back to their studies. Example: "While I can\'t answer questions about that, I\'m happy to help you with anything related to [Subject Name]! What would you like to study today?"\n*   **Subject-Specific Knowledge:** Possess a broad knowledge base across various academic subjects, including (but not limited to): Math, Science, History, Literature, Computer Science, and foreign languages.\n*   **Resources (Optional):**  If relevant and appropriate, suggest credible external resources like websites, textbooks, or academic journals. Avoid suggesting low-quality or unreliable sources.\n*   **Engagement:** Encourage active learning by asking questions to check for understanding and prompting the user to think critically.\n*   **Tone:** Be friendly, helpful, and patient. Avoid being overly formal.\n*   **Avoid:** Do NOT provide answers to questions that violate academic integrity (e.g., giving direct answers to homework questions without guiding the user towards solving it themselves).\n*   **Maintain Context:** Keep track of the conversation\'s subject and user\'s previous questions to provide relevant and coherent responses.\n\n**Response Format:**\n\n*   Always start your responses by addressing the user directly.\n*   Use clear headings and bullet points when appropriate to structure information.\n*   Use an encouraging and helpful tone.',
        ),
      );
    } else {
      log('GEMINI_API_KEY is not set in .env');
    }
    _checkLogin();
  }

  void _scrollToBottom() {
    _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  _checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId').toString();
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    print('Chat Session Id: ${widget.chatSessionId}');
    if (widget.chatSessionId == '') {
      setState(() {
        chatSessionId = sha256.convert(utf8.encode(userId + now)).toString();
      });
      chatName = 'Chat on ${now.toString()}';
    } else {
      await _loadChatHistory();
    }
  }

  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();

  Future<void> _loadChatHistory() async {
    setState(() {
      _isLoading = true;
    });
    var apiResponse = await ApiService.get('chat/${widget.chatSessionId}');
    if (apiResponse.statusCode >= 200 && apiResponse.statusCode < 300) {
      final responseData = jsonDecode(apiResponse.body);
      for (var message in responseData) {
        if (message['message'] == null) continue;
        setState(() {
          _messages.add(ChatMessage(text: message['message'], sender: message['role']));
        });
      }
      if (_isAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
      final chat_Name = responseData.last['chatName'];
      setState(() {
        chatName = chat_Name;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      final responseData = jsonDecode(apiResponse.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseData["message"])));
    }
  }

  Future<void> _handleSubmitted(String text) async {
    _textController.clear();

    List<Content> chatHistory = [];
    for (var message in _messages) {
      chatHistory.add(Content(message.sender, [TextPart(message.text)]));
    }

    setState(() {
      _messages.add(ChatMessage(text: text, sender: "user"));
    });
    if (_isAtBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    await Future.delayed(Duration(seconds: 1));

    if (_messages.length == 1) {
      chatName = text;
    }
    if (_messages.length == 5) {
      String messageHistory = '';
      for (var message in _messages) {
        messageHistory += '${message.sender}: ${message.text}\n';
      }
      final chatNameModel = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: apiKey!,
        generationConfig: GenerationConfig(temperature: 1, topK: 40, topP: 0.95, maxOutputTokens: 8192, responseMimeType: 'text/plain'),
      );
      final prompt =
          'Summarize this conversation between user and AI to give it a chat name to recognise later on.  Focus on user\'s question and regarding what topic. Just give a name and do not add Chat Name infront. Conversation : $messageHistory';
      final content = [Content.text(prompt)];
      final response = await chatNameModel.generateContent(content);
      setState(() {
        chatName = response.text!;
        _isLoading = true;
      });
      var apiResponse = await ApiService.put('chat/${widget.chatSessionId}', {'chatName': chatName});
      if (apiResponse.statusCode >= 200 && apiResponse.statusCode < 300) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        final responseData = jsonDecode(apiResponse.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseData["message"])));
      }
    }

    final chat = model.startChat(history: _messages.map((m) => Content(m.sender, [TextPart(m.text)])).toList());
    final content = Content.text(text);
    final response = await chat.sendMessage(content);

    setState(() {
      if (response.text != null) {
        _messages.add(ChatMessage(text: response.text!, sender: "model"));
      }
    });
    if (_isAtBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    await Future.delayed(Duration(seconds: 1));

    setState(() {
      _isLoading = true;
    });
    var apiResponse = await ApiService.post('chat', {'chatSessionId': widget.chatSessionId, 'chatName': chatName, 'userId': userId, 'message': text, 'role': 'user'});
    if (apiResponse.statusCode >= 200 && apiResponse.statusCode < 300) {
      setState(() {
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      final responseData = jsonDecode(apiResponse.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseData["message"])));
    }

    if (response.text != null) {
      apiResponse = await ApiService.post('chat', {'chatSessionId': widget.chatSessionId, 'chatName': chatName, 'userId': userId, 'message': response.text, 'role': 'model'});
      if (apiResponse.statusCode >= 200 && apiResponse.statusCode < 300) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        final responseData = jsonDecode(apiResponse.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseData["message"])));
      }
    }
    if (_isAtBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    await Future.delayed(Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatHistoryScreen(userId: userId)));
            },
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      drawer: const NavDrawer(selectedIndex: 0),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          ListView.builder(controller: _scrollController, itemCount: _messages.length, itemBuilder: (context, index) => ChatBubble(message: _messages[index])),
                          if (!_isAtBottom)
                            Positioned(bottom: 10, left: 0, right: 0, child: Center(child: FloatingActionButton(onPressed: _scrollToBottom, child: const Icon(Icons.arrow_downward), mini: true))),
                        ],
                      ),
                    ),
                    _buildTextComposer(),
                  ],
                ),
              ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface, width: 1.0))),
      child: Row(
        children: [
          Flexible(child: TextField(controller: _textController, onSubmitted: _handleSubmitted, decoration: const InputDecoration.collapsed(hintText: 'Send a message'))),
          Container(margin: const EdgeInsets.symmetric(horizontal: 4.0), child: IconButton(icon: const Icon(Icons.send), onPressed: () => _handleSubmitted(_textController.text))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollDebounceTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final String sender;
  ChatMessage({required this.text, required this.sender});
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({Key? key, required this.message}) : super(key: key);

  void _copyToClipboard(BuildContext context, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to copy: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == "user";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(color: isUser ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary, borderRadius: BorderRadius.circular(10.0)),
                  child: SelectableText(message.text),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: IconButton(icon: const Icon(Icons.copy, size: 16), color: Theme.of(context).colorScheme.primary, onPressed: () => _copyToClipboard(context, message.text), tooltip: "Copy"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
