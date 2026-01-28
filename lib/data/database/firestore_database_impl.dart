import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'base_database.dart';
import '../models/feedback_model.dart';
import '../models/user_model.dart';
import '../models/survey_models.dart';

/// Cloud Firestore implementation of the database interface
/// This replaces Firebase Realtime Database with Firestore for better web compatibility
class FirestoreDatabaseImpl implements BaseDatabase {
  FirebaseFirestore? _firestore;
  bool _isInitialized = false;

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _firestore = FirebaseFirestore.instance;
      _isInitialized = true;
      developer.log('Firestore initialized successfully', name: 'FirestoreDatabaseImpl');
    } catch (e) {
      developer.log('Error initializing Firestore: $e', name: 'FirestoreDatabaseImpl', error: e);
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_firestore == null || !_isInitialized) {
      developer.log('Firestore not initialized, attempting init...', name: 'FirestoreDatabaseImpl');
      await init();
    }
  }

  @override
  Future<void> createUserProfile(UserModel user) async {
    await _ensureInitialized();
    if (user.id == null) throw Exception('Cannot save user without ID');
    
    try {
      await _firestore!.collection('users').doc(user.id).set(user.toMap());
    } catch (e) {
      developer.log('Error creating user profile: $e', name: 'FirestoreDatabaseImpl', error: e);
      rethrow;
    }
  }

  @override
  Future<UserModel?> getUserProfile(String uid) async {
    await _ensureInitialized();
    
    try {
      final doc = await _firestore!.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['id'] = uid;
        return UserModel.fromMap(data);
      }
    } catch (e) {
      developer.log('Error fetching user profile: $e', name: 'FirestoreDatabaseImpl', error: e);
    }
    return null;
  }

  @override
  Future<void> updateUserProfile(UserModel user) async {
    await createUserProfile(user);
  }

  @override
  Future<String> insertFeedback(FeedbackModel feedback) async {
    await _ensureInitialized();
    
    final feedbackMap = feedback.toMap();
    feedbackMap.remove('id');
    
    developer.log('Inserting feedback to Firestore', name: 'FirestoreDatabaseImpl');
    
    final docRef = await _firestore!.collection('feedback').add(feedbackMap);
    
    developer.log('Feedback saved with ID: ${docRef.id}', name: 'FirestoreDatabaseImpl');
    return docRef.id;
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
    await _ensureInitialized();
    
    try {
      Query<Map<String, dynamic>> query = _firestore!.collection('feedback');
      
      // Filter by owner
      if (userId != null) {
        query = query.where('owner_id', isEqualTo: userId);
      }
      
      // Apply limit
      query = query.limit(limit);
      
      final snapshot = await query.get();
      
      List<FeedbackModel> feedbackList = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          
          final feedback = FeedbackModel.fromMap(data);
          
          // Apply additional filters in memory
          bool matches = true;
          if (minRating != null && feedback.rating < minRating) matches = false;
          if (maxRating != null && feedback.rating > maxRating) matches = false;
          if (startDate != null && feedback.createdAt.isBefore(startDate)) matches = false;
          if (endDate != null && feedback.createdAt.isAfter(endDate)) matches = false;
          
          if (matches) {
            feedbackList.add(feedback);
          }
        } catch (e) {
          developer.log('Skipping invalid feedback: ${doc.id}', error: e, name: 'FirestoreDatabaseImpl');
        }
      }
      
      // Sort by newest first
      feedbackList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      developer.log('Loaded ${feedbackList.length} feedback items', name: 'FirestoreDatabaseImpl');
      return feedbackList;
    } catch (e) {
      developer.log('Error fetching feedback: $e', name: 'FirestoreDatabaseImpl', error: e);
      return [];
    }
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
    await _ensureInitialized();
    await _firestore!.collection('feedback').doc(id).delete();
  }

  @override
  Future<List<SurveyForm>> getAllSurveys({String? creatorId}) async {
    await _ensureInitialized();
    
    try {
      Query<Map<String, dynamic>> query = _firestore!.collection('surveys');
      
      if (creatorId != null) {
        query = query.where('creatorId', isEqualTo: creatorId);
      }
      
      final snapshot = await query.get();
      
      List<SurveyForm> surveys = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          surveys.add(SurveyForm.fromMap(data));
        } catch (e) {
          developer.log('Error parsing survey ${doc.id}: $e', name: 'FirestoreDatabaseImpl');
        }
      }
      
      return surveys;
    } catch (e) {
      developer.log('Error fetching surveys: $e', name: 'FirestoreDatabaseImpl', error: e);
      return [];
    }
  }

  @override
  Future<void> saveSurvey(SurveyForm survey) async {
    await _ensureInitialized();
    await _firestore!.collection('surveys').doc(survey.id).set(survey.toMap());
  }

  @override
  Future<void> deleteSurvey(String surveyId) async {
    await _ensureInitialized();
    await _firestore!.collection('surveys').doc(surveyId).delete();
  }

  @override
  Future<void> activateSurvey(String surveyId) async {
    await _ensureInitialized();
    
    // Get the target survey
    final surveys = await getAllSurveys();
    final targetSurvey = surveys.firstWhere((s) => s.id == surveyId);
    final targetCreatorId = targetSurvey.creatorId;
    final shouldActivate = !targetSurvey.isActive;
    
    // Get all surveys by the same creator
    final userSurveys = surveys.where((s) => s.creatorId == targetCreatorId).toList();
    
    // Batch update
    final batch = _firestore!.batch();
    
    for (var survey in userSurveys) {
      final isActive = shouldActivate && survey.id == surveyId;
      batch.update(
        _firestore!.collection('surveys').doc(survey.id),
        {'isActive': isActive},
      );
    }
    
    await batch.commit();
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
    await _ensureInitialized();
    
    await _firestore!.collection('survey_responses').add({
      'answers': answers,
      'submittedAt': FieldValue.serverTimestamp(),
      'owner_id': ownerId,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getAllSurveyResponses({String? ownerId}) async {
    await _ensureInitialized();
    
    try {
      Query<Map<String, dynamic>> query = _firestore!.collection('survey_responses');
      
      if (ownerId != null) {
        query = query.where('owner_id', isEqualTo: ownerId);
      }
      
      final snapshot = await query.get();
      
      List<Map<String, dynamic>> responses = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Convert Timestamp to ISO string
        if (data['submittedAt'] is Timestamp) {
          data['submittedAt'] = (data['submittedAt'] as Timestamp).toDate().toIso8601String();
        }
        
        responses.add(data);
      }
      
      return responses;
    } catch (e) {
      developer.log('Error fetching survey responses: $e', name: 'FirestoreDatabaseImpl', error: e);
      return [];
    }
  }

  @override
  Future<void> deleteSurveyResponse(String id) async {
    await _ensureInitialized();
    await _firestore!.collection('survey_responses').doc(id).delete();
  }
}
