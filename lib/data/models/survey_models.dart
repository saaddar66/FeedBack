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
    // Safely convert options - handle both List and Map formats
    List<String> parsedOptions = [];
    if (map['options'] != null) {
      final optionsData = map['options'];
      if (optionsData is List) {
        parsedOptions = List<String>.from(optionsData);
      } else if (optionsData is Map) {
        // If options come as a Map, extract the values
        parsedOptions = optionsData.values.map((v) => v.toString()).toList();
      }
    }

    return QuestionModel(
      id: map['id']?.toString() ?? '', // Safely convert to string even if it's a number
      title: map['title']?.toString() ?? '',
      type: QuestionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => QuestionType.text,
      ),
      options: parsedOptions,
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
  final String? creatorId;

  SurveyForm({
    required this.id,
    required this.title,
    this.isActive = false,
    List<QuestionModel>? questions,
    DateTime? createdAt,
    this.creatorId,
  }) : questions = questions ?? [],
       createdAt = createdAt ?? DateTime.now();

  SurveyForm copyWith({
    String? title,
    bool? isActive,
    List<QuestionModel>? questions,
    String? creatorId,
  }) {
    return SurveyForm(
      id: id,
      title: title ?? this.title,
      isActive: isActive ?? this.isActive,
      questions: questions ?? this.questions,
      createdAt: createdAt,
      creatorId: creatorId ?? this.creatorId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isActive': isActive,
      'questions': questions.map((q) => q.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'creatorId': creatorId,
    };
  }

  factory SurveyForm.fromMap(Map<String, dynamic> map) {
    List<QuestionModel> parsedQuestions = [];

    if (map['questions'] != null) {
      final questionsData = map['questions'];
      
      // Skip if questions is a String (corrupted data)
      if (questionsData is String) {
        print('Warning: questions field is a String, skipping: $questionsData');
      } else if (questionsData is List) {
        // Handle as List (standard JSON array)
        for (var q in questionsData) {
          if (q is Map) {
            try {
              parsedQuestions.add(QuestionModel.fromMap(Map<String, dynamic>.from(q)));
            } catch (e) {
              print('Skipping invalid question in list: $e');
            }
          }
        }
      } else if (questionsData is Map) {
        // Handle as Map (Firebase object structure {id: {data}})
        questionsData.forEach((key, value) {
          if (value is Map) {
            try {
              final questionMap = Map<String, dynamic>.from(value);
              // Ensure ID is set (use key if ID is missing in value)
              final existingId = questionMap['id'];
              if (existingId == null || existingId.toString().isEmpty) {
                questionMap['id'] = key.toString();
              }
              parsedQuestions.add(QuestionModel.fromMap(questionMap));
            } catch (e) {
              print('Skipping invalid question ($key): $e');
            }
          }
        });
      }
    }

    return SurveyForm(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled Survey',
      isActive: map['isActive'] == true,
      questions: parsedQuestions,
      createdAt: _parseDateTime(map['createdAt']),
      creatorId: map['creatorId']?.toString(),
    );
  }

  /// Safely parses a DateTime from various formats
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return DateTime.now();
    }
  }
}
