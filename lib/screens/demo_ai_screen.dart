import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

class DemoAIScreen extends StatefulWidget {
  const DemoAIScreen({super.key});

  @override
  State<DemoAIScreen> createState() => _DemoAIScreenState();
}

class _DemoAIScreenState extends State<DemoAIScreen> {
  String _text = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Gemini.instance
              .promptStream(
                parts: [Part.text('Write a story about a magic backpack')],
              )
              .listen((value) {
            if(value != null && value.output != null){
              setState(() {
                  _text = _text + value.output!;
                });
            }
              });
        },
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
          child: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
        child: Text(_text),
          ),
        ),
      )),
    );
  }
}
