import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/feedback_provider.dart';
import '../../../data/models/survey_models.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  // Map to store answers: key is question ID, value is the answer
  final Map<String, dynamic> _answers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedbackProvider>().loadActiveSurvey();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch for changes in configured questions
    final questions = context.watch<FeedbackProvider>().activeSurveyQuestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Button to go to the original General Feedback form
              ElevatedButton.icon(
                onPressed: () => context.go('/feedback'),
                icon: const Icon(Icons.feedback_outlined),
                label: const Text('Submit General Feedback'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade50,
                  foregroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  side: const BorderSide(color: Colors.indigo, width: 1),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              const Text(
                'Please answer the following questions:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              if (questions.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No active survey available at the moment.',
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ),
                )
              else
                ...questions.map((q) => _buildQuestionWidget(q)),
                
              const SizedBox(height: 32),
              
              if (questions.isNotEmpty)
                ElevatedButton(
                  onPressed: _submitSurvey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Submit Survey',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionWidget(QuestionModel question) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.title.isNotEmpty ? question.title : 'Untitled Question',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildAnswerInput(question),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerInput(QuestionModel question) {
    switch (question.type) {
      case QuestionType.text:
        return TextField(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Your answer...',
          ),
          maxLines: 3,
          onChanged: (value) {
            setState(() {
              _answers[question.id] = value;
            });
          },
        );
      
      case QuestionType.rating:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final rating = index + 1;
            final isSelected = (_answers[question.id] ?? 0) >= rating;
            return IconButton(
              icon: Icon(
                isSelected ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32,
              ),
              onPressed: () {
                setState(() {
                  _answers[question.id] = rating;
                });
              },
            );
          }),
        );

      case QuestionType.singleChoice:
        if (question.options.isEmpty) {
          return const Text(
            'No options configured for this question',
            style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
          );
        }
        return Column(
          children: question.options.map((option) {
            return RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: _answers[question.id],
              onChanged: (value) {
                setState(() {
                  _answers[question.id] = value;
                });
              },
            );
          }).toList(),
        );

      case QuestionType.multipleChoice:
        if (question.options.isEmpty) {
          return const Text(
            'No options configured for this question',
            style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
          );
        }
        // Initialize as empty list if not set
        final selectedOptions = _answers[question.id] as List<String>? ?? [];
        
        return Column(
          children: question.options.map((option) {
            return CheckboxListTile(
              title: Text(option),
              value: selectedOptions.contains(option),
              onChanged: (checked) {
                setState(() {
                  final currentList = List<String>.from(selectedOptions);
                  if (checked == true) {
                    currentList.add(option);
                  } else {
                    currentList.remove(option);
                  }
                  _answers[question.id] = currentList;
                });
              },
            );
          }).toList(),
        );

      default:
        return const Text('Unsupported question type');
    }
  }

  void _submitSurvey() async {
    if (_answers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer at least one question')),
      );
      return;
    }

    try {
      await context.read<FeedbackProvider>().submitSurveyAnswers(_answers);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Survey submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      setState(() {
        _answers.clear();
      });
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting survey: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
