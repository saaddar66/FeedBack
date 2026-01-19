import '../../data/repositories/feedback_repository.dart';

/// Use case for submitting new feedback
/// Encapsulates the business logic for feedback submission
/// Part of clean architecture - separates business rules from UI and data layers
class SubmitFeedbackUseCase {
  final FeedbackRepository repository;

  SubmitFeedbackUseCase(this.repository);

  /// Executes the feedback submission use case
  /// Validates and submits feedback through the repository
  /// Returns the Firebase key (ID) of the newly created feedback entry
  Future<String> execute({
    String? name,
    String? email,
    required int rating,
    required String comments,
    String? ownerId,
    String? surveyId,
  }) async {
    return await repository.submitFeedback(
      name: name,
      email: email,
      rating: rating,
      comments: comments,
      ownerId: ownerId,
      surveyId: surveyId,
    );
  }
}
