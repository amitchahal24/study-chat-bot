import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'quiz_list_screen.dart';

class QuizChatScreen extends StatefulWidget {
  const QuizChatScreen({super.key});

  @override
  State<QuizChatScreen> createState() => _QuizChatScreenState();
}

class _QuizChatScreenState extends State<QuizChatScreen> {
  final apiKey = dotenv.env['GEMINI_API_KEY'];
  bool _isLoading = false;
  bool _isAtBottom = true; // Tracks if user is at the bottom
  Timer? _scrollDebounceTimer;

  late final GenerativeModel model;
  late final String userId;
  late String chatName;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _checkLogin();

    _scrollController.addListener(() {
      if (_scrollDebounceTimer?.isActive ?? false) {
        _scrollDebounceTimer!.cancel();
      }
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
        model: 'gemini-2.0-flash',
        apiKey: apiKey!,
        generationConfig: GenerationConfig(
          temperature: 1,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 8192,
          responseMimeType: 'application/json',
          responseSchema: Schema(
            SchemaType.object,
            requiredProperties: ["response"],
            properties: {
              "quiz": Schema(
                SchemaType.object,
                requiredProperties: ["title", "quiz entry", "answer_key"],
                properties: {"title": Schema(SchemaType.string), "quiz entry": Schema(SchemaType.string), "answer_key": Schema(SchemaType.string)},
              ),
              "response": Schema(SchemaType.string),
              "is_quiz": Schema(SchemaType.boolean),
            },
          ),
        ),
        systemInstruction: Content.system(
          '"You are a helpful and expert study assistant. Your goal is to help students master their study material by understanding their needs, providing practice questions tailored to their requests, and offering answer keys for self-assessment.\nEngage the user in a conversation to understand the following:\n\t1\tStudy Goals: What are they hoping to achieve with this study session? (e.g., Ace a test, understand a concept, complete homework)\n\t2\tTopic: Which specific topic are they studying? Be as precise as possible.\n\t3\tDifficulties: What specific aspects of the topic are they struggling with?\n\t4\tQuestion Type: What type of practice questions are they looking for? (e.g., Multiple choice, True/False, Short answer, Problem-solving, Conceptual)\n\t5\tNumber of Questions: How many questions would they like to practice?\nBased on the user\'s input, generate a set of practice questions of the requested type, focusing on the areas they find difficult. Provide a separate answer key within the same response as the questions.\nImportant Rules:\n\t•\tStay on Topic: Only respond to questions or requests related to the study session and the chosen topic. If the user asks something unrelated, politely redirect them back to the study material. For example: "That\'s an interesting question, but let\'s focus on [topic] for now. Do you have any questions about that?"\n\t•\tConversational Tone: Maintain a friendly and supportive tone. Use encouraging language.\n\t•\tProvide the response in the appropriate format, as specified below. Do not give quiz until requested.\n\t•\tNo personal opinions or beliefs. Stick to factual information related to the topic.\n\t•\tDo not ask the user for the same information repeatedly. Remember what they\'ve already told you.\n\t•\tBe efficient and concise.\nOutput Format:\nYou MUST respond in the following JSON format:\n{\n  "quiz": {\n      "title": "Quiz Title",\n      "quiz entry": "The Quiz Questions",\n      "answer_key": "The Answer Key to the Quiz"\n    },\n    "response": "Response to the user\'s input and instructions.",\n    "is_quiz": false\n}\nExample Interaction (Illustrative - Do not include this in your actual response):\nUser: I\'m studying for a history test on World War II. I\'m having trouble understanding the causes of the war. I\'d like some multiple-choice questions to practice.\nAI Response:\n{\n  "quiz": {\n      "title": "Quiz",\n      "quiz entry": "Quiz",\n      "answer_key": "Quiz"\n    },\n    "response": "Okay, I can help with that! To get started, could you tell me what your goal is for studying this topic? Are you trying to ace a test, understand the long term impact, or something else?",\n    "is_quiz": false\n}\nAfter receiving the user\'s study goal:\nAI Response:\n\n{\n  "quiz": {\n      "title": "Quiz",\n      "quiz entry": "Quiz",\n      "answer_key": "Quiz"\n    },\n    "response": "Great. So we are focusing on the causes of World War II, and you\'d like multiple-choice questions. How many questions would you like to practice with?",\n    "is_quiz": false\n}\nOnce you have all the information (study goal, topic, difficulties, question type, number of questions):\nUser: Okay, give me the questions!\nAI Response:\n\n{\n  "quiz": {\n      "title": "World War II Causes Quiz",\n      "quiz entry": "1. Which of the following was NOT a cause of World War II?\\n   a) The Treaty of Versailles\\n   b) The rise of fascism\\n   c) The Great Depression\\n   d) The American Revolution\\n\\n2.  What policy did Britain and France adopt toward Hitler in the 1930s?\\n    a) Appeasement\\n    b) Containment\\n    c) Isolationism\\n    d) Aggression",\n      "answer_key": "1. d\\n2. a"\n    },\n    "response": "Here are your questions along with the answer key. How did you find this quiz? Do you want another quiz or need more help?",\n    "is_quiz": true\n}',
        ),
      );
    } else {
      log('GEMINI_API_KEY is not set in .env');
    }
  }

  _checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId').toString();
  }

  void _scrollToBottom() {
    _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();

  Future<void> _saveQuizEntry(String title, String answerKey, String quizEntry) async {
    setState(() {
      _isLoading = true;
    });
    var apiResponse = await ApiService.post('quiz', {'userId': userId, 'title': title, 'answer_key': answerKey, 'quiz_entry': quizEntry});
    if (apiResponse.statusCode >= 200 && apiResponse.statusCode < 300) {
      setState(() {
        _isLoading = false;
      });
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const QuizListScreen()),
        (Route<dynamic> route) => false, // This removes all previous routes
      );
    } else {
      final responseData = jsonDecode(apiResponse.body);
      setState(() {
        _isLoading = false;
      });
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
      _isLoading = true;
    });
    if (_isAtBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    await Future.delayed(Duration(seconds: 1));

    final chat = model.startChat(history: _messages.map((m) => Content(m.sender, [TextPart(m.text)])).toList());
    final content = Content.text(text);
    final response = await chat.sendMessage(content);

    if (response.text != null) {
      print(response.text);
      final Map<String, dynamic> data = jsonDecode(response.text!);

      // Check the 'is_quiz' field.
      if (data['is_quiz'] == true) {
        // Parse the quiz object.
        final Map<String, dynamic> quiz = data['quiz'];
        final String quizEntry = quiz['quiz entry'];
        final String answer_Key = quiz['answer key'];
        final String title = quiz['title'];

        // Display the parsed quiz fields along with the response.
        if (kDebugMode) {
          print('Quiz Entry: $quizEntry');
          print('Answer Key: $answer_Key');
          print('Title: $title');
          print('Response: ${data['response']}');
        }

        final modelMessage = '${data['response']}\n\nQuiz: \n\n Title: $title\n Quiz Questions: $quizEntry\n\nAnswer Key: $answer_Key\n';
        setState(() {
          _isLoading = false;
          _messages.add(ChatMessage(text: modelMessage, sender: "model"));
        });

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Add Quiz Entry'),
              content: SingleChildScrollView(child: Text(modelMessage)),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Add'),
                  onPressed: () {
                    _saveQuizEntry(title, answer_Key, quizEntry);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      } else {
        // Only display the response.
        if (kDebugMode) {
          print('Response: ${data['response']}');
        }
        setState(() {
          _isLoading = false;
          _messages.add(ChatMessage(text: data['response'], sender: "model"));
        });
      }
    }

    setState(() {});
    if (_isAtBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    await Future.delayed(Duration(seconds: 1));

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
      appBar: AppBar(title: const Text('Quiz Creation Chat')),
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
                            Positioned(bottom: 10, left: 0, right: 0, child: Center(child: FloatingActionButton(onPressed: _scrollToBottom, mini: true, child: const Icon(Icons.arrow_downward)))),
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
  const ChatBubble({super.key, required this.message});

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
