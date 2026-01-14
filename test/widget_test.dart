// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feedy/main.dart';
import 'package:feedy/data/database/database_helper.dart';
import 'package:feedy/data/repositories/feedback_repository.dart';
import 'package:feedy/domain/usecases/submit_feedback_usecase.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Initialize dependencies
    final databaseHelper = DatabaseHelper.instance;
    final feedbackRepository = FeedbackRepository(databaseHelper);
    final submitFeedbackUseCase = SubmitFeedbackUseCase(feedbackRepository);

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(
      feedbackRepository: feedbackRepository, 
      submitFeedbackUseCase: submitFeedbackUseCase
    ));

    // Verify that the app launches (Smoke test)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
