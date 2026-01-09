import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../data/models/feedback_model.dart';
import '../data/models/survey_models.dart';


class AIService {
  // Retrieve API Key securely from environment variables
  static String get _apiKey => dotenv.env['MISTRAL_API_KEY'] ?? 'Key_not_set_yet';
  static const String _baseUrl = 'https://api.mistral.ai/v1/chat/completions';
  static const String _model = 'mistral-small-latest';

  /// Sends a prompt to Mistral AI and returns the generated text response
  Future<String> _generateResponse(String prompt) async {
    // Validate API Key existence before making request
    if (_apiKey == 'Key_not_set_yet') {
      return 'Mistral API Key not set. Please check your .env file.';
    }

    try {
      // Make HTTP POST request to Mistral API
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        // Construct JSON body with model, messages, and temperature
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.7, // Set creativity level
        }),
      );

      // Check for successful response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Extract content from the first choice
        return data['choices'][0]['message']['content'] as String;
      } else {
        return 'Mistral API Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Network Error: $e';
    }
  }

  /// Generates a summary report for a list of feedback items
  Future<String> analyzeFeedback(List<FeedbackModel> feedbackList) async {
    if (feedbackList.isEmpty) return 'No feedback data to analyze.';

    // Build the prompt context
    final buffer = StringBuffer();
    buffer.writeln('Analyze the following customer feedback and provide a report with:');
    buffer.writeln('1. Overall Sentiment Summary');
    buffer.writeln('2. Key Themes/Topics');
    buffer.writeln('3. Actionable Recommendations');
    buffer.writeln('\nFeedback Data:');
    
    // Process only the latest 50 items to fit token limits
    final itemsToAnalyze = feedbackList.length > 50 
        ? feedbackList.sublist(feedbackList.length - 50) 
        : feedbackList;

    // Append each feedback item to the prompt
    for (var f in itemsToAnalyze) {
      buffer.writeln('- Rating: ${f.rating}/5, Comment: "${f.comments}"');
    }

    // specific method call to get AI response
    return await _generateResponse(buffer.toString());
  }

  /// Generates insights from survey responses and their corresponding questions
  Future<String> analyzeSurveyResponses(
      List<Map<String, dynamic>> responses, List<SurveyForm> surveys) async {
    if (responses.isEmpty) return 'No survey responses to analyze.';

    // Create a lookup map for question IDs to titles
    final questionMap = <String, String>{};
    for (var s in surveys) {
      for (var q in s.questions) {
        questionMap[q.id] = q.title;
      }
    }

    // Build the prompt context for survey analysis
    final buffer = StringBuffer();
    buffer.writeln('Analyze the following survey responses and provide a report with:');
    buffer.writeln('1. Key Trends & Patterns');
    buffer.writeln('2. Common Answers per Question');
    buffer.writeln('3. Strategic Insights');
    buffer.writeln('\nResponse Data:');

    // Limit analysis to latest 50 responses
    final itemsToAnalyze = responses.length > 50 
        ? responses.sublist(responses.length - 50) 
        : responses;

    // Format each response with question titles and answers
    for (var r in itemsToAnalyze) {
      final answers = r['answers'] as Map<dynamic, dynamic>? ?? {};
      buffer.writeln('- Response:');
      answers.forEach((k, v) {
         final qTitle = questionMap[k] ?? 'Q';
         buffer.writeln('  $qTitle: $v');
      });
    }

    // Call AI to generate insight
    return await _generateResponse(buffer.toString());
  }
}
