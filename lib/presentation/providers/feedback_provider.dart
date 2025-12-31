import 'package:flutter/foundation.dart';
import '../../data/repositories/feedback_repository.dart';
import '../../data/models/feedback_model.dart';

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

      // 2. In-Memory Calculations (Avoids 4 extra network requests)
      
      // Calculate Total Count
      _totalFeedback = _feedbackList.length;

      // Calculate Average Rating
      if (_feedbackList.isEmpty) {
        _averageRating = 0.0;
      } else {
        final sum = _feedbackList.fold(0, (prev, element) => prev + element.rating);
        _averageRating = sum / _feedbackList.length;
      }

      // Calculate Rating Distribution
      _ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (var f in _feedbackList) {
        _ratingDistribution[f.rating] = (_ratingDistribution[f.rating] ?? 0) + 1;
      }

      // Calculate Trends Data (Group by YYYY-MM-DD)
      final Map<String, List<FeedbackModel>> groupedByDate = {};
      for (var f in _feedbackList) {
        final dateKey = f.createdAt.toIso8601String().substring(0, 10);
        groupedByDate.putIfAbsent(dateKey, () => []).add(f);
      }

      _trendsData = [];
      groupedByDate.forEach((date, feedbacks) {
        final count = feedbacks.length;
        final sum = feedbacks.fold(0, (prev, element) => prev + element.rating);
        final avgRating = sum / count;
        
        _trendsData.add({
          'date': date,
          'count': count,
          'avg_rating': avgRating,
        });
      });
      
      // Sort trends by date
      _trendsData.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

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

