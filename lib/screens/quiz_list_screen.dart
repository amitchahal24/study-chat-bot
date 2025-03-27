import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/screens/quiz_edit_screen.dart';
import 'package:myapp/screens/view_quiz_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quiz_model.dart';
import '../services/api_service.dart';
import '../widgets/nav_drawer.dart';
import 'quiz_chat_screen.dart';
import 'quiz_entry_screen.dart';

class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  final List<QuizModel> _quizEntries = [];
  late final String userId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  _checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId').toString();
    await _loadQuizzesList();
  }

  Future<void> _loadQuizzesList() async {
    setState(() {
      _isLoading = true;
    });
    var apiResponse = await ApiService.get('quizzes/$userId');
    if (apiResponse.statusCode >= 200 && apiResponse.statusCode < 300) {
      final responseData = jsonDecode(apiResponse.body);
      setState(() {
        _quizEntries.clear();
        for (var quiz in responseData) {
          if (quiz['message'] == null) {
            _quizEntries.add(QuizModel.fromJson(quiz));
          }
        }
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

  Future<void> _deleteQuiz(String quizId) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await ApiService.delete('quiz/$quizId');
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Quiz deleted successfully: $quizId');
        }
        setState(() {
          _isLoading = false;
        });
        _loadQuizzesList();
      } else {
        throw Exception('Failed to delete quiz');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting quiz: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete quiz: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => QuizChatScreen()));
            },
          ),
        ],

        title: const Text('Quiz Entries'),
      ),
      drawer: const NavDrawer(selectedIndex: 2),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                itemCount: _quizEntries.length,
                itemBuilder: (context, index) {
                  final quiz = _quizEntries[index];
                  DateTime dateTime = DateTime.parse(quiz.createdAt).toLocal();
                  var format = DateFormat('dd MMM, yyyy hh:MM a');
                  String formattedDate = format.format(dateTime.toUtc().add(const Duration(hours: -8)));
                  return ListTile(
                    title: Text(quiz.title),
                    subtitle: Text(formattedDate),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => ViewQuizScreen(title: quiz.title, answerKey: quiz.answerKey, quizEntry: quiz.quizEntry, date: formattedDate)));
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            // Handle edit action
                            Navigator.of(
                              context,
                            ).push(MaterialPageRoute(builder: (context) => QuizEditScreen(quizId: quiz.quizId, title: quiz.title, answerKey: quiz.answerKey, quizEntry: quiz.quizEntry)));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            _deleteQuiz(quiz.quizId);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const QuizEntryScreen()));
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
