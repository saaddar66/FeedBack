import 'package:firebase_database/firebase_database.dart';
import '../models/feedback_model.dart';
import 'dart:math';

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

  void _generateMockData() {
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
  Future<List<FeedbackModel>> getAllFeedback({
    int? minRating,
    int? maxRating,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<FeedbackModel> feedbackList = [];

    if (_useMock) {
        feedbackList = List.from(_mockData);
    } else {
        if (_databaseRef == null) await initDatabase();
        // Recurse if init switched to mock, otherwise continue with firebase
        if (_useMock) return getAllFeedback(minRating: minRating, maxRating: maxRating, startDate: startDate, endDate: endDate);

        try {
            final snapshot = await _databaseRef!.get();
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

  /// Closes the database connection
  /// Firebase Realtime Database manages connections automatically
  /// This method is kept for interface compatibility
  Future<void> close() async {
    // Firebase Realtime Database doesn't require explicit closing
    // Connections are managed automatically
  }
}
