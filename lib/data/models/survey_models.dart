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
  double? price;                // Price for the dish (if used as a menu item)
  String? description;          // Additional details/description for the dish
  bool isAvailable;             // Whether the dish is available on the menu

  QuestionModel({
    required this.id,
    required this.title,
    required this.type,
    List<String>? options,
    this.price,
    this.description,
    this.isAvailable = true,
  }) : options = options ?? [];

  /// Creates a copy of the question with updated values
  QuestionModel copyWith({
    String? title,
    QuestionType? type,
    List<String>? options,
    double? price,
    String? description,
    bool? isAvailable,
  }) {
    return QuestionModel(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      options: options ?? this.options,
      price: price ?? this.price,
      description: description ?? this.description,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  /// Converts the question object to a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.name, // Save enum as string
      'options': options, // Save list directly
      'price': price,
      'description': description,
      'isAvailable': isAvailable,
    };
  }

  /// Creates a QuestionModel from a database Map
  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    // Safely convert options - handle both List and Map formats
    List<String> parsedOptions = [];
    if (map['options'] != null) {
      final optionsData = map['options'];
      if (optionsData is List) {
        parsedOptions = optionsData.map((e) => e.toString()).toList();
      } else if (optionsData is Map) {
        // If options come as a Map, extract the values
        parsedOptions = optionsData.values.map((v) => v.toString()).toList();
      }
    }

    // Safely parse enum
    QuestionType questionType = QuestionType.text; // Default
    if (map['type'] != null) {
        try {
           questionType = QuestionType.values.firstWhere(
            (e) => e.name == map['type'].toString(),
            orElse: () => QuestionType.text,
          );
        } catch (_) {}
    }

    return QuestionModel(
      id: map['id']?.toString() ?? '', // Safely convert to string even if it's a number
      title: map['title']?.toString() ?? '',
      type: questionType,
      options: parsedOptions,
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : null,
      description: map['description']?.toString(), // Explicitly cast/convert
      isAvailable: map['isAvailable'] == true || map['isAvailable'] == 'true', // Handle string bools too
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
  final double? taxRate;           // Tax percentage for this menu section
  final double? serviceChargeRate; // Service charge percentage

  SurveyForm({
    required this.id,
    required this.title,
    this.isActive = false,
    List<QuestionModel>? questions,
    DateTime? createdAt,
    this.creatorId,
    this.taxRate,
    this.serviceChargeRate,
  }) : questions = questions ?? [],
       createdAt = createdAt ?? DateTime.now();

  SurveyForm copyWith({
    String? title,
    bool? isActive,
    List<QuestionModel>? questions,
    String? creatorId,
    double? taxRate,
    double? serviceChargeRate,
  }) {
    return SurveyForm(
      id: id,
      title: title ?? this.title,
      isActive: isActive ?? this.isActive,
      questions: questions ?? this.questions,
      createdAt: createdAt,
      creatorId: creatorId ?? this.creatorId,
      taxRate: taxRate ?? this.taxRate,
      serviceChargeRate: serviceChargeRate ?? this.serviceChargeRate,
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
      'taxRate': taxRate,
      'serviceChargeRate': serviceChargeRate,
    };
  }

  factory SurveyForm.fromMap(Map<String, dynamic> map) {
    List<QuestionModel> parsedQuestions = [];

    if (map['questions'] != null) {
      final questionsData = map['questions'];
      
      try {
        if (questionsData is List) {
          for (var q in questionsData) {
            if (q != null && q is Map) {
              try {
                parsedQuestions.add(QuestionModel.fromMap(Map<String, dynamic>.from(q)));
              } catch (e) {
                print('Error parsing question from list: $e');
              }
            }
          }
        } else if (questionsData is Map) {
          questionsData.forEach((key, value) {
            if (value != null && value is Map) {
              try {
                final questionMap = Map<String, dynamic>.from(value);
                // Ensure ID is present
                if (questionMap['id'] == null || questionMap['id'].toString().isEmpty) {
                  questionMap['id'] = key.toString();
                }
                parsedQuestions.add(QuestionModel.fromMap(questionMap));
              } catch (e) {
                 print('Error parsing question from map ($key): $e');
              }
            }
          });
        }
      } catch (e) {
        print('Error processing questions structure: $e');
      }
    }

    return SurveyForm(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled Survey',
      isActive: map['isActive'] == true,
      questions: parsedQuestions,
      createdAt: _parseDateTime(map['createdAt']),
      creatorId: map['creatorId']?.toString(),
      taxRate: (map['taxRate'] is num) ? (map['taxRate'] as num).toDouble() : null,
      serviceChargeRate: (map['serviceChargeRate'] is num) ? (map['serviceChargeRate'] as num).toDouble() : null,
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
