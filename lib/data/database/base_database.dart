import '../models/feedback_model.dart';
import '../models/user_model.dart';
import '../models/survey_models.dart';

abstract class BaseDatabase {
  Future<void> init();

  // User Profile
  Future<void> createUserProfile(UserModel user);
  Future<UserModel?> getUserProfile(String uid);
  Future<void> updateUserProfile(UserModel user);

  // Feedback
  Future<String> insertFeedback(FeedbackModel feedback);
  Future<List<FeedbackModel>> getAllFeedback({
    int? minRating,
    int? maxRating,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    String? userId,
  });
  Future<int> getFeedbackCount({
    int? minRating,
    int? maxRating,
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  });
  Future<Map<int, int>> getRatingDistribution({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  });
  Future<List<Map<String, dynamic>>> getTrendsData({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  });
  Future<double> getAverageRating({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  });
  Future<void> deleteFeedback(String id);

  // Surveys
  Future<List<SurveyForm>> getAllSurveys({String? creatorId});
  Future<void> saveSurvey(SurveyForm survey);
  Future<void> deleteSurvey(String surveyId);
  Future<void> activateSurvey(String surveyId);
  Future<SurveyForm?> getActiveSurvey({String? creatorId});

  // Survey Responses
  Future<void> submitSurveyResponse(Map<String, dynamic> answers, {String? ownerId});
  Future<List<Map<String, dynamic>>> getAllSurveyResponses({String? ownerId});
  Future<void> deleteSurveyResponse(String id);
}
