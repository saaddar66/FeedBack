import 'package:flutter/foundation.dart';
import '../../domain/use_cases/submit_feedback_use_case.dart';

/// Public submission provider for public web users
/// Handles submission only (no data fetching) to ensure security
/// Uses CQRS-lite pattern - write-only operations for public access
class PublicSubmissionProvider with ChangeNotifier {
  final SubmitFeedbackUseCase _submitFeedbackUseCase;

  PublicSubmissionProvider(this._submitFeedbackUseCase);

  // State variables
  bool _isSubmitting = false;
  String? _errorMessage;

  // Getters
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  /// Submits public feedback
  /// Returns true if successful, false otherwise
  Future<bool> submitPublicFeedback({
    String? name,
    String? email,
    required int rating,
    required String comments,
    String? ownerId,
    String? surveyId,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _submitFeedbackUseCase.execute(
        name: name,
        email: email,
        rating: rating,
        comments: comments,
        ownerId: ownerId,
        surveyId: surveyId,
      );
      
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to submit feedback. Please try again.';
      _isSubmitting = false;
      notifyListeners();
      debugPrint('Error submitting public feedback: $e');
      return false;
    }
  }

  /// Clears any error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

