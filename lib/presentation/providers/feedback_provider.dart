import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../data/repositories/feedback_repository.dart';
import '../../data/models/feedback_model.dart';

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
      createdAt: DateTime.parse(json['createdAt'] as String),
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

  // Getters to expose state to UI
  List<FeedbackModel> get feedbackList => _feedbackList;
  int get totalFeedback => _totalFeedback;
  Map<int, int> get ratingDistribution => _ratingDistribution;
  List<Map<String, dynamic>> get trendsData => _trendsData;
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
      _feedbackList = await _repository.getFeedback(
        minRating: _selectedMinRating,
        maxRating: _selectedMaxRating,
        startDate: _startDate,
        endDate: _endDate,
      );

      // 2. Convert FeedbackModel list to JSON for serialization
      final feedbackJsonList = _feedbackList.map((f) => {
        'id': f.id,
        'name': f.name,
        'email': f.email,
        'rating': f.rating,
        'comments': f.comments,
        'createdAt': f.createdAt.toIso8601String(),
      }).toList();

      // 3. Run calculations in background isolate using compute()
      final stats = await compute(calculateStats, feedbackJsonList);

      // 4. Update state with calculated results
      _totalFeedback = stats['totalFeedback'] as int;
      _averageRating = stats['averageRating'] as double;
      _ratingDistribution = Map<int, int>.from(stats['ratingDistribution'] as Map);
      _trendsData = List<Map<String, dynamic>>.from(stats['trendsData'] as List);

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
  }) async {
    try {
      await _repository.submitFeedback(
        name: name,
        email: email,
        rating: rating,
        comments: comments,
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
}

