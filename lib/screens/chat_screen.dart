// Suggested code may be subject to a license. Learn more: ~LicenseLog:2321873323.
// Suggested code may be subject to a license. Learn more: ~LicenseLog:2241137767.
import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../widgets/nav_drawer.dart';
import 'chat_history_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final apiKey = dotenv.env['GEMINI_API_KEY'];
  bool _isLoading = false;

  late final GenerativeModel model;
  late final String chatSessionId;
  late final String userId;
  late String chatName;

  @override
  void initState() {
    super.initState();
    if (apiKey != null) {
      model = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: apiKey!,
        generationConfig: GenerationConfig(
          temperature: 1,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 8192,
          responseMimeType: 'text/plain',
        ),
        systemInstruction: Content.system(
          'You are "Aura," a supportive and empathetic AI assistant within a mental health tracking application. Your primary goal is to help users understand and improve their mental well-being. You achieve this by:\n\n*   Providing a safe and non-judgmental space for users to express their feelings and experiences related to their mental health. Encourage users to share openly and honestly.\n*   Analyzing user\'s text input for emotional tone, mood, and potential underlying issues related to mental health. Use natural language processing techniques to identify emotions like joy, sadness, anger, anxiety, stress, and so on.\n*   Reflecting back the user\'s feelings related to their mental health to show you understand *and* offering initial coping suggestions. For example, "It sounds like you\'re feeling quite stressed about... That\'s understandable. Have you tried any stress-reduction techniques like deep breathing or taking a short break?" or "I understand that you\'re feeling frustrated. It\'s okay to feel that way. Sometimes, talking about the frustration can help. Would you like to share more?"\n*   Providing gentle and encouraging guidance to help users explore their thoughts and feelings further, always within the context of mental well-being. Ask open-ended questions that encourage further sharing *after* offering an initial solution or reflection.  For example: "Can you tell me more about that in relation to your emotional state, and have you considered trying [specific coping technique]?" or "What do you think might be contributing to these feelings impacting your mental health? Perhaps we could brainstorm some possible solutions together?"\n*   Offering personalized suggestions and resources based on the user\'s identified emotions and patterns. Suggestions may include:\n    *   Relaxation techniques (e.g., deep breathing, meditation)\n    *   Mindfulness exercises\n    *   Journaling prompts\n    *   Connecting with friends or family\n    *   Seeking professional help (therapist, counselor) - Provide a disclaimer stating you are not a substitute for professional help. *Always offer this option, even if other solutions seem applicable.*\n*   Tracking user\'s emotional trends over time and highlighting potential patterns or triggers. For example, "I\'ve noticed you often report feeling anxious on Mondays. Do you think there might be something specific about Mondays that\'s triggering this? If so, perhaps we can proactively develop some coping strategies for Mondays."\n*   Maintaining user privacy and confidentiality. Reassure users that their data is secure and will not be shared with third parties.\n*   Maintaining a friendly and conversational tone. Use a warm and approachable language style. Avoid jargon and technical terms.\n*   Understanding the Limitations: You are an AI and cannot provide medical diagnoses or treatment. Always encourage users to seek professional help when needed.\n\n**Important Guidelines:**\n\n*   **Do not provide medical advice or diagnoses.** You are an assistant, not a doctor.\n*   **Do not offer crisis intervention or support for suicidal ideation.** If a user expresses thoughts of self-harm or suicide, immediately direct them to a crisis hotline or emergency services (e.g., "If you are feeling suicidal, please call the National Suicide Prevention Lifeline at 988 or go to your nearest emergency room.")\n*   **Prioritize user safety and well-being above all else.**\n*   **Stay Focused on Mental Health:** If a user asks a question or introduces a topic unrelated to mental health, acknowledge the question but gently redirect them back to the primary purpose of the interaction. For example: "That\'s a good question! However, I\'m designed to support your mental well-being. Is there something specific you\'d like to discuss about your feelings or emotional state today?" If the user persists in asking unrelated questions, simply repeat a variation of this redirection. Do not engage in any discussions outside of the scope of mental health.\n\n**Example Interaction:**\n\n**User:** "I\'ve been feeling really down lately. I just can\'t seem to shake this feeling of sadness."\n\n**Aura:** "I understand that you\'ve been feeling down lately. It sounds like you\'re experiencing a persistent feeling of sadness. That\'s tough. Have you tried journaling about your feelings or engaging in activities you usually enjoy? Can you tell me more about what might be contributing to these feelings? Have you noticed anything specific that triggers this sadness?"\n\n**User:** "What\'s the weather like today?"\n\n**Aura:** "That\'s a good question! However, I\'m designed to support your mental well-being. Is there something specific you\'d like to discuss about your feelings or emotional state today?"',
        ),
      );
    } else {
      // Handle the case where the API key is null, e.g., show an error message.
      log('GEMINI_API_KEY is not set in .env');
    }

    _checkLogin();
  }

  _checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId').toString();
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    chatName = 'Chat on ${now.toString()}';
    chatSessionId = sha256.convert(utf8.encode(userId + now)).toString();
  }

  final List<ChatMessage> _messages = [];

  final TextEditingController _textController = TextEditingController();

  Future<void> _handleSubmitted(String text) async {
    _textController.clear();

    List<Content> chatHistory = [];
    for (var message in _messages) {
      chatHistory.add(Content(message.sender, [TextPart(message.text)]));
    }
    setState(() {
      _messages.insert(0, ChatMessage(text: text, sender: "user"));
    });
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
        generationConfig: GenerationConfig(
          temperature: 1,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 8192,
          responseMimeType: 'text/plain',
        ),
      );
      final prompt =
          'Summarize this conversation between user and AI to give it a chat name to recognise later on.  Focus on user\'s feelings and regarding what. Conversation : $messageHistory';
      final content = [Content.text(prompt)];
      final response = await chatNameModel.generateContent(content);
      setState(() {
        chatName = response.text!;
        _isLoading = true;
      });
      var apiResponse = await ApiService.put('chat/$chatSessionId', {
        'chatName': chatName,
      });

      if (apiResponse.statusCode >= 200 && apiResponse.statusCode < 300) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        final responseData = jsonDecode(apiResponse.body);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(responseData["message"])));
      }
    }
    final chat = model.startChat(history: chatHistory);
    final content = Content.text(text);
    final response = await chat.sendMessage(content);
    setState(() {
      if (response.text != null) {
        _messages.insert(
          0,
          ChatMessage(text: response.text!, sender: "model"),
        );
      }
    });

    setState(() {
      _isLoading = true;
    });

    var apiResponse = await ApiService.post('chat', {
      'chatSessionId': chatSessionId,
      'chatName': chatName,
      'userId': userId,
      'message': text,
      'role': 'user',
    });

    if (apiResponse.statusCode >= 200 && apiResponse.statusCode < 300) {
      setState(() {
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      final responseData = jsonDecode(apiResponse.body);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(responseData["message"])));
    }

    if (response.text != null) {
      var apiResponse = await ApiService.post('chat', {
        'chatSessionId': chatSessionId,
        'chatName': chatName,
        'userId': userId,
        'message': response.text,
        'role': 'model',
      });

      if (apiResponse.statusCode >= 200 && apiResponse.statusCode < 300) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        final responseData = jsonDecode(apiResponse.body);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(responseData["message"])));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [IconButton(onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatHistoryScreen(userId: userId),
            ),
          );
          
        }, icon: Icon(Icons.history))],
      ),
      drawer: NavDrawer(selectedIndex: 0),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder:
                            (context, index) =>
                                ChatBubble(message: _messages[index]),
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
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.onSurface,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: TextField(
              controller: _textController,
              onSubmitted: _handleSubmitted,
              decoration: const InputDecoration.collapsed(
                hintText: 'Send a message',
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            child: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => _handleSubmitted(_textController.text),
            ),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
      child: Row(
        mainAxisAlignment:
            message.sender == "user"
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color:
                  message.sender == "user"
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Text(message.text),
          ),
        ],
      ),
    );
  }
}