import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../services/ai_service.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../utils/pdf_exporter.dart';
import '../../../utils/csv_exporter.dart';

/// Production-ready screen displaying all survey responses with proper states
/// Shows expandable cards with question answers and submission timestamps
class SurveyResponseListScreen extends StatefulWidget {
  const SurveyResponseListScreen({super.key});

  @override
  State<SurveyResponseListScreen> createState() => _SurveyResponseListScreenState();
}

class _SurveyResponseListScreenState extends State<SurveyResponseListScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final Map<String, String> _questionTitleCache = {}; // Cache question ID to title mapping
  String? _selectedSurveyId; // Selected survey ID for filtering

  @override
  void initState() {
    super.initState();
    _loadResponses();
  }

  /// Loads survey responses and builds question title cache
  Future<void> _loadResponses() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Set current user context before loading data
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        context.read<FeedbackProvider>().setCurrentUser(userId);
      }
      
      await context.read<FeedbackProvider>().loadSurveyResponses();
      
      // Build question title cache from surveys
      _buildQuestionTitleCache();
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        
        _showErrorSnackbar('Error loading responses: $e');
      }
    }
  }

  /// Builds cache mapping question IDs to their titles
  void _buildQuestionTitleCache() {
    final surveys = context.read<FeedbackProvider>().surveys;
    _questionTitleCache.clear();
    
    for (final survey in surveys) {
      for (final question in survey.questions) {
        _questionTitleCache[question.id] = question.title;
      }
    }
  }

  /// Determines which survey a response belongs to by matching question IDs
  String? _getSurveyIdForResponse(Map<String, dynamic> response) {
    final surveys = context.read<FeedbackProvider>().surveys;
    
    // Get answer keys from response
    Map<String, dynamic> answers;
    if (response.containsKey('answers') && response['answers'] is Map) {
      answers = Map<String, dynamic>.from(response['answers'] as Map);
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
    
    final answerQuestionIds = answers.keys.toSet();
    
    // Find the survey that contains all or most of the question IDs from the response
    for (final survey in surveys) {
      final surveyQuestionIds = survey.questions.map((q) => q.id).toSet();
      
      // Check if all answer question IDs are in this survey
      if (answerQuestionIds.isNotEmpty && 
          answerQuestionIds.every((id) => surveyQuestionIds.contains(id))) {
        return survey.id;
      }
    }
    
    return null; // Could not match to any survey
  }

  /// Filters responses by selected survey
  List<Map<String, dynamic>> _getFilteredResponses(List<Map<String, dynamic>> responses) {
    if (_selectedSurveyId == null) {
      return responses;
    }
    
    return responses.where((response) {
      final surveyId = _getSurveyIdForResponse(response);
      return surveyId == _selectedSurveyId;
    }).toList();
  }

  /// Deletes single response with confirmation dialog
  Future<void> _deleteResponse(String responseId, int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Response'),
        content: Text('Are you sure you want to delete Response #${index + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await context.read<FeedbackProvider>().deleteSurveyResponse(responseId);
      
      if (mounted) {
        _showSuccessSnackbar('Response deleted successfully');
        await _loadResponses(); // Reload to update list
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error deleting response: $e');
      }
    }
  }

  /// Exports all responses to CSV or JSON format
  Future<void> _exportResponses() async {
    try {
      final allResponses = context.read<FeedbackProvider>().surveyResponses;
      final responses = _getFilteredResponses(allResponses);
      
      if (responses.isEmpty) {
        _showErrorSnackbar('No responses to export');
        return;
      }

      // Show export options dialog
      final format = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export Responses'),
          content: const Text('Choose export format:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('csv'),
              child: const Text('CSV'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('pdf'),
              child: const Text('PDF'),
            ),
          ],
        ),
      );

      try {
        if (format == 'pdf') {
          final userId = context.read<AuthProvider>().user?.id;
          await PDFExporter().exportAllData(userId: userId);
          if (mounted) _showSuccessSnackbar('PDF Report generated successfully');
        } else if (format == 'csv') {
          final surveys = context.read<FeedbackProvider>().surveys;
          final userId = context.read<AuthProvider>().user?.id;
          await CSVExporter().exportSurveyResponses(responses, surveys, userId: userId);
          if (mounted) _showSuccessSnackbar('CSV file exported successfully');
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar('Failed to export: $e');
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error exporting responses: $e');
    }
  }

  Future<void> _analyzeResponses() async {
    final allResponses = context.read<FeedbackProvider>().surveyResponses;
    final responses = _getFilteredResponses(allResponses);
    final surveys = context.read<FeedbackProvider>().surveys;
    
    if (responses.isEmpty) {
      _showErrorSnackbar('No responses to analyze');
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final aiService = AIService();
      final report = await aiService.analyzeSurveyResponses(responses, surveys);
      
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading

      // Show Report
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple.shade300),
              const SizedBox(width: 8),
              const Text('AI Insights'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: MarkdownBody(data: report),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackbar('AI Analysis Failed: $e');
    }
  }

  /// Shows success message in green snackbar
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows error message in red snackbar with retry
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadResponses,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responses = context.watch<FeedbackProvider>().surveyResponses;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Survey Responses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          // Filter button
          if (!_isLoading)
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color: _selectedSurveyId != null ? Colors.blue : null,
              ),
              onPressed: _showFilterDialog,
              tooltip: 'Filter by Survey',
            ),
          // AI Analyze button
            if (!_isLoading && responses.isNotEmpty)
              IconButton(
                icon: Icon(Icons.auto_awesome, color: Colors.purple.shade300),
                onPressed: _analyzeResponses,
                tooltip: 'Analyze with AI',
              ),
            // Export button
            if (!_isLoading && responses.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _exportResponses,
                tooltip: 'Export Responses',
              ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadResponses,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chip bar
          if (_selectedSurveyId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.filter_alt, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filtered by: ${_getSelectedSurveyTitle()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedSurveyId = null;
                      });
                    },
                    child: Text(
                      'Clear',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBody(_getFilteredResponses(responses))),
        ],
      ),
    );
  }

  /// Builds appropriate body based on loading error empty states
  Widget _buildBody(List<Map<String, dynamic>> responses) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading responses...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load responses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadResponses,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (responses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No survey responses yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Responses will appear here once users submit surveys',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: responses.length,
      itemBuilder: (context, index) {
        final response = responses[index];
        return _buildResponseCard(response, index);
      },
    );
  }

  /// Builds expandable card for each survey response
  Widget _buildResponseCard(Map<String, dynamic> response, int index) {
    // Handle both formats: answers wrapped in 'answers' or at root level
    Map<String, dynamic> answers;
    if (response.containsKey('answers') && response['answers'] is Map) {
      answers = Map<String, dynamic>.from(response['answers'] as Map);
    } else {
      // If no 'answers' key, extract answer fields from root (backwards compatibility)
      answers = <String, dynamic>{};
      final metadataFields = {'id', 'submittedAt', 'ownerId', 'userName', 'userEmail', 'answers'};
      response.forEach((key, value) {
        if (!metadataFields.contains(key)) {
          answers[key] = value;
        }
      });
    }
    final responseId = response['id'] as String? ?? '';
    final submittedAtString = response['submittedAt'] as String?;
    final userName = response['userName'] as String?;
    final userEmail = response['userEmail'] as String?;
    
    final submittedAt = submittedAtString != null 
        ? DateTime.tryParse(submittedAtString) ?? DateTime.now()
        : DateTime.now();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          userName ?? 'Response #${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userEmail != null)
              Text(
                userEmail,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            Text(
              DateFormat('MMM d, y • h:mm a').format(submittedAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _deleteResponse(responseId, index),
          tooltip: 'Delete Response',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: answers.isEmpty
                ? const Center(
                    child: Text(
                      'No answers recorded',
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 8),
                      ...answers.entries.map((entry) => _buildAnswerRow(entry)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds single answer row with question and response
  Widget _buildAnswerRow(MapEntry<String, dynamic> entry) {
    final questionTitle = _questionTitleCache[entry.key] ?? 'Question';
    final answer = _formatAnswer(entry.value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            width: double.infinity,
            child: Text(
              answer,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Formats answer value for display handles multiple types
  String _formatAnswer(dynamic value) {
    if (value == null) return 'No answer';
    
    if (value is List) {
      return value.isEmpty ? 'No selections' : value.join(', ');
    }
    
    if (value is Map) {
      return value.toString();
    }
    
    final stringValue = value.toString();
    return stringValue.isEmpty ? 'No answer' : stringValue;
  }

  /// Shows filter dialog to select a survey
  void _showFilterDialog() {
    final surveys = context.read<FeedbackProvider>().surveys;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Options',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                
                // Filter by survey section
                const Text('Filter by Survey', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                // All Surveys option
                ChoiceChip(
                  label: const Text('All Surveys'),
                  selected: _selectedSurveyId == null,
                  onSelected: (selected) {
                    setModalState(() => _selectedSurveyId = null);
                    setState(() => _selectedSurveyId = null);
                  },
                ),
                const SizedBox(height: 8),
                
                // Individual survey options
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: surveys.map((survey) => ChoiceChip(
                    label: Text(
                      survey.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: _selectedSurveyId == survey.id,
                    onSelected: (selected) {
                      setModalState(() => _selectedSurveyId = survey.id);
                      setState(() => _selectedSurveyId = survey.id);
                    },
                  )).toList(),
                ),
                const SizedBox(height: 24),
                
                // Apply button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Gets the title of the selected survey
  String _getSelectedSurveyTitle() {
    if (_selectedSurveyId == null) return '';
    
    final surveys = context.read<FeedbackProvider>().surveys;
    final survey = surveys.firstWhere(
      (s) => s.id == _selectedSurveyId,
      orElse: () => surveys.first,
    );
    return survey.title;
  }
}