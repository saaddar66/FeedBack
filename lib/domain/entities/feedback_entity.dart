/// Domain entity representing a feedback entry
/// This is the business logic representation of feedback data
/// Separates domain logic from data layer implementation
class FeedbackEntity {
  final int? id;              // Unique identifier
  final String? name;        // Optional name of feedback submitter
  final String? email;       // Optional email of feedback submitter
  final int rating;          // Rating from 1 to 5 (required)
  final String comments;     // Feedback comments (required)
  final DateTime createdAt;  // Timestamp when feedback was created

  FeedbackEntity({
    this.id,
    this.name,
    this.email,
    required this.rating,
    required this.comments,
    required this.createdAt,
  });
}
