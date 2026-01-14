import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import '../data/models/feedback_model.dart';
import '../data/models/survey_models.dart';

/// Utility class for exporting data to CSV format
class CSVExporter {
  /// Exports feedback list to CSV file and shares it
  Future<void> exportFeedback(List<FeedbackModel> feedbackList, {String? userId}) async {
    if (feedbackList.isEmpty) {
      throw Exception('No feedback data to export');
    }

    final csvContent = _generateFeedbackCSV(feedbackList);
    final fileName = 'feedy_feedback_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    
    await _saveAndShare(csvContent, fileName);
  }

  /// Exports survey responses to CSV file and shares it
  Future<void> exportSurveyResponses(
    List<Map<String, dynamic>> responses,
    List<SurveyForm> surveys, {
    String? userId,
  }) async {
    if (responses.isEmpty) {
      throw Exception('No survey responses to export');
    }

    final csvContent = _generateSurveyResponsesCSV(responses, surveys);
    final fileName = 'feedy_survey_responses_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    
    await _saveAndShare(csvContent, fileName);
  }

  /// Exports all data (feedback + survey responses) to CSV
  Future<void> exportAllData({
    required List<FeedbackModel> feedbackList,
    required List<Map<String, dynamic>> surveyResponses,
    required List<SurveyForm> surveys,
    String? userId,
  }) async {
    final csvContent = StringBuffer();
    
    // Add feedback section
    csvContent.writeln('=== FEEDBACK RESPONSES ===');
    csvContent.writeln();
    csvContent.write(_generateFeedbackCSV(feedbackList));
    csvContent.writeln();
    csvContent.writeln();
    
    // Add survey responses section
    csvContent.writeln('=== SURVEY RESPONSES ===');
    csvContent.writeln();
    csvContent.write(_generateSurveyResponsesCSV(surveyResponses, surveys));
    
    final fileName = 'feedy_all_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    await _saveAndShare(csvContent.toString(), fileName);
  }

  /// Generates CSV content for feedback list
  String _generateFeedbackCSV(List<FeedbackModel> feedbackList) {
    final buffer = StringBuffer();
    
    // CSV Header
    buffer.writeln('ID,Name,Email,Rating,Comments,Date Created');
    
    // CSV Rows
    for (var feedback in feedbackList) {
      final id = _escapeCSV(feedback.id ?? '');
      final name = _escapeCSV(feedback.name ?? 'Anonymous');
      final email = _escapeCSV(feedback.email ?? '');
      final rating = feedback.rating.toString();
      final comments = _escapeCSV(feedback.comments);
      final date = DateFormat('yyyy-MM-dd HH:mm:ss').format(feedback.createdAt);
      
      buffer.writeln('$id,$name,$email,$rating,$comments,$date');
    }
    
    return buffer.toString();
  }

  /// Generates CSV content for survey responses
  String _generateSurveyResponsesCSV(
    List<Map<String, dynamic>> responses,
    List<SurveyForm> surveys,
  ) {
    final buffer = StringBuffer();
    
    // Create question ID to title mapping
    final questionTitleMap = <String, String>{};
    for (var survey in surveys) {
      for (var question in survey.questions) {
        questionTitleMap[question.id] = question.title;
      }
    }
    
    // Get all unique question IDs from all responses
    final allQuestionIds = <String>{}; 
    for (var response in responses) {
      // Handle both formats: answers wrapped or at root level
      Map<String, dynamic> answers;
      if (response.containsKey('answers') && response['answers'] is Map) {
        answers = _safeConvertMap(response['answers']);
      } else {
        // Extract answer fields from root (backwards compatibility)
        answers = <String, dynamic>{};
        final metadataFields = {'id', 'submittedAt', 'ownerId', 'userName', 'userEmail', 'answers'};
        response.forEach((key, value) {
          if (!metadataFields.contains(key)) {
            answers[key.toString()] = value;
          }
        });
      }
      allQuestionIds.addAll(answers.keys.map((k) => k.toString()));
    }
    
    // Build header row
    final headerRow = ['Response ID', 'Submitted Date', ...allQuestionIds.map((id) => questionTitleMap[id] ?? id)];
    buffer.writeln(headerRow.map(_escapeCSV).join(','));
    
    // Build data rows
    for (var response in responses) {
      final responseId = _escapeCSV(response['id']?.toString() ?? '');
      final submittedAt = response['submittedAt']?.toString() ?? '';
      final date = submittedAt.isNotEmpty
          ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.tryParse(submittedAt) ?? DateTime.now())
          : '';
      
      // Handle both formats: answers wrapped or at root level
      Map<String, dynamic> answers;
      if (response.containsKey('answers') && response['answers'] is Map) {
        answers = _safeConvertMap(response['answers']);
      } else {
        // Extract answer fields from root (backwards compatibility)
        answers = <String, dynamic>{};
        final metadataFields = {'id', 'submittedAt', 'ownerId', 'userName', 'userEmail', 'answers'};
        response.forEach((key, value) {
          if (!metadataFields.contains(key)) {
            answers[key.toString()] = value;
          }
        });
      }
      
      final row = [
        responseId,
        date,
        ...allQuestionIds.map((id) => _escapeCSV(answers[id]?.toString() ?? '')),
      ];
      
      buffer.writeln(row.join(','));
    }
    
    return buffer.toString();
  }

  /// Safely converts a dynamic map to Map<String, dynamic>
  /// Handles Firebase's _Map<Object?, Object?> type
  Map<String, dynamic> _safeConvertMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      // Convert all keys to String and values to dynamic
      return Map<String, dynamic>.fromEntries(
        value.entries.map((e) => MapEntry(
          e.key?.toString() ?? '',
          e.value,
        )),
      );
    }
    return {};
  }

  /// Escapes CSV values (handles commas, quotes, and newlines)
  String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      // Replace double quotes with two double quotes and wrap in quotes
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Saves CSV content to file and shares it
  Future<void> _saveAndShare(String content, String fileName) async {
    try {
      Directory directory;
      
      // Try to get Downloads directory for desktop, fallback to temp
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        try {
          // Try to get Downloads directory
          final homeDir = Platform.environment['HOME'] ?? 
                         Platform.environment['USERPROFILE'] ?? 
                         Platform.environment['HOMEPATH'];
          if (homeDir != null) {
            final downloadsPath = path.join(homeDir, 'Downloads');
            directory = Directory(downloadsPath);
            if (!await directory.exists()) {
              directory = await getTemporaryDirectory();
            }
          } else {
            directory = await getTemporaryDirectory();
          }
        } catch (_) {
          directory = await getTemporaryDirectory();
        }
      } else {
        // Mobile platforms
        directory = await getTemporaryDirectory();
      }
      
      final file = File(path.join(directory.path, fileName));
      await file.writeAsString(content);
      
      // Share the file
      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile],
        subject: 'Feedy Data Export',
        text: 'Feedy data export - $fileName',
      );
    } catch (e) {
      // Fallback: share as text if file operations fail
      await Share.share(content, subject: fileName);
      rethrow;
    }
  }
}
