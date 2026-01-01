import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Enum representing the type of question
enum QuestionType {
  singleChoice,
  multipleChoice,
  openEnded,
}

/// Enum representing the type of answer expected
enum AnswerType {
  rating,
  text,
  yesNo,
}

/// Model class representing a survey question
class QuestionModel {
  final String id;
  String title;
  QuestionType type;
  AnswerType answerType;

  QuestionModel({
    required this.id,
    required this.title,
    required this.type,
    required this.answerType,
  });

  /// Creates a copy of the question with updated values
  QuestionModel copyWith({
    String? title,
    QuestionType? type,
    AnswerType? answerType,
  }) {
    return QuestionModel(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      answerType: answerType ?? this.answerType,
    );
  }
}

/// Configuration screen for building dynamic survey questions
/// Allows adding, editing, and deleting survey questions
class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  // List of questions maintained in state
  final List<QuestionModel> _questions = [];

  /// Adds a new empty question to the list
  void _addQuestion() {
    setState(() {
      _questions.add(
        QuestionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: '',
          type: QuestionType.singleChoice,
          answerType: AnswerType.text,
        ),
      );
    });
  }

  /// Removes a question from the list at the given index
  void _deleteQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  /// Updates a question at the given index
  void _updateQuestion(int index, QuestionModel updatedQuestion) {
    setState(() {
      _questions[index] = updatedQuestion;
    });
  }

  /// Handles list reordering
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final QuestionModel item = _questions.removeAt(oldIndex);
      _questions.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey Configuration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
          tooltip: 'Back',
        ),
      ),
      body: _questions.isEmpty
          ? _buildEmptyState()
          : ReorderableListView(
              padding: const EdgeInsets.all(16.0),
              onReorder: _onReorder,
              children: _questions.map((question) {
                final index = _questions.indexOf(question);
                return _buildQuestionItem(index, question.id);
              }).toList(),
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

  /// Builds a question item with all its controls
  Widget _buildQuestionItem(int index, String id) {
    final question = _questions[index];

    return Card(
      key: ValueKey(id),
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
                  'Question ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteQuestion(index),
                  tooltip: 'Delete question',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Title TextFormField
            TextFormField(
              initialValue: question.title,
              decoration: const InputDecoration(
                labelText: 'Question Title',
                border: OutlineInputBorder(),
                hintText: 'Enter your question here...',
              ),
              onChanged: (value) {
                _updateQuestion(
                  index,
                  question.copyWith(title: value),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // QuestionType Dropdown
            DropdownButtonFormField<QuestionType>(
              value: question.type,
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
              onChanged: (value) {
                if (value != null) {
                  _updateQuestion(
                    index,
                    question.copyWith(type: value),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            
            // AnswerType Dropdown
            DropdownButtonFormField<AnswerType>(
              value: question.answerType,
              decoration: const InputDecoration(
                labelText: 'Answer Type',
                border: OutlineInputBorder(),
              ),
              items: AnswerType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getAnswerTypeLabel(type)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _updateQuestion(
                    index,
                    question.copyWith(answerType: value),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Save the question (already in state, just show confirmation)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Question saved successfully!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue,
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a human-readable label for QuestionType
  String _getQuestionTypeLabel(QuestionType type) {
    switch (type) {
      case QuestionType.singleChoice:
        return 'Single Choice';
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.openEnded:
        return 'Open Ended';
    }
  }

  /// Returns a human-readable label for AnswerType
  String _getAnswerTypeLabel(AnswerType type) {
    switch (type) {
      case AnswerType.rating:
        return 'Rating';
      case AnswerType.text:
        return 'Text';
      case AnswerType.yesNo:
        return 'Yes/No';
    }
  }
}

