import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/feedback_provider.dart';

class SurveyResponseListScreen extends StatefulWidget {
  const SurveyResponseListScreen({super.key});

  @override
  State<SurveyResponseListScreen> createState() => _SurveyResponseListScreenState();
}

class _SurveyResponseListScreenState extends State<SurveyResponseListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedbackProvider>().loadSurveyResponses();
    });
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
      ),
      body: responses.isEmpty
          ? const Center(child: Text('No survey responses yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: responses.length,
              itemBuilder: (context, index) {
                final response = responses[index];
                final answers = Map<String, dynamic>.from(response['answers'] as Map);
                final submittedAtString = response['submittedAt'] as String?;
                final submittedAt = submittedAtString != null 
                    ? DateTime.parse(submittedAtString) 
                    : DateTime.now();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text('Response #${index + 1}'),
                    subtitle: Text(
                      DateFormat('MMM d, y • h:mm a').format(submittedAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: answers.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Since we store by Question ID, we might not have the question title 
                                  // unless we fetch it. For now, showing Question ID is the raw data way.
                                  // Improving this would require joining with Questions, which is complex 
                                  // if questions are deleted. 
                                  // Displaying the Answer value:
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: DefaultTextStyle.of(context).style,
                                        children: [
                                          const TextSpan(text: 'Q: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                          TextSpan(text: _formatQuestionId(entry.key), style: const TextStyle(fontWeight: FontWeight.bold)), // Ideally map to title
                                          const TextSpan(text: '\n'),
                                          TextSpan(text: '${entry.value}'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
  
  // Helper to make ID look slightly less raw if no title map available
  String _formatQuestionId(String id) {
      // In a real app, we would look up the question title from the ID.
      // Since survey structure changes, simply showing the ID or "Question" is a fallback.
      // If the ID is a timestamp (which it is), maybe just say "Question"
      return 'Question';
  }
}
