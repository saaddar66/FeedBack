import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../services/ai_service.dart';
import '../../providers/feedback_provider.dart';
import '../../../utils/pdf_exporter.dart';

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
  Map<String, String> _questionTitleCache = {}; // Cache question ID to title mapping

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
      final responses = context.read<FeedbackProvider>().surveyResponses;
      
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

      if (format == 'pdf') {
        try {
          await PDFExporter().exportAllData();
          if (mounted) _showSuccessSnackbar('PDF Report generated successfully');
        } catch (e) {
          if (mounted) _showErrorSnackbar('Failed to generate PDF: $e');
        }
        return;
      }

      // TODO: Implement actual export logic based on format
      _showSuccessSnackbar('Export feature coming soon!');
    } catch (e) {
      _showErrorSnackbar('Error exporting responses: $e');
    }
  }

  Future<void> _analyzeResponses() async {
    final responses = context.read<FeedbackProvider>().surveyResponses;
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
      appBar: AppBar(
        title: const Text('Survey Responses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
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
      body: _buildBody(responses),
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
    final answers = Map<String, dynamic>.from(response['answers'] as Map? ?? {});
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
}