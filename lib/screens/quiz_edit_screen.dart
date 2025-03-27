import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myapp/screens/quiz_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class QuizEditScreen extends StatefulWidget {
  final String quizId;
  final String title;
  final String answerKey;
  final String quizEntry;

  const QuizEditScreen({super.key, required this.quizId, required this.title, required this.answerKey, required this.quizEntry});

  @override
  State<QuizEditScreen> createState() => _QuizEditScreenState();
}

class _QuizEditScreenState extends State<QuizEditScreen> {
  late String title;
  late String answerKey;
  late String quizEntry;
  late String date;

  final TextEditingController _bodyTextEditingController = TextEditingController();
  final TextEditingController _titleTextEditingController = TextEditingController();
  final TextEditingController _answersTextEditingController = TextEditingController();
  late final String userId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    title = widget.title;
    answerKey = widget.answerKey;
    quizEntry = widget.quizEntry;

    _bodyTextEditingController.text = quizEntry;
    _titleTextEditingController.text = title;
    _answersTextEditingController.text = answerKey;

    _checkLogin();
  }

  _checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId').toString();
  }

  @override
  void dispose() {
    _bodyTextEditingController.dispose();
    _titleTextEditingController.dispose();
    _answersTextEditingController.dispose();
    super.dispose();
  }

  Future<void> _saveQuizEntry() async {
    final title = _titleTextEditingController.text;
    final feeling = _answersTextEditingController.text;
    final body = _bodyTextEditingController.text;
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title and body')));
      return;
    }
    setState(() {
      _isLoading = true;
    });
    var apiResponse = await ApiService.put('quiz/${widget.quizId}', {'userId': userId, 'title': title, 'answer_key': feeling, 'quiz_entry': body});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              _saveQuizEntry();
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleTextEditingController,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
                    ),
                    TextField(controller: _answersTextEditingController, decoration: const InputDecoration(hintText: 'Answer Key', border: InputBorder.none)),
                    Expanded(
                      child: TextField(
                        controller: _bodyTextEditingController,
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration(hintText: 'Start writing your quiz questions...', border: InputBorder.none),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
