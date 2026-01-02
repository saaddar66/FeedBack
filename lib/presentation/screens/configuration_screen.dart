import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/models/survey_models.dart';
import '../providers/feedback_provider.dart';

/// Configuration screen for building dynamic survey questions
/// Allows adding, editing, and deleting survey questions
class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  // Controller for the survey form title
  late TextEditingController _surveyTitleController;

  @override
  void initState() {
    super.initState();
    // Do not load questions here, they are passed by the list screen into the provider's editing state
    // Just initialize the title controller from the provider's editing survey
    final survey = context.read<FeedbackProvider>().editingSurvey;
    _surveyTitleController = TextEditingController(
      text: survey?.title ?? 'Untitled Survey'
    );
  }

  @override
  void dispose() {
    // Save questions when navigating away from configuration screen
    context.read<FeedbackProvider>().saveSurveyQuestionsManually();
    _surveyTitleController.dispose();
    super.dispose();
  }

  /// Adds a new empty question to the list
  void _addQuestion() {
     context.read<FeedbackProvider>().addSurveyQuestion(
      QuestionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '',
        type: QuestionType.text,
      ),
    );
  }

  /// Removes a question from the list at the given index
  void _deleteQuestion(int index) {
    context.read<FeedbackProvider>().removeSurveyQuestion(index);
  }

  /// Handles list reordering
  void _onReorder(int oldIndex, int newIndex) {
    context.read<FeedbackProvider>().reorderSurveyQuestions(oldIndex, newIndex);
  }

  /// Updates survey title in provider
  void _updateSurveyTitle() {
    context.read<FeedbackProvider>().updateEditingSurveyTitle(_surveyTitleController.text);
  }

  @override
  Widget build(BuildContext context) {
    // Consume questions from Provider
    final questions = context.watch<FeedbackProvider>().surveyQuestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Survey'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // Save before navigating
            await context.read<FeedbackProvider>().saveSurveyQuestionsManually();
            if (context.mounted) {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/config'); // Go back to list
              }
            }
          },
          tooltip: 'Back',
        ),
      ),
      body: Column(
        children: [
          // Survey Title Input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _surveyTitleController,
              decoration: const InputDecoration(
                labelText: 'Survey Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              onChanged: (_) => _updateSurveyTitle(),
            ),
          ),
          
          Expanded(
            child: questions.isEmpty
                ? _buildEmptyState()
                : ReorderableListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    onReorder: _onReorder,
                    children: questions.asMap().entries.map((entry) {
                      return _QuestionCard(
                        key: ValueKey(entry.value.id),
                        index: entry.key,
                        question: entry.value,
                        onDelete: () => _deleteQuestion(entry.key),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addQuestion,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Builds the empty state when no questions exist
  Widget _buildEmptyState() {
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
          Text(
            'No questions yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first question',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stateful widget for each question card to manage its own controllers
class _QuestionCard extends StatefulWidget {
  final int index;
  final QuestionModel question;
  final VoidCallback onDelete;

  const _QuestionCard({
    required Key key,
    required this.index,
    required this.question,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late TextEditingController _titleController;
  late List<TextEditingController> _optionControllers;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.question.title);
    _optionControllers = widget.question.options
        .map((opt) => TextEditingController(text: opt))
        .toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    _optionControllers.clear(); // Safety: clear list after disposal
    super.dispose();
  }

  void _saveQuestion() {
    final provider = context.read<FeedbackProvider>();
    final updatedQuestion = widget.question.copyWith(
      title: _titleController.text,
      options: _optionControllers.map((c) => c.text).toList(),
    );
    provider.updateSingleSurveyQuestion(widget.index, updatedQuestion);
  }

  void _updateType(QuestionType? newType) {
    if (newType == null) return;
    final provider = context.read<FeedbackProvider>();
    final updatedQuestion = widget.question.copyWith(type: newType);
    provider.updateSingleSurveyQuestion(widget.index, updatedQuestion);
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
    _saveQuestion();
  }

  bool _needsOptions() {
    return widget.question.type == QuestionType.singleChoice ||
        widget.question.type == QuestionType.multipleChoice;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question number header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDelete,
                  tooltip: 'Delete question',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Title TextField with controller
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Question Title',
                border: OutlineInputBorder(),
                hintText: 'Enter your question here...',
              ),
              onChanged: (_) => _saveQuestion(),
            ),
            const SizedBox(height: 16),
            
            // QuestionType Dropdown
            DropdownButtonFormField<QuestionType>(
              value: widget.question.type,
              decoration: const InputDecoration(
                labelText: 'Question Type',
                border: OutlineInputBorder(),
              ),
              items: QuestionType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getQuestionTypeLabel(type)),
                );
              }).toList(),
              onChanged: _updateType,
            ),
            
            // Options section for choice questions
            if (_needsOptions()) ...[
              const SizedBox(height: 16),
              const Text(
                'Options:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._optionControllers.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: entry.value,
                          decoration: InputDecoration(
                            labelText: 'Option ${entry.key + 1}',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => _saveQuestion(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeOption(entry.key),
                      ),
                    ],
                  ),
                );
              }).toList(),
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add),
                label: const Text('Add Option'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Returns a human-readable label for QuestionType
  String _getQuestionTypeLabel(QuestionType type) {
    switch (type) {
      case QuestionType.text:
        return 'Text';
      case QuestionType.rating:
        return 'Rating';
      case QuestionType.singleChoice:
        return 'Single Choice';
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
    }
  }
}
