import 'package:flutter/material.dart';

class ViewQuizScreen extends StatefulWidget {
  final String title;
  final String answerKey;
  final String quizEntry;
  final String date;

  const ViewQuizScreen({super.key, required this.title, required this.answerKey, required this.quizEntry, required this.date});

  @override
  State<ViewQuizScreen> createState() => _ViewQuizScreenState();
}

class _ViewQuizScreenState extends State<ViewQuizScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Align(alignment: Alignment.topLeft, child: Text(widget.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            Align(alignment: Alignment.topLeft, child: Text(widget.date.toString(), style: const TextStyle(fontSize: 16))),
            const SizedBox(height: 16),
            Align(alignment: Alignment.topLeft, child: Text(widget.answerKey, style: const TextStyle(fontSize: 18))),
            const SizedBox(height: 16),
            Expanded(child: SingleChildScrollView(child: Text(widget.quizEntry, style: const TextStyle(fontSize: 18)))),
          ],
        ),
      ),
    );
  }
}
