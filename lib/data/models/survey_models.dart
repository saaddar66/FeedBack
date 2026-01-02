/// Unified enum representing the type of question
/// Combines question format and expected answer type
enum QuestionType {
  text,           // Open-ended text response
  rating,         // Star rating (1-5)
  singleChoice,   // Radio buttons - pick one option
  multipleChoice, // Checkboxes - pick multiple options
}

/// Model class representing a survey question
class QuestionModel {
  final String id;              // Unique identifier
  String title;                 // Question text
  QuestionType type;            // Type of question
  List<String> options;         // Available choices (for single/multiple choice)

  QuestionModel({
    required this.id,
    required this.title,
    required this.type,
    List<String>? options,
  }) : options = options ?? [];

  /// Creates a copy of the question with updated values
  QuestionModel copyWith({
    String? title,
    QuestionType? type,
    List<String>? options,
  }) {
    return QuestionModel(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      options: options ?? this.options,
    );
  }

  /// Converts the question object to a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.name, // Save enum as string
      'options': options, // Save list directly
    };
  }

  /// Creates a QuestionModel from a database Map
  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    return QuestionModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      type: QuestionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => QuestionType.text,
      ),
      options: map['options'] != null 
          ? List<String>.from(map['options'] as List)
          : [],
    );
  }
}

/// Model class representing a complete survey form
class SurveyForm {
  final String id;
  String title;
  bool isActive;
  List<QuestionModel> questions;
  final DateTime createdAt;

  SurveyForm({
    required this.id,
    required this.title,
    this.isActive = false,
    List<QuestionModel>? questions,
    DateTime? createdAt,
  }) : questions = questions ?? [],
       createdAt = createdAt ?? DateTime.now();

  SurveyForm copyWith({
    String? title,
    bool? isActive,
    List<QuestionModel>? questions,
  }) {
    return SurveyForm(
      id: id,
      title: title ?? this.title,
      isActive: isActive ?? this.isActive,
      questions: questions ?? this.questions,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isActive': isActive,
      'questions': questions.map((q) => q.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SurveyForm.fromMap(Map<String, dynamic> map) {
    return SurveyForm(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Untitled Survey',
      isActive: map['isActive'] ?? false,
      questions: map['questions'] != null
          ? (map['questions'] as List)
              .map((q) => QuestionModel.fromMap(Map<String, dynamic>.from(q)))
              .toList()
          : [],
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
    );
  }
}
