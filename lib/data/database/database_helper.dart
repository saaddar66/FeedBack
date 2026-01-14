import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feedback_model.dart';
import '../models/user_model.dart';
import '../models/survey_models.dart';
import 'dart:math';
import 'dart:convert';

/// Database helper class using Firebase Realtime Database
/// Implements singleton pattern to ensure single database instance
/// Falls back to mock data if Firebase is not initialized
class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  
  // Firebase Realtime Database reference
  DatabaseReference? _databaseRef;
  
  // Mock data for demo/offline mode
  bool _useMock = false;
  final List<FeedbackModel> _mockData = [];
  
  // Private constructor for singleton pattern
  DatabaseHelper._init();

  /// Initializes the database connection
  /// For Firebase, this is mainly for ensuring Firebase is initialized
  /// Should be called at app startup
  Future<void> initDatabase() async {
    try {
      // Enable offline persistence
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      
      _databaseRef = FirebaseDatabase.instance.ref('feedback');
      
      // Optional: Check connection status, but don't block or switch to mock
      // This allows the app to start offline using cached data
      try {
        await _databaseRef!.limitToFirst(1).get().timeout(const Duration(seconds: 2));
      } catch (e) {
        print('Note: Starting in OFFLINE mode (Firebase not reachable immediately)');
      }
      
    } catch (e) {
      print('Critical Error: Firebase initialization failed: $e');
      // In production, we might want to show a fatal error screen here
      // instead of silently failing or showing mock data.
    }
  }

  /// Generates or loads cached mock data for demo/offline mode
  Future<void> _generateMockData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('mock_feedback_data');
      
      if (cached != null) {
        // Load from cache
        final List<dynamic> decoded = jsonDecode(cached);
        _mockData.clear();
        _mockData.addAll(
          decoded.map((e) => FeedbackModel.fromMap(Map<String, dynamic>.from(e)))
        );
        print('Mock: Loaded ${_mockData.length} cached feedback entries');
        return;
      }
    } catch (e) {
      print('Error loading cached mock data: $e');
    }
    
    // Generate new mock data - kept for legacy mock compatibility
    final random = Random();
  }

  // --- User Profile Methods (Firebase RTDB) ---

  /// Creates or Overwrites user profile data in Realtime Database
  Future<void> createUserProfile(UserModel user) async {
      // Ensure DB initialized
      if (_databaseRef == null) await initDatabase();
      if (user.id == null) throw Exception('Cannot save user without ID');
      
      try {
          // Store under users/{uid}
          await _databaseRef!.root.child('users/${user.id}').set(user.toMap());
      } catch (e) {
          print('Error creating user profile: $e');
          rethrow;
      }
  }
  
  /// Fetches user profile data from Realtime Database
  Future<UserModel?> getUserProfile(String uid) async {
       if (_databaseRef == null) await initDatabase();
       
       try {
           final snapshot = await _databaseRef!.root.child('users/$uid').get();
           if (snapshot.exists && snapshot.value != null) {
               final data = Map<String, dynamic>.from(snapshot.value as Map);
               data['id'] = uid; // Ensure ID is present
               return UserModel.fromMap(data);
           }
       } catch (e) {
           print('Error fetching user profile: $e');
       }
       return null;
  }

  /// Updates specific fields in user profile
  Future<void> updateUserProfile(UserModel user) async {
      await createUserProfile(user); // Reuse create (it overwrites/updates)
  }


  /// Inserts a new feedback entry into Firebase Realtime Database
  /// Returns the key (ID) of the inserted entry
  Future<String> insertFeedback(FeedbackModel feedback) async {
    if (_useMock) {
        final id = 'mock_${DateTime.now().millisecondsSinceEpoch}';
        final newFeedback = feedback.copyWith(id: id);
        _mockData.add(newFeedback);
        return id;
    }

    final feedbackMap = feedback.toMap();
    // Remove id from map as Firebase generates its own key
    feedbackMap.remove('id');
    
    // Push creates a new child with auto-generated key
    final newFeedbackRef = _databaseRef!.push();
    await newFeedbackRef.set(feedbackMap);
    
    // Return the generated key as the ID
    return newFeedbackRef.key!;
  }

  /// Retrieves all feedback entries with optional filters
  /// Filters are applied client-side after fetching data
  /// Returns list sorted by creation date (newest first)
  /// [limit] parameter limits the number of entries fetched (default: 100)
  Future<List<FeedbackModel>> getAllFeedback({
    int? minRating,
    int? maxRating,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    String? userId, // Optional filter by owner
  }) async {
    List<FeedbackModel> feedbackList = [];

    if (_useMock) {
        feedbackList = List.from(_mockData);
        // Sort by date (newest first) and apply limit
        feedbackList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (feedbackList.length > limit) {
          feedbackList = feedbackList.take(limit).toList();
        }
    } else {
        if (_databaseRef == null) await initDatabase();
        // Recurse if init switched to mock, otherwise continue with firebase
        if (_useMock) return getAllFeedback(minRating: minRating, maxRating: maxRating, startDate: startDate, endDate: endDate, limit: limit, userId: userId);

        try {
            // Use limitToLast to fetch only the most recent entries
            // Order by created_at timestamp to get newest first
            // Note: Firebase query limitations mean we often filter client-side for complex multi-field queries
            final query = _databaseRef!.orderByChild('created_at').limitToLast(limit);
            final snapshot = await query.get();
            if (snapshot.exists && snapshot.value != null) {
              final dynamic val = snapshot.value;

              // SCENARIO 1: Standard Firebase Data (Map)
              if (val is Map) {
                for (var entry in val.entries) {
                  // Safety check: ensure the child is actually a Map
                  if (entry.value is Map) {
                    final feedbackData = Map<String, dynamic>.from(entry.value as Map);
                    feedbackData['id'] = entry.key.toString();
                    feedbackList.add(FeedbackModel.fromMap(feedbackData));
                  }
                }
              } 
              // SCENARIO 2: Sequential Data (List)
              else if (val is List) {
                for (int i = 0; i < val.length; i++) {
                  // Lists might contain nulls if keys were deleted
                  if (val[i] != null && val[i] is Map) {
                    final feedbackData = Map<String, dynamic>.from(val[i] as Map);
                    feedbackData['id'] = i.toString(); // Use index as ID
                    feedbackList.add(FeedbackModel.fromMap(feedbackData));
                  }
                }
              }
              // SCENARIO 3: Corrupted Data (String/Other)
              else {
                print('Warning: Ignored unexpected data type from Firebase: ${val.runtimeType}');
              }
            }
        } catch (e) {
             print('Error fetching from Firebase: $e. Switching to mock.');
             _useMock = true;
             _generateMockData();
             return getAllFeedback(minRating: minRating, maxRating: maxRating, startDate: startDate, endDate: endDate, limit: limit, userId: userId);
        }
    }

    // Filter and Sort
    final filteredList = feedbackList.where((feedback) {
      bool matches = true;
      
      // User ID filter (Owner check)
      if (userId != null && feedback.ownerId != userId) matches = false;

      // Rating filters
      if (minRating != null && feedback.rating < minRating) matches = false;
      if (maxRating != null && feedback.rating > maxRating) matches = false;
      
      // Date filters
      if (startDate != null && feedback.createdAt.isBefore(startDate)) matches = false;
      if (endDate != null && feedback.createdAt.isAfter(endDate)) matches = false;
      
      return matches;
    }).toList();

    // Sort by creation date (newest first)
    filteredList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return filteredList;
  }

  /// Gets the total count of feedback entries matching the filters
  /// Useful for displaying statistics
  Future<int> getFeedbackCount({
    int? minRating,
    int? maxRating,
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) async {
    final feedbackList = await getAllFeedback(
      minRating: minRating,
      maxRating: maxRating,
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );
    return feedbackList.length;
  }

  /// Gets the distribution of ratings (how many feedbacks for each rating 1-5)
  /// Returns a map where key is rating and value is count
  Future<Map<int, int>> getRatingDistribution({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) async {
    final feedbackList = await getAllFeedback(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );
    
    final Map<int, int> distribution = {};
    
    for (var feedback in feedbackList) {
      distribution[feedback.rating] = (distribution[feedback.rating] ?? 0) + 1;
    }
    
    // Ensure all ratings 1-5 are in the map (even if count is 0)
    for (int i = 1; i <= 5; i++) {
      distribution.putIfAbsent(i, () => 0);
    }
    
    return distribution;
  }

  /// Gets trends data grouped by date
  /// Returns daily counts and average ratings for chart visualization
  Future<List<Map<String, dynamic>>> getTrendsData({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) async {
    final feedbackList = await getAllFeedback(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );
    
    // Group by date
    final Map<String, List<FeedbackModel>> groupedByDate = {};
    
    for (var feedback in feedbackList) {
      final dateKey = feedback.createdAt.toIso8601String().substring(0, 10); // YYYY-MM-DD
      groupedByDate.putIfAbsent(dateKey, () => []).add(feedback);
    }
    
    // Convert to list of maps with aggregated data
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
    
    // Sort by date
    trendsData.sort((a, b) => a['date'].compareTo(b['date']));
    
    return trendsData;
  }

  /// Calculates the average rating of all feedback entries
  /// Can be filtered by date range
  Future<double> getAverageRating({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) async {
    final feedbackList = await getAllFeedback(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );
    
    if (feedbackList.isEmpty) {
      return 0.0;
    }
    
    final totalRating = feedbackList.map((f) => f.rating).reduce((a, b) => a + b);
    return totalRating / feedbackList.length;
  }

  // --- Survey Configuration & Responses ---

  /// Saves the current configuration of survey questions to Firebase or SharedPreferences (mock mode)
  // --- Survey Management Methods ---

  /// Retrieves all configured surveys
  Future<List<SurveyForm>> getAllSurveys({String? creatorId}) async {
    if (_useMock) {
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
        print('Error loading surveys from SharedPreferences: $e');
      }
      return [];
    }

    if (_databaseRef == null) await initDatabase();
    if (_useMock) return getAllSurveys(creatorId: creatorId);

    try {
      // Fetch ALL surveys without server-side filtering to avoid Firebase SDK crashes
      // Server-side filtering causes Firebase to deserialize ALL nodes (including corrupted ones)
      // which triggers 'String is not a subtype of Map' errors before our code can handle them
      Query query = _databaseRef!.root.child('surveys');

      final snapshot = await query.get();
      
      if (!snapshot.exists || snapshot.value == null) {
        print('DEBUG: No surveys found in database');
        return [];
      }
      
      // Wrap the value access in its own try-catch
      dynamic value;
      try {
        value = snapshot.value;
        print('DEBUG: snapshot.value type = ${value.runtimeType}');
      } catch (e) {
        print('ERROR accessing snapshot.value: $e');
        return [];
      }
      
      List<SurveyForm> surveys = [];
      
      // Handle case where entire snapshot is a String (corrupted data)
      if (value is String) {
        print('Warning: surveys node is a String, not a Map/List: $value');
        return [];
      }
      
      if (value is Map) {
        for (var entry in value.entries) {
          final key = entry.key;
          final val = entry.value;
          
          // Skip non-map entries (strings, numbers, etc.)
          if (val is! Map) {
            print('Skipping non-map survey node: $key → ${val.runtimeType}');
            continue;
          }

          try {
            final map = Map<String, dynamic>.from(val);
            map['id'] = key.toString();
            surveys.add(SurveyForm.fromMap(map));
          } catch (e) {
            print('Skipping malformed survey ($key): $e');
          }
        }
      } else if (value is List) {
         for (int i = 0; i < value.length; i++) {
           final item = value[i];
           if (item is Map) {
              try {
                 final map = Map<String, dynamic>.from(item);
                 surveys.add(SurveyForm.fromMap(map));
              } catch(e) {
                 print('Skipping malformed survey at index $i: $e');
              }
           }
         }
      } else {
        print('DEBUG: Unexpected value type: ${value.runtimeType}');
      }
      
      // Apply client-side filtering AFTER safe parsing to avoid Firebase SDK crashes
      if (creatorId != null) {
        surveys = surveys.where((s) => s.creatorId == creatorId).toList();
      }
      
      print('DEBUG: Successfully loaded ${surveys.length} surveys');
      return surveys;
    } catch (e, stackTrace) {
      print('Error fetching surveys: $e');
      print('Stack trace: $stackTrace');
    }
    return [];
  }

  /// Transforms survey data for Firebase storage
  /// Converts questions list to object format with value field for index.html compatibility
  Map<String, dynamic> _transformSurveyForFirebase(SurveyForm survey) {
    final baseMap = survey.toMap();
    
    // Convert questions list to object format
    // Each question gets a 'value' field: true if survey is active, false otherwise
    final Map<String, dynamic> questionsMap = {};
    for (var question in survey.questions) {
      final questionMap = question.toMap();
      // Add 'value' field based on survey's isActive status
      // When survey is green (active), questions have value: true (shown in index.html)
      // When survey is red (inactive), questions have value: false (hidden in index.html)
      questionMap['value'] = survey.isActive;
      // Also add 'text' field for index.html compatibility (uses 'title' as 'text')
      questionMap['text'] = question.title;
      // Map question type to index.html format
      questionMap['type'] = _mapQuestionTypeForWeb(question.type);
      // Add required field (default to true, can be set to false if needed)
      questionMap['required'] = true;
      questionsMap[question.id] = questionMap;
    }
    
    // Replace questions list with questions object
    baseMap['questions'] = questionsMap;
    
    return baseMap;
  }

  /// Maps Dart QuestionType to web format string
  String _mapQuestionTypeForWeb(QuestionType type) {
    switch (type) {
      case QuestionType.text:
        return 'text';
      case QuestionType.rating:
        return 'rating';
      case QuestionType.singleChoice:
        return 'singleChoice';
      case QuestionType.multipleChoice:
        return 'multipleChoice';
    }
  }

  /// Saves a survey (create or update)
  Future<void> saveSurvey(SurveyForm survey) async {
    // Ensure database is initialized before saving
    if (_databaseRef == null) await initDatabase();
    
    if (_useMock) {
      final surveys = await getAllSurveys();
      final index = surveys.indexWhere((s) => s.id == survey.id);
      if (index >= 0) {
        surveys[index] = survey;
      } else {
        surveys.add(survey);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('all_surveys', jsonEncode(surveys.map((e) => e.toMap()).toList()));
      return;
    }

    // For Firebase, transform the survey structure for web compatibility
    final transformedData = _transformSurveyForFirebase(survey);
    await _databaseRef!.root.child('surveys/${survey.id}').set(transformedData);
  }

  /// Deletes a survey
  Future<void> deleteSurvey(String surveyId) async {
    if (_useMock) {
      final surveys = await getAllSurveys();
      surveys.removeWhere((s) => s.id == surveyId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('all_surveys', jsonEncode(surveys.map((e) => e.toMap()).toList()));
      return;
    }
    await _databaseRef!.root.child('surveys/$surveyId').remove();
  }

  /// Toggles survey activation - activates if inactive, deactivates if already active
  /// Ensures only one survey is active at a time
  Future<void> activateSurvey(String surveyId) async {
    final surveys = await getAllSurveys();
    
    // Find the survey being toggled
    final targetSurvey = surveys.firstWhere(
      (s) => s.id == surveyId,
      orElse: () => throw Exception('Survey not found: $surveyId'),
    );
    
    // Determine new state: if already active, deactivate; otherwise activate
    final shouldActivate = !targetSurvey.isActive;
    
    // Update all surveys: activate target (if shouldActivate), deactivate all others
    for (var s in surveys) {
      s.isActive = (shouldActivate && s.id == surveyId);
    }

    if (_useMock) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('all_surveys', jsonEncode(surveys.map((e) => e.toMap()).toList()));
      return;
    }

    // For Firebase, we need to update both isActive and questions structure
    // When a survey becomes active (green), its questions get value: true
    // When a survey becomes inactive (red), its questions get value: false
    Map<String, Object?> updates = {};
    for (var s in surveys) {
      updates['surveys/${s.id}/isActive'] = s.isActive;
      
      // Update questions structure with value field based on isActive
      // When survey is green (active), questions have value: true (shown in index.html)
      // When survey is red (inactive), questions have value: false (hidden in index.html)
      final questionsMap = <String, dynamic>{};
      for (var question in s.questions) {
        final questionMap = question.toMap();
        questionMap['value'] = s.isActive;
        questionMap['text'] = question.title;
        questionMap['type'] = _mapQuestionTypeForWeb(question.type);
        questionMap['required'] = true;
        questionsMap[question.id] = questionMap;
      }
      updates['surveys/${s.id}/questions'] = questionsMap;
    }
    await _databaseRef!.root.update(updates);
  }

  /// Gets the currently active survey for user display
  Future<SurveyForm?> getActiveSurvey({String? creatorId}) async {
    final surveys = await getAllSurveys(creatorId: creatorId);
    try {
      return surveys.firstWhere((s) => s.isActive);
    } catch (e) {
      return null;
    }
  }

  /// Submits a user's answers to the survey
  Future<void> submitSurveyResponse(Map<String, dynamic> answers, {String? ownerId}) async {
       if (_useMock) {
          // In mock mode, save responses to SharedPreferences
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
              print('Mock: Survey response saved to SharedPreferences');
          } catch (e) {
              print('Error saving survey response: $e');
          }
          return;
      }

      // Store responses under 'survey_responses'
      final responseRef = _databaseRef!.root.child('survey_responses').push();
      
      await responseRef.set({
          'answers': answers,
          'submittedAt': DateTime.now().toIso8601String(),
          'ownerId': ownerId,
      });
  }

  /// Retrieves all survey responses, optionally filtered by ownerId
  Future<List<Map<String, dynamic>>> getAllSurveyResponses({String? ownerId}) async {
    if (_useMock) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final responses = prefs.getStringList('survey_responses') ?? [];
        var allResponses = responses.map((r) => Map<String, dynamic>.from(jsonDecode(r))).toList();
        
        // Filter by ownerId if provided
        if (ownerId != null) {
          allResponses = allResponses.where((r) => r['ownerId'] == ownerId).toList();
        }
        
        return allResponses;
      } catch (e) {
        print('Error loading survey responses: $e');
        return [];
      }
    }

    if (_databaseRef == null) await initDatabase();
    if (_useMock) return getAllSurveyResponses(ownerId: ownerId);

    try {
      print('Fetching survey responses from Firebase...');
      final snapshot = await _databaseRef!.root.child('survey_responses').get();
      print('Snapshot exists: ${snapshot.exists}');
      
      if (snapshot.exists && snapshot.value != null) {
        final dynamic value = snapshot.value;
        List<Map<String, dynamic>> responses = [];
        if (value is Map) {
          print('Found ${value.length} survey responses in Firebase');
          value.forEach((key, val) {
             final map = Map<String, dynamic>.from(val as Map);
             map['id'] = key;
             
             // Normalize data format: if answers are at root level, wrap them in 'answers'
             if (!map.containsKey('answers')) {
               // Extract answer fields (everything except metadata fields)
               final answers = <String, dynamic>{};
               final metadataFields = {'id', 'submittedAt', 'ownerId', 'userName', 'userEmail', 'answers'};
               
               map.forEach((k, v) {
                 if (!metadataFields.contains(k)) {
                   answers[k] = v;
                 }
               });
               
               // If we found answer fields, wrap them
               if (answers.isNotEmpty) {
                 // Remove answer fields from root
                 answers.keys.forEach((k) => map.remove(k));
                 // Add wrapped answers
                 map['answers'] = answers;
                 print('Normalized response $key: moved ${answers.length} answer fields to answers object');
               }
             }
             
             responses.add(map);
          });
        }
        
        print('Total responses before filtering: ${responses.length}');
        
        // Filter by ownerId if provided
        if (ownerId != null) {
          // Show responses that match ownerId OR responses without ownerId (orphaned responses)
          // This handles cases where QR code didn't include uid parameter
          final filtered = responses.where((r) {
            final responseOwnerId = r['ownerId'];
            // Match if ownerId matches OR if response has no ownerId (null/empty)
            return responseOwnerId == ownerId || 
                   responseOwnerId == null || 
                   responseOwnerId.toString().isEmpty;
          }).toList();
          
          print('Filtered responses by ownerId ($ownerId): ${filtered.length}');
          print('  - Responses with matching ownerId: ${responses.where((r) => r['ownerId'] == ownerId).length}');
          print('  - Responses without ownerId (orphaned): ${responses.where((r) => r['ownerId'] == null || r['ownerId'].toString().isEmpty).length}');
          
          responses = filtered;
        } else {
          // If no ownerId filter, show all responses (for debugging/admin view)
          print('No ownerId filter - showing all ${responses.length} responses');
        }
        
        print('Returning ${responses.length} survey responses');
        return responses;
      } else {
        print('No survey responses found in Firebase');
      }
    } catch (e) {
      print('Error fetching survey responses: $e');
      print('Stack trace: ${StackTrace.current}');
    }
    return [];
  }

  /// Deletes a specific feedback entry
  Future<void> deleteFeedback(String id) async {
    if (_useMock) {
      _mockData.removeWhere((element) => element.id == id);
      // Update cache
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_mockData.map((e) => e.toMap()).toList());
      await prefs.setString('mock_feedback_data', encoded);
      return;
    }
    
    // For Firebase
    if (_databaseRef == null) await initDatabase();
    // Assuming feedback is stored under 'feedback' node
    await _databaseRef!.root.child('feedback/$id').remove();
  }

  /// Deletes a specific survey response
  Future<void> deleteSurveyResponse(String id) async {
      if (_useMock) {
          final prefs = await SharedPreferences.getInstance();
          final existingResponses = prefs.getStringList('survey_responses') ?? [];
          // This is a bit tricky since we store as list of strings, ID logic would need parsing
          // For simplicity in mock, we skip or naive delete if we could identify
          // Actually let's assume we can load, filter, and save
          // Implementation omitted for brevity in mock mode for now, or just:
          // existingResponses.removeWhere(...)
          return;
      }

      if (_databaseRef == null) await initDatabase();
      await _databaseRef!.root.child('survey_responses/$id').remove();
  }

  /// Closes the database connection
  /// Firebase Realtime Database manages connections automatically
  /// This method is kept for interface compatibility
  Future<void> close() async {
    // Firebase Realtime Database doesn't require explicit closing
    // Connections are managed automatically
  }
}
