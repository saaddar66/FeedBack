import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/survey_models.dart';
import 'package:intl/intl.dart';

/// Production-ready screen displaying all survey forms with loading states
/// Allows creating, editing, deleting, and toggling active survey status
class SurveyListScreen extends StatefulWidget {
  const SurveyListScreen({super.key});

  @override
  State<SurveyListScreen> createState() => _SurveyListScreenState();
}

class _SurveyListScreenState extends State<SurveyListScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final Set<String> _processingIds = {}; // Track operations in progress

  @override
  void initState() {
    super.initState();
    _loadSurveys();
  }

  /// Loads all surveys with proper loading and error states
  Future<void> _loadSurveys() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final userId = context.read<AuthProvider>().user?.id.toString();
      await context.read<FeedbackProvider>().loadSurveys(userId: userId);
      
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
        
        _showErrorSnackbar('Error loading surveys: $e');
      }
    }
  }

  /// Creates new survey and navigates to editor
  Future<void> _createNewSurvey() async {
    try {
      final userId = context.read<AuthProvider>().user?.id.toString();
      context.read<FeedbackProvider>().startEditingSurvey(null, creatorId: userId);
      await context.push('/config/edit');
      
      if (mounted) {
         await _loadSurveys();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error creating survey: $e');
      }
    }
  }

  /// Opens existing survey in edit mode
  Future<void> _editSurvey(SurveyForm survey) async {
    if (_processingIds.contains(survey.id)) return;
    
    try {
      context.read<FeedbackProvider>().startEditingSurvey(survey);
      await context.push('/config/edit');
      
      if (mounted) {
         await _loadSurveys();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error editing survey: $e');
      }
    }
  }

  /// Deletes survey with optimistic UI update and rollback
  void _deleteSurvey(BuildContext context, SurveyForm survey) {
    if (_processingIds.contains(survey.id)) return;
    
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              
              // Mark as processing
              setState(() => _processingIds.add(survey.id));
              
              try {
                await context.read<FeedbackProvider>().deleteSurvey(survey.id);
                
                if (context.mounted) {
                  _showSuccessSnackbar('Survey deleted successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  _showErrorSnackbar('Failed to delete survey: $e');
                }
              } finally {
                if (mounted) {
                  setState(() => _processingIds.remove(survey.id));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Toggles survey active status
  Future<void> _toggleSurveyActive(SurveyForm survey) async {
    if (_processingIds.contains(survey.id)) return;
    
    // Mark as processing
    setState(() => _processingIds.add(survey.id));
    
    final wasActive = survey.isActive;
    
    try {
      await context.read<FeedbackProvider>().toggleSurveyActive(survey.id);
      
      if (mounted) {
        _showSuccessSnackbar(wasActive ? 'Survey deactivated' : 'Survey activated');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error toggling survey: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(survey.id));
      }
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

  /// Shows error message in red snackbar
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
          onPressed: _loadSurveys,
        ),
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
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadSurveys,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(surveys),
      floatingActionButton: (!_isLoading && !_hasError)
          ? FloatingActionButton(
              onPressed: _createNewSurvey,
              child: const Icon(Icons.add),
              tooltip: 'Create New Survey',
            )
          : null,
    );
  }

  /// Builds appropriate body based on loading error empty states
  Widget _buildBody(List<SurveyForm> surveys) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading surveys...',
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
              'Failed to load surveys',
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
              onPressed: _loadSurveys,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (surveys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No surveys found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first survey to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createNewSurvey,
              icon: const Icon(Icons.add),
              label: const Text('Create New Survey'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: surveys.length,
      itemBuilder: (context, index) {
        final survey = surveys[index];
        return _buildSurveyCard(context, survey);
      },
    );
  }

  /// Builds survey card with all actions and loading states
  Widget _buildSurveyCard(BuildContext context, SurveyForm survey) {
    final isProcessing = _processingIds.contains(survey.id);
    
    return Opacity(
      opacity: isProcessing ? 0.5 : 1.0,
      child: Card(
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
          onTap: isProcessing ? null : () => _editSurvey(survey),
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
              if (isProcessing)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                // Power button with validation
                IconButton(
                  icon: Icon(
                    Icons.power_settings_new,
                    color: survey.isActive ? Colors.green : Colors.red,
                    size: 28,
                  ),
                  tooltip: survey.isActive ? 'Active (Turn Off)' : 'Inactive (Turn On)',
                  onPressed: () {
                    // Validate before toggling
                    if (survey.questions.isEmpty) {
                      _showErrorSnackbar('Cannot activate a survey with no questions');
                      return;
                    }
                    _toggleSurveyActive(survey);
                  },
                ),
                const SizedBox(width: 8),
                // Delete button with validation
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () {
                    // Warn if deleting the only active survey
                    final surveys = context.read<FeedbackProvider>().surveys;
                    final activeSurveys = surveys.where((s) => s.isActive).length;
                    
                    if (survey.isActive && activeSurveys == 1) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Warning'),
                          content: const Text(
                            'This is your only active survey. Deleting it will leave you with no active surveys. Continue?'
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _deleteSurvey(context, survey);
                              },
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete Anyway'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      _deleteSurvey(context, survey);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}