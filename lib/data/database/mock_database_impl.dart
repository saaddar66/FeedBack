import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:developer' as developer;
import 'base_database.dart';
import '../models/feedback_model.dart';
import '../models/user_model.dart';
import '../models/survey_models.dart';

class MockDatabaseImpl implements BaseDatabase {
  final List<FeedbackModel> _mockData = [];

  @override
  Future<void> init() async {
    await _generateMockData();
  }

  Future<void> _generateMockData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('mock_feedback_data');
      if (cached != null) {
        final List<dynamic> decoded = jsonDecode(cached);
        _mockData.clear();
        _mockData.addAll(decoded.map((e) => FeedbackModel.fromMap(Map<String, dynamic>.from(e))));
        developer.log('Mock: Loaded ${_mockData.length} cached feedback entries', name: 'MockDatabaseImpl');
      } else {
        // Fallback random generation if needed, but currently empty list or manual testing
        // Keeping it simple as per original code behavior which implicitly allowed empty
      }
    } catch (e) {
      developer.log('Error loading cached mock data: $e', name: 'MockDatabaseImpl', error: e);
    }
  }

  @override
  Future<void> createUserProfile(UserModel user) async {
    // Mock user profile persistence could be implemented here using SharedPreferences
    // For now, doing nothing or basic logging
    developer.log('Mock: Create user profile ${user.email}', name: 'MockDatabaseImpl');
  }

  @override
  Future<UserModel?> getUserProfile(String uid) async {
    // Return null or a mock user
    developer.log('Mock: Get user profile $uid', name: 'MockDatabaseImpl');
    return null;
  }

  @override
  Future<void> updateUserProfile(UserModel user) async {
    await createUserProfile(user);
  }

  @override
  Future<String> insertFeedback(FeedbackModel feedback) async {
    final id = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    final newFeedback = feedback.copyWith(id: id);
    _mockData.add(newFeedback);
    return id;
  }

  @override
  Future<List<FeedbackModel>> getAllFeedback({
    int? minRating,
    int? maxRating,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    String? userId,
  }) async {
    var feedbackList = List<FeedbackModel>.from(_mockData);
    feedbackList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (feedbackList.length > limit) {
      feedbackList = feedbackList.take(limit).toList();
    }
    
    // Apply filters
    return feedbackList.where((feedback) {
      bool matches = true;
      // In mock mode, we might simply ignore userId or assume single user
      if (minRating != null && feedback.rating < minRating) matches = false;
      if (maxRating != null && feedback.rating > maxRating) matches = false;
      if (startDate != null && feedback.createdAt.isBefore(startDate)) matches = false;
      if (endDate != null && feedback.createdAt.isAfter(endDate)) matches = false;
      return matches;
    }).toList();
  }

  @override
  Future<int> getFeedbackCount({
    int? minRating,
    int? maxRating,
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) async {
    final list = await getAllFeedback(
      minRating: minRating,
      maxRating: maxRating,
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );
    return list.length;
  }

  @override
  Future<Map<int, int>> getRatingDistribution({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) async {
    final list = await getAllFeedback(startDate: startDate, endDate: endDate, userId: userId);
    final Map<int, int> distribution = {};
    for (var feedback in list) {
       distribution[feedback.rating] = (distribution[feedback.rating] ?? 0) + 1;
    }
    for (int i = 1; i <= 5; i++) {
       distribution.putIfAbsent(i, () => 0);
    }
    return distribution;
  }

  @override
  Future<List<Map<String, dynamic>>> getTrendsData({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) async {
    final list = await getAllFeedback(startDate: startDate, endDate: endDate, userId: userId);
    final Map<String, List<FeedbackModel>> groupedByDate = {};
    for (var feedback in list) {
      final dateKey = feedback.createdAt.toIso8601String().substring(0, 10);
      groupedByDate.putIfAbsent(dateKey, () => []).add(feedback);
    }
    final List<Map<String, dynamic>> trendsData = [];
    groupedByDate.forEach((date, feedbacks) {
      final count = feedbacks.length;
      final avgRating = feedbacks.map((f) => f.rating).reduce((a, b) => a + b) / count;
      trendsData.add({
        'date': date,
        'count': count,
        'avg_rating': avgRating,
      });
    });
    trendsData.sort((a, b) => a['date'].compareTo(b['date']));
    return trendsData;
  }

  @override
  Future<double> getAverageRating({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) async {
    final list = await getAllFeedback(startDate: startDate, endDate: endDate, userId: userId);
    if (list.isEmpty) return 0.0;
    final totalRating = list.map((f) => f.rating).reduce((a, b) => a + b);
    return totalRating / list.length;
  }

  @override
  Future<void> deleteFeedback(String id) async {
    _mockData.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_mockData.map((e) => e.toMap()).toList());
    await prefs.setString('mock_feedback_data', encoded);
  }

  @override
  Future<List<SurveyForm>> getAllSurveys({String? creatorId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('all_surveys');
      if (jsonString != null) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        var surveys = decoded.map((item) => SurveyForm.fromMap(Map<String, dynamic>.from(item))).toList();
        if (creatorId != null) {
          surveys = surveys.where((s) => s.creatorId == creatorId).toList();
        }
        return surveys;
      }
    } catch (e) {
      developer.log('Error loading surveys from SharedPreferences: $e', name: 'MockDatabaseImpl', error: e);
    }
    return [];
  }

  @override
  Future<void> saveSurvey(SurveyForm survey) async {
    final surveys = await getAllSurveys();
    final index = surveys.indexWhere((s) => s.id == survey.id);
    if (index >= 0) {
      surveys[index] = survey;
    } else {
      surveys.add(survey);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('all_surveys', jsonEncode(surveys.map((e) => e.toMap()).toList()));
  }

  @override
  Future<void> deleteSurvey(String surveyId) async {
    final surveys = await getAllSurveys();
    surveys.removeWhere((s) => s.id == surveyId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('all_surveys', jsonEncode(surveys.map((e) => e.toMap()).toList()));
  }

  @override
  Future<void> activateSurvey(String surveyId) async {
    // In mock, simplistic implementation ignoring user constraints for now, or assume single user
    final surveys = await getAllSurveys();
    final targetSurvey = surveys.firstWhere((s) => s.id == surveyId);
    final shouldActivate = !targetSurvey.isActive;
    
    // Deactivate others (simplistic)
    for (var s in surveys) {
      s.isActive = (shouldActivate && s.id == surveyId);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('all_surveys', jsonEncode(surveys.map((e) => e.toMap()).toList()));
  }

  @override
  Future<SurveyForm?> getActiveSurvey({String? creatorId}) async {
    final surveys = await getAllSurveys(creatorId: creatorId);
    try {
      return surveys.firstWhere((s) => s.isActive);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> submitSurveyResponse(Map<String, dynamic> answers, {String? ownerId}) async {
    try {
        final prefs = await SharedPreferences.getInstance();
        final existingResponses = prefs.getStringList('survey_responses') ?? [];
        final responseJson = jsonEncode({
            'answers': answers,
            'submittedAt': DateTime.now().toIso8601String(),
            'ownerId': ownerId,
        });
        existingResponses.add(responseJson);
        await prefs.setStringList('survey_responses', existingResponses);
        developer.log('Mock: Survey response saved', name: 'MockDatabaseImpl');
    } catch (e) {
        developer.log('Error saving survey response: $e', name: 'MockDatabaseImpl', error: e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAllSurveyResponses({String? ownerId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final responses = prefs.getStringList('survey_responses') ?? [];
      var allResponses = responses.map((r) => Map<String, dynamic>.from(jsonDecode(r))).toList();
      if (ownerId != null) {
        allResponses = allResponses.where((r) => r['ownerId'] == ownerId).toList();
      }
      return allResponses;
    } catch (e) {
       developer.log('Error loading survey responses: $e', name: 'MockDatabaseImpl', error: e);
       return [];
    }
  }

  @override
  Future<void> deleteSurveyResponse(String id) async {
     // Naive implementation as ID is tricky in list of strings
  }
}
