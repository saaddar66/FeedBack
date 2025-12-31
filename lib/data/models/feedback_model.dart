/// Data model representing a feedback entry
/// Contains all information about a single feedback submission
class FeedbackModel {
  final String? id;              // Unique identifier (Firebase key as string, null for new entries)
  final String? name;          // Optional name of the feedback submitter
  final String? email;        // Optional email of the feedback submitter
  final int rating;           // Rating from 1 to 5 (required)
  final String comments;      // Feedback comments (required)
  final DateTime createdAt;    // Timestamp when feedback was created

  FeedbackModel({
    this.id,
    this.name,
    this.email,
    required this.rating,
    required this.comments,
    required this.createdAt,
  });

  /// Converts the model to a Map for database storage
  /// Used when inserting or updating feedback in the database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'rating': rating,
      'comments': comments,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a FeedbackModel from a database Map
  /// Used when retrieving feedback from the database
  factory FeedbackModel.fromMap(Map<String, dynamic> map) {
    // Handle both string and int IDs for compatibility
    final idValue = map['id'];
    final String? id = idValue is String 
        ? idValue 
        : (idValue is int ? idValue.toString() : null);
    
    return FeedbackModel(
      id: id,
      name: map['name'] as String?,
      email: map['email'] as String?,
      rating: map['rating'] as int,
      comments: map['comments'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Creates a copy of this model with updated fields
  /// Useful for immutable updates
  FeedbackModel copyWith({
    String? id,
    String? name,
    String? email,
    int? rating,
    String? comments,
    DateTime? createdAt,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      rating: rating ?? this.rating,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

