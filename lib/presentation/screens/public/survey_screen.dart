import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/feedback_provider.dart';
import '../../../data/models/survey_models.dart';
import '../../widgets/mic_button.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get ownerId from query parameters to load the correct user's survey
      final state = GoRouterState.of(context);
      final ownerId = state.uri.queryParameters['uid'];
      
      context.read<FeedbackProvider>().loadActiveSurvey(userId: ownerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch for changes in configured questions and answers
    final provider = context.watch<FeedbackProvider>();
    final questions = provider.activeSurveyQuestions;
    final answers = provider.currentSurveyAnswers;

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
                onPressed: () {
                  // Preserve the uid query parameter when navigating to feedback
                  final state = GoRouterState.of(context);
                  final uid = state.uri.queryParameters['uid'];
                  if (uid != null && uid.isNotEmpty) {
                    context.go('/feedback?uid=$uid');
                  } else {
                    context.go('/feedback');
                  }
                },
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
    final answers = context.watch<FeedbackProvider>().currentSurveyAnswers;

    switch (question.type) {
      case QuestionType.text:
        return _SurveyTextField(
          initialValue: answers[question.id] as String? ?? '',
          onChanged: (value) {
            context.read<FeedbackProvider>().updateSurveyAnswer(question.id, value);
          },
        );
      
      case QuestionType.rating:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final rating = index + 1;
            final isSelected = (answers[question.id] ?? 0) >= rating;
            return IconButton(
              icon: Icon(
                isSelected ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32,
              ),
              onPressed: () {
                context.read<FeedbackProvider>().updateSurveyAnswer(question.id, rating);
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
              groupValue: answers[question.id],
              onChanged: (value) {
                context.read<FeedbackProvider>().updateSurveyAnswer(question.id, value);
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
        final selectedOptions = answers[question.id] as List<String>? ?? [];
        
        return Column(
          children: question.options.map((option) {
            return CheckboxListTile(
              title: Text(option),
              value: selectedOptions.contains(option),
              onChanged: (checked) {
                final currentList = List<String>.from(selectedOptions);
                if (checked == true) {
                  currentList.add(option);
                } else {
                  currentList.remove(option);
                }
                context.read<FeedbackProvider>().updateSurveyAnswer(question.id, currentList);
              },
            );
          }).toList(),
        );

      default:
        return const Text('Unsupported question type');
    }
  }

  void _submitSurvey() async {
    try {
      await context.read<FeedbackProvider>().submitCurrentAnswers();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Survey submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate BEFORE clearing state (although state is cleared in provider)
      // Actually provider clears it, so we rely on that.
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

class _SurveyTextField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _SurveyTextField({
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_SurveyTextField> createState() => _SurveyTextFieldState();
}

class _SurveyTextFieldState extends State<_SurveyTextField> {
  late TextEditingController _controller;
  String _textBeforeListening = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: 'Your answer...',
        suffixIcon: MicButton(
          onListeningStart: () {
            _textBeforeListening = _controller.text;
          },
          onResult: (text) {
             if (text.isNotEmpty) {
               final prefix = _textBeforeListening.isEmpty ? '' : '$_textBeforeListening ';
               final newText = '$prefix$text';
               
               _controller.text = newText;
               _controller.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
               widget.onChanged(newText);
             }
          },
        ),
      ),
      maxLines: 3,
      onChanged: widget.onChanged,
    );
  }
}
