/// Example usage of the FeedbackAPI for programmatic feedback submission
/// 
/// This file demonstrates how other apps can integrate with the feedback system
/// to submit feedback programmatically.
library;

import 'feedback_api.dart';

Future<void> exampleUsage() async {
  // Initialize the API
  final api = FeedbackAPI();
  await api.initialize();

  // Submit feedback with all fields
  await api.submitFeedback(
    rating: 5,
    comments: 'This app is amazing! Great work!',
    name: 'John Doe',
    email: 'john@example.com',
  );

  // Submit feedback with minimal fields (name and email are optional)
  await api.submitFeedback(
    rating: 4,
    comments: 'Good app, but could use some improvements.',
  );

  // Get all feedback
  final allFeedback = await api.getFeedback();
  print('Total feedback: ${allFeedback.length}');

  // Get filtered feedback
  final highRatingFeedback = await api.getFeedback(
    minRating: 4,
  );
  print('High rating feedback: ${highRatingFeedback.length}');

  // Get statistics
  final stats = await api.getStatistics();
  print('Statistics: $stats');

  // Clean up when done
  await api.dispose();
}

