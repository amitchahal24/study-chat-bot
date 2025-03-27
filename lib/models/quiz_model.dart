class QuizModel {
  final String quizId;
  final String title;
  final String answerKey;
  final String quizEntry;
  final String createdAt;

  QuizModel({required this.quizId, required this.title, required this.answerKey, required this.quizEntry, required this.createdAt});

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(quizId: json['_id'], title: json['title'], answerKey: json['answer_key'], quizEntry: json['quiz_entry'], createdAt: json['datetime']);
  }
}
