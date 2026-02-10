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
  Future<bool> checkBusinessNameExists(String businessName) async {
    await _ensureInitialized();
    try {
      final query = await _firestore!
          .collection('users')
          .where('businessName', isEqualTo: businessName)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      developer.log('Error checking business name: $e', name: 'FirestoreDatabaseImpl');
      return false;
    }
  }

  @override
  Future<bool> checkPhoneExists(String phone) async {
    await _ensureInitialized();
    try {
      final query = await _firestore!
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
       developer.log('Error checking phone: $e', name: 'FirestoreDatabaseImpl');
       return false;
    }
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
      
      // Fix for PERMISSION_DENIED:
      // Firestore Rules require either:
      // 1. resource.data.isActive == true (Public)
      // 2. resource.data.creatorId == auth.uid (Owner)
      
      if (creatorId != null) {
         // Case 2: We are looking for specific creator's surveys. 
         // If we are that creator (auth.uid == creatorId), we can see everything.
         // If we are public user looking at a creator, we must ALSO filter by isActive=true
         // However, the rule says `allow read: if resource.data.isActive == true || isOwner(...)`.
         // So a public query for `where('creatorId', isEqualTo: X).where('isActive', isEqualTo: true)` should pass.
         
         // Ideally, we should detect if we are the owner or public.
         // But for simplicity in this public-facing method:
         query = query.where('creatorId', isEqualTo: creatorId);
      } else {
         // Case 1: Fetching "all" surveys? We should probably only fetch active ones if no creator specified.
         query = query.where('isActive', isEqualTo: true);
      }
      
      final snapshot = await query.get();
      
      developer.log('getAllSurveys: Found ${snapshot.docs.length} surveys for creatorId: $creatorId', name: 'FirestoreDatabaseImpl');

      List<SurveyForm> surveys = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          final survey = SurveyForm.fromMap(data);
          
          // Double check visibility in memory just in case
          if (creatorId != null && !survey.isActive) {
             // If we fetched inactive surveys, we must be the owner.
             // If this was a public request, Query would fail before reaching here if Rule logic was strict.
             // But let's log it.
             developer.log('Loaded inactive survey (Owner Mode?): ${survey.title}', name: 'FirestoreDatabaseImpl');
          }

          surveys.add(survey);
        } catch (e) {
          developer.log('Error parsing survey ${doc.id}: $e', name: 'FirestoreDatabaseImpl');
        }
      }
      
      return surveys;
    } catch (e) {
      // If we get PERMISSION_DENIED here with creatorId set, it likely means we are Public
      // trying to view Inactive surveys (which is forbidden).
      // We should retry with isActive=true.
      if (e.toString().contains('PERMISSION_DENIED') && creatorId != null) {
          developer.log('Permission denied fetching all surveys for $creatorId. Retrying with isActive=true filter.', name: 'FirestoreDatabaseImpl');
          return _getPublicSurveysForCreator(creatorId);
      }
      
      developer.log('Error fetching surveys: $e', name: 'FirestoreDatabaseImpl', error: e);
      return [];
    }
  }

  Future<List<SurveyForm>> _getPublicSurveysForCreator(String creatorId) async {
      try {
        final query = _firestore!.collection('surveys')
          .where('creatorId', isEqualTo: creatorId)
          .where('isActive', isEqualTo: true);
          
         final snapshot = await query.get();
         return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return SurveyForm.fromMap(data);
         }).toList();
      } catch (e) {
         developer.log('Error fetching public surveys retry: $e', name: 'FirestoreDatabaseImpl');
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
    
    try {
      // 1. Fetch the specific survey to be toggled directly
      // This avoids "Query matches all documents" rule violation (PERMISSION_DENIED)
      final docRef = _firestore!.collection('surveys').doc(surveyId);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        developer.log('Survey not found: $surveyId', name: 'FirestoreDatabaseImpl');
        return;
      }

      final data = docSnapshot.data()!;
      data['id'] = docSnapshot.id;
      final targetSurvey = SurveyForm.fromMap(data);
      
      final targetCreatorId = targetSurvey.creatorId;
      final shouldActivate = !targetSurvey.isActive;
      
      final batch = _firestore!.batch();

      // Update the target survey
      batch.update(docRef, {'isActive': shouldActivate});

      // If we are activating this one, find all OTHER active surveys by this creator and deactivate them
      if (shouldActivate && targetCreatorId != null) {
         // This filtered query matches security rules: creatorId == auth.uid OR isActive == true
         final otherActiveSurveysSnapshot = await _firestore!
            .collection('surveys')
            .where('creatorId', isEqualTo: targetCreatorId)
            .where('isActive', isEqualTo: true)
            .get();

         for (var doc in otherActiveSurveysSnapshot.docs) {
           if (doc.id != surveyId) {
             batch.update(doc.reference, {'isActive': false});
           }
         }
      }
      
      await batch.commit();
    } catch (e) {
      developer.log('Error activating survey: $e', name: 'FirestoreDatabaseImpl', error: e);
      rethrow;
    }
  }

  @override
  Future<SurveyForm?> getActiveSurvey({String? creatorId}) async {
    await _ensureInitialized();
    if (creatorId == null) return null;

    try {
      // Strategy 1: Smart Query (Requires Composite Index: creatorId + isActive)
      // This is the most efficient and rule-compliant way.
      try {
        final query = _firestore!.collection('surveys')
            .where('creatorId', isEqualTo: creatorId)
            .where('isActive', isEqualTo: true)
            .limit(1);

        final snapshot = await query.get();
        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          final data = doc.data();
          data['id'] = doc.id;
          return SurveyForm.fromMap(data);
        }
      } catch (e) {
        // If Strategy 1 fails (likely FAILED_PRECONDITION due to missing index),
        // we fall back to Strategy 2.
        developer.log('Smart query failed (likely missing index), trying fallback: $e', name: 'FirestoreDatabaseImpl');
               
        // Strategy 2: Broad Query (isActive only) + Client-side filtering
        // This scans all active surveys but guarantees a result if the survey exists.
        // It satisfies the "public read active" rule.
        final fallbackQuery = _firestore!.collection('surveys')
            .where('isActive', isEqualTo: true);
            
         final snapshot = await fallbackQuery.get();
         
         // Filter for the specific creator in memory
         final match = snapshot.docs
             .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return SurveyForm.fromMap(data); 
             })
             .firstWhere(
                (s) => s.creatorId == creatorId, 
                orElse: () => throw Exception('Not found')
             );
             
         return match;
      }
    } catch (e) {
       // If both startgies fail, or no match found in Strategy 2
       if (e.toString().contains('Not found')) {
         developer.log('No active survey found for creator: $creatorId', name: 'FirestoreDatabaseImpl');
       } else {
         developer.log('Error getting active survey: $e', name: 'FirestoreDatabaseImpl', error: e);
       }
       return null;
    }
    
    return null;
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
  @override
  Future<List<Map<String, dynamic>>> getAllSurveyResponses({String? ownerId, int limit = 100}) async {
    await _ensureInitialized();
    
    try {
      Query<Map<String, dynamic>> query = _firestore!.collection('survey_responses');
      
      if (ownerId != null) {
        query = query.where('owner_id', isEqualTo: ownerId);
      }
      
      // Sort by newest first (server-side)
      query = query.orderBy('submittedAt', descending: true);
      
      // Apply limit
      query = query.limit(limit);
      
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
      if (e.toString().contains('FAILED_PRECONDITION')) {
        developer.log('MISSING INDEX: Visit the link in the console to create required composite index', name: 'FirestoreDatabaseImpl');
      }
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
