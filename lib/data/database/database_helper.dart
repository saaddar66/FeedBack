import '../models/feedback_model.dart';
import '../models/user_model.dart';
import '../models/survey_models.dart';
import 'base_database.dart';

/// Database helper class that delegates to a BaseDatabase implementation
/// Implements singleton pattern but requires initialization through configure()
class DatabaseHelper implements BaseDatabase {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  
  late BaseDatabase _db;
  bool _isInitialized = false;

  // Private constructor for singleton pattern
  DatabaseHelper._init();

  /// Configures the database implementation to use
  void configure(BaseDatabase db) {
    _db = db;
  }

  /// Initializes the configured database
  @override
  Future<void> init() async {
    if (!_isInitialized) {
      await _db.init();
      _isInitialized = true;
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call init() first.');
    }
  }

  void _checkConfig() {
     _ensureInitialized();
  }

  // Delegate all methods to _db

  @override
  Future<void> createUserProfile(UserModel user) {
    _checkConfig();
    return _db.createUserProfile(user);
  }
  
  @override
  Future<UserModel?> getUserProfile(String uid) {
    _checkConfig();
    return _db.getUserProfile(uid);
  }

  @override
  Future<void> updateUserProfile(UserModel user) {
    _checkConfig();
    return _db.updateUserProfile(user);
  }

  @override
  Future<String> insertFeedback(FeedbackModel feedback) {
    _checkConfig();
    return _db.insertFeedback(feedback);
  }

  @override
  Future<List<FeedbackModel>> getAllFeedback({
    int? minRating,
    int? maxRating,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    String? userId,
  }) {
    _checkConfig();
    return _db.getAllFeedback(
      minRating: minRating,
      maxRating: maxRating,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      userId: userId,
    );
  }

  @override
  Future<int> getFeedbackCount({
    int? minRating,
    int? maxRating,
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) {
    _checkConfig();
    return _db.getFeedbackCount(
      minRating: minRating,
      maxRating: maxRating,
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );
  }

  @override
  Future<Map<int, int>> getRatingDistribution({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) {
    _checkConfig();
    return _db.getRatingDistribution(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getTrendsData({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) {
    _checkConfig();
    return _db.getTrendsData(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );
  }

  @override
  Future<double> getAverageRating({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) {
    _checkConfig();
    return _db.getAverageRating(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );
  }

  @override
  Future<void> deleteFeedback(String id) {
    _checkConfig();
    return _db.deleteFeedback(id);
  }

  @override
  Future<List<SurveyForm>> getAllSurveys({String? creatorId}) {
    _checkConfig();
    return _db.getAllSurveys(creatorId: creatorId);
  }

  @override
  Future<void> saveSurvey(SurveyForm survey) {
    _checkConfig();
    return _db.saveSurvey(survey);
  }

  @override
  Future<void> deleteSurvey(String surveyId) {
    _checkConfig();
    return _db.deleteSurvey(surveyId);
  }

  @override
  Future<void> activateSurvey(String surveyId) {
    _checkConfig();
    return _db.activateSurvey(surveyId);
  }

  @override
  Future<SurveyForm?> getActiveSurvey({String? creatorId}) {
    _checkConfig();
    return _db.getActiveSurvey(creatorId: creatorId);
  }

  @override
  Future<void> submitSurveyResponse(Map<String, dynamic> answers, {String? ownerId}) {
    _checkConfig();
    return _db.submitSurveyResponse(answers, ownerId: ownerId);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllSurveyResponses({String? ownerId}) {
    _checkConfig();
    return _db.getAllSurveyResponses(ownerId: ownerId);
  }

  @override
  Future<void> deleteSurveyResponse(String id) {
    _checkConfig();
    return _db.deleteSurveyResponse(id);
  }

  // Legacy method kept for compatibility if needed, but redirects to init
  Future<void> initDatabase() async {
    await init();
  }
}
