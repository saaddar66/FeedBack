import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/feedback_provider.dart';
import '../../../data/models/survey_models.dart';
import 'package:intl/intl.dart';

/// Screen displaying a list of all survey forms
/// Allows creating new surveys, editing existing ones, and toggling the active one
class SurveyListScreen extends StatefulWidget {
  const SurveyListScreen({super.key});

  @override
  State<SurveyListScreen> createState() => _SurveyListScreenState();
}

class _SurveyListScreenState extends State<SurveyListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedbackProvider>().loadSurveys();
    });
  }

  void _createNewSurvey() {
    // Initialize a new empty survey in the provider
    context.read<FeedbackProvider>().startEditingSurvey(null);
    // Navigate to the editor
    context.push('/config/edit');
  }

  void _editSurvey(SurveyForm survey) {
    // Load the existing survey into the provider's editing state
    context.read<FeedbackProvider>().startEditingSurvey(survey);
    // Navigate to the editor
    context.push('/config/edit');
  }

  void _deleteSurvey(BuildContext context, SurveyForm survey) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Survey'),
        content: Text('Are you sure you want to delete "${survey.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<FeedbackProvider>().deleteSurvey(survey.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surveys = context.watch<FeedbackProvider>().surveys;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey Configuration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: surveys.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Text(
                    'No surveys found.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _createNewSurvey,
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Survey'),
                  )
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: surveys.length,
              itemBuilder: (context, index) {
                final survey = surveys[index];
                return _buildSurveyCard(context, survey);
              },
            ),
      floatingActionButton: surveys.isNotEmpty
          ? FloatingActionButton(
              onPressed: _createNewSurvey,
              child: const Icon(Icons.add),
              tooltip: 'Create New Survey',
            )
          : null,
    );
  }

  Widget _buildSurveyCard(BuildContext context, SurveyForm survey) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: survey.isActive 
            ? const BorderSide(color: Colors.green, width: 2) 
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _editSurvey(survey),
        title: Text(
          survey.title.isEmpty ? 'Untitled Survey' : survey.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${survey.questions.length} Questions • Created ${DateFormat('MMM d, y').format(survey.createdAt)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Power Button (Toggle Active)
            IconButton(
              icon: Icon(
                Icons.power_settings_new,
                color: survey.isActive ? Colors.green : Colors.red,
                size: 28,
              ),
              tooltip: survey.isActive ? 'Active (Turn Off)' : 'Inactive (Turn On)',
              onPressed: () {
                // If already active, maybe we can turn it off? 
                // Or user requirement says "rest should remain red", usually means one MUST be active,
                // or turning "on" one auto-turns off others. 
                // Let's allow simple toggle ON. Turning OFF specifically means no survey active.
                context.read<FeedbackProvider>().toggleSurveyActive(survey.id);
              },
            ),
            const SizedBox(width: 8),
            // Delete Button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () => _deleteSurvey(context, survey),
            ),
          ],
        ),
      ),
    );
  }
}
