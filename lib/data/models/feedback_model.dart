/// Data model representing a feedback entry
/// Contains all information about a single feedback submission
class FeedbackModel {
  final String? id;              // Unique identifier (Firebase key as string, null for new entries)
  final String? name;          // Optional name of the feedback submitter
  final String? email;        // Optional email of the feedback submitter
  final int rating;           // Rating from 1 to 5 (required)
  final String comments;      // Feedback comments (required)
  final DateTime createdAt;    // Timestamp when feedback was created

  final String? ownerId;       // ID of the user (admin) who owns this feedback
  final String? surveyId;      // ID of the survey this feedback is associated with (optional)

  FeedbackModel({
    this.id,
    this.name,
    this.email,
    required this.rating,
    required this.comments,
    required this.createdAt,
    this.ownerId,
    this.surveyId,
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
      'owner_id': ownerId,
      'survey_id': surveyId,
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
    
    // STRICTLY prioritize snake_case 'owner_id' as per database requirement
    // Only fall back to camelCase if absolutely necessary for legacy instances
    final ownerIdValue = map['owner_id'] ?? map['ownerId'];
    final String? ownerId = ownerIdValue is String ? ownerIdValue : null;
    
    // Handle both snake_case (survey_id) and camelCase (surveyId)
    final surveyIdValue = map['survey_id'] ?? map['surveyId'];
    final String? surveyId = surveyIdValue is String ? surveyIdValue : null;
    
    return FeedbackModel(
      id: id,
      name: map['name'] as String?,
      email: map['email'] as String?,
      rating: map['rating'] as int,
      comments: map['comments'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      ownerId: ownerId,
      surveyId: surveyId,
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
    String? ownerId,
    String? surveyId,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      rating: rating ?? this.rating,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      ownerId: ownerId ?? this.ownerId,
      surveyId: surveyId ?? this.surveyId,
    );
  }
}

