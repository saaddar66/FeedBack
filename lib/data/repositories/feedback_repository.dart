import '../database/database_helper.dart';
import '../models/feedback_model.dart';

/// Repository class that acts as an abstraction layer between business logic and data layer
/// Provides methods for all feedback-related data operations
class FeedbackRepository {
  final DatabaseHelper _databaseHelper;

  FeedbackRepository(this._databaseHelper);

  /// Submits a new feedback entry to the database
  /// Creates a FeedbackModel with current timestamp and inserts it
  /// Returns the ID (Firebase key) of the newly created feedback entry
  Future<String> submitFeedback({
    String? name,
    String? email,
    required int rating,
    required String comments,
  }) async {
    final feedback = FeedbackModel(
      name: name?.isEmpty == true ? null : name,
      email: email?.isEmpty == true ? null : email,
      rating: rating,
      comments: comments,
      createdAt: DateTime.now(),
    );

    return await _databaseHelper.insertFeedback(feedback);
  }

  /// Retrieves all feedback entries with optional filtering
  /// Supports filtering by rating range and date range
  /// [limit] parameter limits the number of entries fetched (default: 100)
  Future<List<FeedbackModel>> getFeedback({
    int? minRating,
    int? maxRating,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    return await _databaseHelper.getAllFeedback(
      minRating: minRating,
      maxRating: maxRating,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// Gets the total count of feedback entries matching the filters
  Future<int> getFeedbackCount({
    int? minRating,
    int? maxRating,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _databaseHelper.getFeedbackCount(
      minRating: minRating,
      maxRating: maxRating,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Gets the distribution of ratings (count per rating 1-5)
  /// Returns a map where key is rating and value is count of feedbacks
  Future<Map<int, int>> getRatingDistribution({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _databaseHelper.getRatingDistribution(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Gets trends data grouped by date for chart visualization
  /// Returns daily feedback counts and average ratings
  Future<List<Map<String, dynamic>>> getTrendsData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _databaseHelper.getTrendsData(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Calculates the average rating across all feedback entries
  /// Can be filtered by date range
  Future<double> getAverageRating({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _databaseHelper.getAverageRating(
      startDate: startDate,
      endDate: endDate,
    );
  }
}

