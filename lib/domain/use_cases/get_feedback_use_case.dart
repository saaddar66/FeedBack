import '../../data/repositories/feedback_repository.dart';
import '../../data/models/feedback_model.dart';

/// Use case for retrieving feedback entries
/// Encapsulates the business logic for fetching feedback
/// Part of clean architecture - separates business rules from UI and data layers
class GetFeedbackUseCase {
  final FeedbackRepository repository;

  GetFeedbackUseCase(this.repository);

  /// Executes the get feedback use case
  /// Retrieves feedback entries with optional filtering
  /// Supports filtering by rating range and date range
  /// Returns a list of feedback models matching the criteria
  Future<List<FeedbackModel>> execute({
    int? minRating,
    int? maxRating,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await repository.getFeedback(
      minRating: minRating,
      maxRating: maxRating,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
