import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feedback_model.dart';
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
      // Try to get the reference. If Firebase isn't initialized, this might throw
      // or subsequent operations will throw.
      _databaseRef = FirebaseDatabase.instance.ref('feedback');
      
      // dedicated check to see if we can actually use it
      await _databaseRef!.limitToFirst(1).get();
      
    } catch (e) {
      print('Firebase initialization failed or not configured: $e');
      print('Switching to MOCK mode for demo purposes.');
      _useMock = true;
      _generateMockData();
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
    
    // Generate new mock data
    final random = Random();
    final now = DateTime.now();
    for (int i = 0; i < 20; i++) {
        final date = now.subtract(Duration(days: random.nextInt(30)));
        _mockData.add(FeedbackModel(
            id: 'mock_$i',
            rating: random.nextInt(5) + 1,
            comments: 'This is a mock feedback comment #$i used for demonstration purposes.',
            createdAt: date,
            name: random.nextBool() ? 'User $i' : null,
            email: random.nextBool() ? 'user$i@example.com' : null,
        ));
    }
    
    // Cache for next time
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_mockData.map((e) => e.toMap()).toList());
      await prefs.setString('mock_feedback_data', encoded);
      print('Mock: Generated and cached ${_mockData.length} feedback entries');
    } catch (e) {
      print('Error caching mock data: $e');
    }
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
        if (_useMock) return getAllFeedback(minRating: minRating, maxRating: maxRating, startDate: startDate, endDate: endDate);

        try {
            // Use limitToLast to fetch only the most recent entries
            // Order by created_at timestamp to get newest first
            final query = _databaseRef!.orderByChild('created_at').limitToLast(limit);
            final snapshot = await query.get();
            if (snapshot.exists && snapshot.value != null) {
                final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
                for (var entry in data.entries) {
                    final feedbackData = Map<String, dynamic>.from(entry.value as Map);
                    feedbackData['id'] = entry.key; // Use Firebase key as ID
                    feedbackList.add(FeedbackModel.fromMap(feedbackData));
                }
            }
        } catch (e) {
             print('Error fetching from Firebase: $e. Switching to mock.');
             _useMock = true;
             _generateMockData();
             return getAllFeedback(minRating: minRating, maxRating: maxRating, startDate: startDate, endDate: endDate);
        }
    }

    // Filter and Sort
    final filteredList = feedbackList.where((feedback) {
      bool matches = true;
      
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
  }) async {
    final feedbackList = await getAllFeedback(
      minRating: minRating,
      maxRating: maxRating,
      startDate: startDate,
      endDate: endDate,
    );
    return feedbackList.length;
  }

  /// Gets the distribution of ratings (how many feedbacks for each rating 1-5)
  /// Returns a map where key is rating and value is count
  Future<Map<int, int>> getRatingDistribution({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final feedbackList = await getAllFeedback(
      startDate: startDate,
      endDate: endDate,
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
  }) async {
    final feedbackList = await getAllFeedback(
      startDate: startDate,
      endDate: endDate,
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
  }) async {
    final feedbackList = await getAllFeedback(
      startDate: startDate,
      endDate: endDate,
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
  Future<List<SurveyForm>> getAllSurveys() async {
    if (_useMock) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString('all_surveys');
        if (jsonString != null) {
          final List<dynamic> decoded = jsonDecode(jsonString);
          return decoded.map((item) => SurveyForm.fromMap(Map<String, dynamic>.from(item))).toList();
        }
      } catch (e) {
        print('Error loading surveys from SharedPreferences: $e');
      }
      return [];
    }

    if (_databaseRef == null) await initDatabase();
    if (_useMock) return getAllSurveys();

    try {
      final snapshot = await _databaseRef!.root.child('surveys').get();
      if (snapshot.exists && snapshot.value != null) {
        // Firebase returns either a List (if keys are integers) or Map (if keys are strings)
        // Since we will use push(), keys are strings.
        final dynamic value = snapshot.value;
        List<SurveyForm> surveys = [];
        if (value is Map) {
          value.forEach((key, val) {
             final map = Map<String, dynamic>.from(val as Map);
             map['id'] = key; // Ensure ID matches key
             surveys.add(SurveyForm.fromMap(map));
          });
        } else if (value is List) {
           for (var item in value) {
             if (item != null) {
                surveys.add(SurveyForm.fromMap(Map<String, dynamic>.from(item as Map)));
             }
           }
        }
        return surveys;
      }
    } catch (e) {
      print('Error fetching surveys: $e');
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

  /// Activates one survey and deactivates all others
  Future<void> activateSurvey(String surveyId) async {
    final surveys = await getAllSurveys();
    
    // Update local objects
    for (var s in surveys) {
      s.isActive = (s.id == surveyId);
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
  Future<SurveyForm?> getActiveSurvey() async {
    final surveys = await getAllSurveys();
    try {
      return surveys.firstWhere((s) => s.isActive);
    } catch (e) {
      return null;
    }
  }

  /// Submits a user's answers to the survey
  Future<void> submitSurveyResponse(Map<String, dynamic> answers) async {
       if (_useMock) {
          // In mock mode, save responses to SharedPreferences
          try {
              final prefs = await SharedPreferences.getInstance();
              final existingResponses = prefs.getStringList('survey_responses') ?? [];
              final responseJson = jsonEncode({
                  'answers': answers,
                  'submittedAt': DateTime.now().toIso8601String(),
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
      });
  }

  /// Retrieves all survey responses
  Future<List<Map<String, dynamic>>> getAllSurveyResponses() async {
    if (_useMock) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final responses = prefs.getStringList('survey_responses') ?? [];
        return responses.map((r) => Map<String, dynamic>.from(jsonDecode(r))).toList();
      } catch (e) {
        print('Error loading survey responses: $e');
        return [];
      }
    }

    if (_databaseRef == null) await initDatabase();
    if (_useMock) return getAllSurveyResponses();

    try {
      final snapshot = await _databaseRef!.root.child('survey_responses').get();
      if (snapshot.exists && snapshot.value != null) {
        final dynamic value = snapshot.value;
        List<Map<String, dynamic>> responses = [];
        if (value is Map) {
          value.forEach((key, val) {
             final map = Map<String, dynamic>.from(val as Map);
             map['id'] = key;
             responses.add(map);
          });
        }
        return responses;
      }
    } catch (e) {
      print('Error fetching survey responses: $e');
    }
    return [];
  }

  /// Closes the database connection
  /// Firebase Realtime Database manages connections automatically
  /// This method is kept for interface compatibility
  Future<void> close() async {
    // Firebase Realtime Database doesn't require explicit closing
    // Connections are managed automatically
  }
}
