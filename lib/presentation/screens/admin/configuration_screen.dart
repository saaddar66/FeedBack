import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../data/models/survey_models.dart';
import '../../providers/feedback_provider.dart';

/// Configuration screen for building dynamic survey questions
/// Allows adding, editing, and deleting survey questions
class ConfigurationScreen extends StatefulWidget {
  final String? titleOverride;
  final String? itemLabel;
  final String? addItemLabel;
  final bool hideSurveyOnlyFields;

  const ConfigurationScreen({
    super.key,
    this.titleOverride,
    this.itemLabel,
    this.addItemLabel,
    this.hideSurveyOnlyFields = false,
  });

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  late TextEditingController _surveyTitleController;
  // Menu-specific controllers
  late TextEditingController _taxRateController;
  late TextEditingController _serviceChargeController;

  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize title controller from provider's editing survey state
    final survey = context.read<FeedbackProvider>().editingSurvey;
    _surveyTitleController = TextEditingController(
      text: survey?.title ?? 'Untitled Survey'
    );
    // Initialize menu fields
    _taxRateController = TextEditingController(
      text: survey?.taxRate?.toString() ?? '',
    );
    _serviceChargeController = TextEditingController(
      text: survey?.serviceChargeRate?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    // Clean up title controller to prevent memory leaks
    _surveyTitleController.dispose();
    _taxRateController.dispose();
    _serviceChargeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Adds new empty question to the survey form
  void _addQuestion() {
    context.read<FeedbackProvider>().addSurveyQuestion(
      QuestionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '',
        type: QuestionType.text,
      ),
    );
    
    // Automatically scroll to bottom when new question is added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Removes question from survey at given index
  void _deleteQuestion(int index) {
    context.read<FeedbackProvider>().removeSurveyQuestion(index);
  }

  /// Handles drag and drop reordering of questions
  void _onReorder(int oldIndex, int newIndex) {
    context.read<FeedbackProvider>().reorderSurveyQuestions(oldIndex, newIndex);
  }

  /// Updates survey title in provider state
  void _updateSurveyTitle() {
    context.read<FeedbackProvider>().updateEditingSurveyTitle(_surveyTitleController.text);
  }

  void _updateTaxRate() {
    final value = double.tryParse(_taxRateController.text);
    context.read<FeedbackProvider>().updateEditingSurveyTaxRate(value);
  }

  void _updateServiceChargeRate() {
    final value = double.tryParse(_serviceChargeController.text);
    context.read<FeedbackProvider>().updateEditingSurveyServiceChargeRate(value);
  }

  /// Validates survey has title and at least one question
  bool _validateSurvey() {
    final title = _surveyTitleController.text.trim();
    final questions = context.read<FeedbackProvider>().surveyQuestions;

    if (title.isEmpty) {
      _showError('Please enter a survey title');
      return false;
    }

    if (questions.isEmpty) {
      _showError('Please add at least one question');
      return false;
    }

    // Check if any questions have empty titles
    for (int i = 0; i < questions.length; i++) {
      if (questions[i].title.trim().isEmpty) {
        _showError('Question ${i + 1} is missing a title');
        return false;
      }
    }

    return true;
  }

  /// Shows error message in red snackbar
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Shows success message in green snackbar
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Saves survey to Firebase and navigates back to list
  Future<void> _saveSurvey() async {
    if (_isSaving) return;
    
    if (!_validateSurvey()) return;

    setState(() => _isSaving = true);

    try {
      await context.read<FeedbackProvider>().saveEditingSurvey();
      
      // Small delay to ensure Firebase write completes
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        _showSuccess('Survey saved successfully');
        
        // Wait for snackbar to show before navigating
        await Future.delayed(const Duration(milliseconds: 800));
        
        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/config');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('Error saving survey: $e');
      }
    }
  }

  /// Handles back navigation with unsaved changes warning
  Future<void> _handleBackNavigation() async {
    // Show confirmation dialog if there are unsaved changes
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Do you want to save your changes before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      await _saveSurvey();
    } else if (shouldLeave == false) {
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/config');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = context.watch<FeedbackProvider>().surveyQuestions;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titleOverride ?? 'Edit Survey'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Survey',
              onPressed: _saveSurvey,
            ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isSaving ? null : _handleBackNavigation,
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
              decoration: InputDecoration(
                labelText: widget.titleOverride ?? 'Survey Title',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.title),
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              onChanged: (_) => _updateSurveyTitle(),
              enabled: !_isSaving,
            ),
          ),
          
          // Menu-Specific Fields (Tax & Service Charge)
          if (widget.hideSurveyOnlyFields) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _taxRateController,
                      decoration: const InputDecoration(
                        labelText: 'Tax Rate (%)',
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _updateTaxRate(),
                      enabled: !_isSaving,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _serviceChargeController,
                      decoration: const InputDecoration(
                        labelText: 'Service Charge (%)',
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _updateServiceChargeRate(),
                      enabled: !_isSaving,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          Expanded(
            child: questions.isEmpty
                ? _buildEmptyState()
                : ReorderableListView(
                    scrollController: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    onReorder: _onReorder,
                    children: questions.asMap().entries.map((entry) {
                      return _QuestionCard(
                        key: ValueKey(entry.value.id),
                        index: entry.key,
                        question: entry.value,
                        onDelete: () => _deleteQuestion(entry.key),
                        isDisabled: _isSaving,
                        itemLabel: widget.itemLabel,
                        isMenuMode: widget.hideSurveyOnlyFields,
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : _addQuestion,
        backgroundColor: _isSaving ? Colors.grey : Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Builds empty state when no questions exist yet
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
          const SizedBox(height: 16),
          Text(
            'No ${widget.itemLabel?.toLowerCase() ?? 'questions'} yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first ${widget.itemLabel?.toLowerCase() ?? 'question'}',
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
  final bool isDisabled;
  final String? itemLabel;
  final bool isMenuMode;

  const _QuestionCard({
    required Key key,
    required this.index,
    required this.question,
    required this.onDelete,
    this.isDisabled = false,
    this.itemLabel,
    this.isMenuMode = false,
  }) : super(key: key);

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late List<TextEditingController> _optionControllers;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing question data
    _titleController = TextEditingController(text: widget.question.title);
    _priceController = TextEditingController(
      text: widget.question.price?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.question.description ?? '',
    );
    _isAvailable = widget.question.isAvailable;
    _optionControllers = widget.question.options
        .map((opt) => TextEditingController(text: opt))
        .toList();
  }

  @override
  void dispose() {
    // Dispose all controllers to prevent memory leaks
    _titleController.dispose();
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    _optionControllers.clear();
    super.dispose();
  }

  /// Saves question changes to provider state
  void _saveQuestion() {
    final provider = context.read<FeedbackProvider>();
    final updatedQuestion = widget.question.copyWith(
      title: _titleController.text,
      price: double.tryParse(_priceController.text),
      description: _descriptionController.text,
      isAvailable: _isAvailable,
      options: _optionControllers.map((c) => c.text).toList(),
    );
    provider.updateSingleSurveyQuestion(widget.index, updatedQuestion);
  }

  void _toggleAvailable(bool value) {
    setState(() => _isAvailable = value);
    _saveQuestion();
  }

  /// Updates question type and saves to provider
  void _updateType(QuestionType? newType) {
    if (newType == null) return;
    final provider = context.read<FeedbackProvider>();
    final updatedQuestion = widget.question.copyWith(type: newType);
    provider.updateSingleSurveyQuestion(widget.index, updatedQuestion);
  }

  /// Adds new empty option to choice questions
  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  /// Removes option at given index from question
  void _removeOption(int index) {
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
    _saveQuestion();
  }

  /// Checks if question type requires option choices
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
            // Question number and delete button header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.itemLabel ?? 'Question'} ${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Row(
                  children: [
                    if (widget.isMenuMode) ...[
                      const Text('Available', style: TextStyle(fontSize: 12)),
                      Switch(
                        value: _isAvailable,
                        onChanged: widget.isDisabled ? null : _toggleAvailable,
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: widget.isDisabled ? null : widget.onDelete,
                      tooltip: 'Delete ${widget.itemLabel?.toLowerCase() ?? 'question'}',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Question title input field with auto save
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '${widget.itemLabel ?? 'Question'} Title',
                border: const OutlineInputBorder(),
                hintText: 'Enter your ${widget.itemLabel?.toLowerCase() ?? 'question'} here...',
              ),
              onChanged: (_) => _saveQuestion(),
              enabled: !widget.isDisabled,
            ),
            const SizedBox(height: 16),

            // Price Field (Menu Mode Only)
            if (widget.isMenuMode) ...[
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ', 
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _saveQuestion(),
                enabled: !widget.isDisabled,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Additional Details (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Ingredients, Allergens, Spice Level',
                ),
                maxLines: 2,
                onChanged: (_) => _saveQuestion(),
                enabled: !widget.isDisabled,
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Question type dropdown selector
              DropdownButtonFormField<QuestionType>(
                initialValue: widget.question.type,
                decoration: InputDecoration(
                  labelText: '${widget.itemLabel ?? 'Question'} Type',
                  border: const OutlineInputBorder(),
                ),
                items: QuestionType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getQuestionTypeLabel(type)),
                  );
                }).toList(),
                onChanged: widget.isDisabled ? null : _updateType,
              ),
              
              // Options section for single and multiple choice questions
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
                            enabled: !widget.isDisabled,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: widget.isDisabled ? null : () => _removeOption(entry.key),
                        ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: widget.isDisabled ? null : _addOption,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Option'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Returns human readable label for question type enum
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