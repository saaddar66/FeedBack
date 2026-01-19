import 'package:flutter/foundation.dart';
import '../../data/repositories/feedback_repository.dart';
import '../../data/models/feedback_model.dart';
import '../../data/models/survey_models.dart';

/// Top-level function for computing statistics in a background isolate
/// This function must be top-level or static to work with compute()
Map<String, dynamic> calculateStats(List<Map<String, dynamic>> feedbackJsonList) {
  // Convert JSON back to FeedbackModel objects
  final feedbackList = feedbackJsonList.map((json) {
    return FeedbackModel(
      id: json['id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      rating: json['rating'] as int,
      comments: json['comments'] as String,
      createdAt: DateTime.parse(json['created_at'] as String), // Note: created_at from toMap()
    );
  }).toList();

  // Calculate Total Count
  final totalFeedback = feedbackList.length;

  // Calculate Average Rating
  double averageRating = 0.0;
  if (feedbackList.isNotEmpty) {
    final sum = feedbackList.fold(0, (prev, element) => prev + element.rating);
    averageRating = sum / feedbackList.length;
  }

  // Calculate Rating Distribution
  final Map<int, int> ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  for (var f in feedbackList) {
    ratingDistribution[f.rating] = (ratingDistribution[f.rating] ?? 0) + 1;
  }

  // Calculate Trends Data (Group by YYYY-MM-DD)
  final Map<String, List<FeedbackModel>> groupedByDate = {};
  for (var f in feedbackList) {
    final dateKey = f.createdAt.toIso8601String().substring(0, 10);
    groupedByDate.putIfAbsent(dateKey, () => []).add(f);
  }

  final List<Map<String, dynamic>> trendsData = [];
  groupedByDate.forEach((date, feedbacks) {
    final count = feedbacks.length;
    final sum = feedbacks.fold(0, (prev, element) => prev + element.rating);
    final avgRating = sum / count;
    
    trendsData.add({
      'date': date,
      'count': count,
      'avg_rating': avgRating,
    });
  });
  
  // Sort trends by date
  trendsData.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

  // Return results as a map
  return {
    'totalFeedback': totalFeedback,
    'averageRating': averageRating,
    'ratingDistribution': ratingDistribution,
    'trendsData': trendsData,
  };
}

/// State management provider for feedback data
/// Manages all feedback-related state and business logic
/// Uses ChangeNotifier to notify UI of state changes
class FeedbackProvider with ChangeNotifier {
  final FeedbackRepository _repository;

  FeedbackProvider(this._repository);

  // State variables
  List<FeedbackModel> _feedbackList = [];           // List of all feedback entries
  int _totalFeedback = 0;                          // Total count of feedback
  Map<int, int> _ratingDistribution = {};          // Rating distribution map
  List<Map<String, dynamic>> _trendsData = [];     // Trends data for charts
  double _averageRating = 0.0;                     // Average rating value
  bool _isLoading = false;                         // Loading state indicator

  // Filter state variables
  int? _selectedMinRating;                         // Minimum rating filter
  int? _selectedMaxRating;                         // Maximum rating filter
  DateTime? _startDate;                            // Start date filter
  DateTime? _endDate;                              // End date filter
  
  // Current user context for filtering
  String? _currentUserId;

  // Survey config state
  List<SurveyForm> _surveys = [];
  SurveyForm? _editingSurvey;       // The survey currently being edited
  SurveyForm? _activeSurvey;        // The currently active survey for users (cached)
  
  // Backwards compatibility for ConfigurationScreen (now operates on _editingSurvey)
  SurveyForm? get editingSurvey => _editingSurvey;
  List<QuestionModel> get surveyQuestions => 
      _editingSurvey != null ? List.unmodifiable(_editingSurvey!.questions) : [];

  List<SurveyForm> get surveys => List.unmodifiable(_surveys);

  /// Sets the current user context and reloads data
  void setCurrentUser(String? userId) {
    print('FeedbackProvider: Setting current user to: $userId');
    _currentUserId = userId;
    loadSurveys();
    loadFeedback();
  }

  /// Loads all surveys
  Future<void> loadSurveys({String? userId}) async {
    // If userId provided, update context
    if (userId != null) {
      _currentUserId = userId;
    }
    _surveys = await _repository.getAllSurveys(creatorId: _currentUserId);
    notifyListeners();
  }

  /// Loads the active survey for the user-facing screen
  Future<void> loadActiveSurvey({String? userId}) async {
    _activeSurvey = await _repository.getActiveSurvey(userId: userId);
    resetSurveyAnswers();
    notifyListeners();
  }

  /// Helper to get questions for the user screen
  List<QuestionModel> get activeSurveyQuestions => 
      _activeSurvey != null ? List.unmodifiable(_activeSurvey!.questions) : [];

  /// Starts editing a survey (or creates a new one if null)
  void startEditingSurvey(SurveyForm? survey, {String? creatorId}) {
    if (survey == null) {
      // Create new draft
      _editingSurvey = SurveyForm(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Untitled Survey',
        isActive: false, // Default to inactive
        questions: [],
        creatorId: creatorId,
      );
    } else {
      _editingSurvey = survey.copyWith(
        questions: List.from(survey.questions), // Deep copy list
      );
    }
    notifyListeners();
  }

  /// Updates the title of the editing survey
  void updateEditingSurveyTitle(String title) {
    if (_editingSurvey != null) {
      _editingSurvey!.title = title;
      notifyListeners();
    }
  }

  // --- Question Manipulation (Operates on _editingSurvey) ---

  void addSurveyQuestion(QuestionModel question) {
    if (_editingSurvey != null) {
      _editingSurvey!.questions.add(question);
      notifyListeners();
    }
  }

  void removeSurveyQuestion(int index) {
    if (_editingSurvey != null) {
      _editingSurvey!.questions.removeAt(index);
      // Auto-save logic removed for multi-survey, explicit save required on exit
      notifyListeners();
    }
  }

  void updateSingleSurveyQuestion(int index, QuestionModel question) {
    if (_editingSurvey != null) {
      _editingSurvey!.questions[index] = question;
      notifyListeners();
    }
  }

  void reorderSurveyQuestions(int oldIndex, int newIndex) {
    if (_editingSurvey != null) {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final QuestionModel item = _editingSurvey!.questions.removeAt(oldIndex);
      _editingSurvey!.questions.insert(newIndex, item);
      notifyListeners();
    }
  }

  /// Saves the current editing survey to the database
  Future<void> saveEditingSurvey() async {
    if (_editingSurvey != null) {
      await _repository.saveSurvey(_editingSurvey!);
      await loadSurveys(); // Refresh list using _currentUserId
    }
  }
  
  // Compatibility alias
  Future<void> saveSurveyQuestionsManually() async {
      await saveEditingSurvey();
  }

  /// Deletes a survey
  Future<void> deleteSurvey(String surveyId) async {
    await _repository.deleteSurvey(surveyId);
    await loadSurveys(); // Reloads using _currentUserId
  }

  /// Toggles a survey's active state
  Future<void> toggleSurveyActive(String surveyId) async {
    await _repository.activateSurvey(surveyId);
    await loadSurveys(); // Reloads using _currentUserId
  }

  // Survey Answer State
  Map<String, dynamic> _currentSurveyAnswers = {};
  Map<String, dynamic> get currentSurveyAnswers => Map.unmodifiable(_currentSurveyAnswers);

  void updateSurveyAnswer(String questionId, dynamic value) {
    _currentSurveyAnswers[questionId] = value;
    notifyListeners();
  }

  void resetSurveyAnswers() {
    _currentSurveyAnswers = {};
    notifyListeners();
  }

  /// Submits survey answers
  Future<void> submitSurveyAnswers(Map<String, dynamic> answers) async {
    await _repository.submitSurveyResponse(answers, ownerId: _currentUserId);
  }

  /// Submits the currently accumulated survey answers
  Future<void> submitCurrentAnswers() async {
    if (_currentSurveyAnswers.isEmpty) {
      throw Exception('Please answer at least one question');
    }
    await submitSurveyAnswers(Map.from(_currentSurveyAnswers));
    resetSurveyAnswers();
  }

  // Survey Responses state
  List<Map<String, dynamic>> _surveyResponses = [];
  List<Map<String, dynamic>> get surveyResponses => List.unmodifiable(_surveyResponses);

  /// Loads all survey responses for the current user
  Future<void> loadSurveyResponses() async {
    _surveyResponses = await _repository.getSurveyResponses(ownerId: _currentUserId);
    notifyListeners();
  }

  // Getters to expose state to UI (unmodifiable to prevent accidental mutation)
  List<FeedbackModel> get feedbackList => List.unmodifiable(_feedbackList);
  int get totalFeedback => _totalFeedback;
  Map<int, int> get ratingDistribution => Map.unmodifiable(_ratingDistribution);
  List<Map<String, dynamic>> get trendsData => List.unmodifiable(_trendsData);
  double get averageRating => _averageRating;
  bool get isLoading => _isLoading;

  int? get selectedMinRating => _selectedMinRating;
  int? get selectedMaxRating => _selectedMaxRating;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  /// Loads all feedback data from the repository
  /// Applies current filters and updates all state variables
  /// Notifies listeners when loading starts and completes
  /// Uses compute() to run calculations in a background isolate
  Future<void> loadFeedback() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Single Network Request: Load feedback list with current filters
    if (_currentUserId == null) {
      print('FeedbackProvider: Skipping loadFeedback because currentUserId is null');
      _isLoading = false;
      notifyListeners();
      return;
    }

      print('FeedbackProvider: Loading feedback with userId: $_currentUserId');
      _feedbackList = await _repository.getFeedback(
        minRating: _selectedMinRating,
        maxRating: _selectedMaxRating,
        startDate: _startDate,
        endDate: _endDate,
        userId: _currentUserId, // Filter by current user
      );
      print('FeedbackProvider: Loaded ${_feedbackList.length} feedback entries');
      
      if (_feedbackList.isNotEmpty) {
        print('DEBUG: First feedback item ownerId: "${_feedbackList.first.ownerId}" vs currentUserId: "$_currentUserId"');
      }

      // 2. Convert FeedbackModel list to JSON for serialization using existing toMap()
      final feedbackJsonList = _feedbackList.map((f) => f.toMap()).toList();

      // 3. Run calculations in background isolate using compute()
      final stats = await compute(calculateStats, feedbackJsonList);

      // 4. Update state with calculated results
      _totalFeedback = stats['totalFeedback'] as int;
      _averageRating = stats['averageRating'] as double;
      _ratingDistribution = (stats['ratingDistribution'] as Map).map(
        (key, value) => MapEntry(key as int, value as int),
      );
      _trendsData = (stats['trendsData'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

    } catch (e) {
      debugPrint('Error loading feedback: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submits a new feedback entry
  /// Returns true if successful, false otherwise
  /// Automatically reloads feedback after submission
  Future<bool> submitFeedback({
    String? name,
    String? email,
    required int rating,
    required String comments,
    String? surveyId,
  }) async {
    try {
      await _repository.submitFeedback(
        name: name,
        email: email,
        rating: rating,
        comments: comments,
        ownerId: _currentUserId, // Owner ID for manual admin submissions
        surveyId: surveyId,
      );
      // Reload feedback to include the new entry
      await loadFeedback();
      return true;
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      return false;
    }
  }

  /// Sets rating filter and reloads feedback
  /// minRating and maxRating can be null to remove filter
  void setRatingFilter(int? minRating, int? maxRating) {
    _selectedMinRating = minRating;
    _selectedMaxRating = maxRating;
    loadFeedback();
  }

  /// Sets date range filter and reloads feedback
  /// startDate and endDate can be null to remove filter
  void setDateFilter(DateTime? startDate, DateTime? endDate) {
    _startDate = startDate;
    _endDate = endDate;
    loadFeedback();
  }

  /// Clears all active filters and reloads feedback
  void clearFilters() {
    _selectedMinRating = null;
    _selectedMaxRating = null;
    _startDate = null;
    _endDate = null;
    loadFeedback();
  }
  
  /// Checks if any filters are currently active
  bool get hasActiveFilters => 
    _selectedMinRating != null || 
    _selectedMaxRating != null || 
    _startDate != null || 
    _endDate != null;

  /// Deletes a specific feedback entry by ID
  Future<void> deleteFeedback(String? id) async {
    if (id == null) return;
    try {
      await _repository.deleteFeedback(id);
      await loadFeedback(); // Reload list
    } catch (e) {
      debugPrint('Error deleting feedback: $e');
      rethrow;
    }
  }

  /// Deletes a specific survey response by ID
  Future<void> deleteSurveyResponse(String id) async {
    try {
       await _repository.deleteSurveyResponse(id);
       await loadSurveyResponses(); // Reload list (assuming getAllSurveyResponses is called somewhere or we need loadSurveyResponses)
    } catch (e) {
      debugPrint('Error deleting survey response: $e');
      rethrow;
    }
  }
}

