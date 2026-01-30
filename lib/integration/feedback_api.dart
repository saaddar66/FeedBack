import '../data/database/database_helper.dart';
import '../data/repositories/feedback_repository.dart';

/// Integration API for programmatic feedback submission
/// 
/// This class provides a simple interface for other apps to submit feedback
/// programmatically without going through the UI.
/// 
/// Example usage:
/// ```dart
/// final api = FeedbackAPI();
/// await api.initialize();
/// await api.submitFeedback(
///   rating: 5,
///   comments: 'Great app!',
///   name: 'John Doe',
///   email: 'john@example.com',
/// );
/// ```
class FeedbackAPI {
  DatabaseHelper? _databaseHelper;
  FeedbackRepository? _repository;
  bool _initialized = false;

  /// Initialize the feedback API
  /// Must be called before submitting feedback or accessing data
  /// Sets up the database connection and repository
  /// Safe to call multiple times (idempotent)
  Future<void> initialize() async {
    if (_initialized) return;

    _databaseHelper = DatabaseHelper.instance;
    await _databaseHelper!.initDatabase();
    _repository = FeedbackRepository(_databaseHelper!);
    _initialized = true;
  }

  /// Submit feedback programmatically
  /// 
  /// [rating] - Required. Rating from 1 to 5
  /// [comments] - Required. Feedback comments
  /// [name] - Optional. Name of the person submitting feedback
  /// [email] - Optional. Email of the person submitting feedback
  /// [ownerId] - Optional. ID of the user (admin) who owns this feedback
  /// [surveyId] - Optional. ID of the survey this feedback is associated with
  /// 
  /// Returns the Firebase key (ID) of the inserted feedback record, or throws an exception on error
  Future<String> submitFeedback({
    required int rating,
    required String comments,
    String? name,
    String? email,
    String? ownerId,
    String? surveyId,
  }) async {
    if (!_initialized) {
      throw StateError(
        'FeedbackAPI not initialized. Call initialize() first.',
      );
    }

    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5');
    }

    if (comments.trim().isEmpty) {
      throw ArgumentError('Comments cannot be empty');
    }

    return await _repository!.submitFeedback(
      name: name,
      email: email,
      rating: rating,
      comments: comments,
      ownerId: ownerId,
      surveyId: surveyId,
    );
  }

  /// Get all feedback records
  /// 
  /// Optional filters:
  /// [minRating] - Minimum rating filter
  /// [maxRating] - Maximum rating filter
  /// [startDate] - Start date filter
  /// [endDate] - End date filter
  Future<List<Map<String, dynamic>>> getFeedback({
    int? minRating,
    int? maxRating,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_initialized) {
      throw StateError(
        'FeedbackAPI not initialized. Call initialize() first.',
      );
    }

    final feedback = await _repository!.getFeedback(
      minRating: minRating,
      maxRating: maxRating,
      startDate: startDate,
      endDate: endDate,
    );

    return feedback.map((f) => {
      'id': f.id,
      'name': f.name,
      'email': f.email,
      'rating': f.rating,
      'comments': f.comments,
      'createdAt': f.createdAt.toIso8601String(),
      'owner_id': f.ownerId,
      'survey_id': f.surveyId,
    }).toList();
  }

  /// Get feedback statistics
  /// 
  /// Returns a map with:
  /// - 'total': Total number of feedback records
  /// - 'averageRating': Average rating
  /// - 'ratingDistribution': Map of rating -> count
  Future<Map<String, dynamic>> getStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_initialized) {
      throw StateError(
        'FeedbackAPI not initialized. Call initialize() first.',
      );
    }

    final total = await _repository!.getFeedbackCount(
      startDate: startDate,
      endDate: endDate,
    );

    final averageRating = await _repository!.getAverageRating(
      startDate: startDate,
      endDate: endDate,
    );

    final ratingDistribution = await _repository!.getRatingDistribution(
      startDate: startDate,
      endDate: endDate,
    );

    return {
      'total': total,
      'averageRating': averageRating,
      'ratingDistribution': ratingDistribution,
    };
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _databaseHelper?.close();
    _initialized = false;
  }
}

