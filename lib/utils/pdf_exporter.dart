import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../data/database/database_helper.dart';
import '../data/models/feedback_model.dart';
import '../data/models/survey_models.dart';

class PDFExporter {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Generates and previews a PDF containing all app data
  Future<void> exportAllData() async {
    final pdf = pw.Document();
    
    // Fetch all data
    final feedbackList = await _dbHelper.getAllFeedback();
    final surveyResponses = await _dbHelper.getAllSurveyResponses();
    final surveys = await _dbHelper.getAllSurveys();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildReportHeader(),
            pw.SizedBox(height: 20),
            
            _buildSectionHeader('1. Feedback Responses (${feedbackList.length})'),
            _buildFeedbackTable(feedbackList),
            pw.SizedBox(height: 30),

            _buildSectionHeader('2. Survey Responses (${surveyResponses.length})'),
            _buildSurveyResponsesList(surveyResponses, surveys),
            pw.SizedBox(height: 30),

            _buildSectionHeader('3. Surveys Configuration (${surveys.length})'),
            _buildSurveysTable(surveys),
          ];
        },
      ),
    );

    // Show native share/print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'feedy_data_export_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _buildReportHeader() {
    return pw.Header(
      level: 0,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Feedy Data Export', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.Text(DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())),
        ],
      ),
    );
  }

  pw.Widget _buildSectionHeader(String title) {
    return pw.Header(
      level: 1,
      child: pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _buildFeedbackTable(List<FeedbackModel> feedbackList) {
    if (feedbackList.isEmpty) {
      return pw.Text('No feedback data available.', style: const pw.TextStyle(color: PdfColors.grey));
    }

    // Define table headers
    final headers = ['ID', 'Name', 'Email', 'Rating', 'Date', 'Comment'];

    // Map data to table rows
    final data = feedbackList.map((feedback) {
      final id = feedback.id ?? '';
      return [
        id.length > 8 ? '${id.substring(0, 8)}...' : id,
        feedback.name ?? 'Anonymous',
        feedback.email ?? '-',
        feedback.rating.toString(),
        DateFormat('MMM d, y').format(feedback.createdAt),
        feedback.comments,
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.center,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerLeft,
      },
    );
  }

  pw.Widget _buildSurveyResponsesList(List<Map<String, dynamic>> responses, List<SurveyForm> surveys) {
    if (responses.isEmpty) {
      return pw.Text('No survey responses available.', style: const pw.TextStyle(color: PdfColors.grey));
    }

    // Create a map of Question ID -> Question Title for easier lookup
    final questionTitleMap = <String, String>{};
    for (var survey in surveys) {
      for (var question in survey.questions) {
        questionTitleMap[question.id] = question.title;
      }
    }

    return pw.Column(
      children: responses.map((response) {
        final id = response['id']?.toString() ?? 'Unknown ID';
        final dateStr = response['submittedAt']?.toString();
        final date = dateStr != null 
            ? DateFormat('MMM d, y h:mm a').format(DateTime.tryParse(dateStr) ?? DateTime.now())
            : 'Unknown Date';
        
        final answers = Map<String, dynamic>.from(response['answers'] as Map? ?? {});

        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                   pw.Text('Response ID: $id', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                   pw.Text('Submitted: $date', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
              pw.Divider(),
              ...answers.entries.map((e) {
                final questionId = e.key;
                // Lookup title, fallback to ID if not found
                final questionTitle = questionTitleMap[questionId] ?? 'Question: $questionId';

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 150, // Increased width for titles
                        child: pw.Text('$questionTitle:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Expanded(
                        child: pw.Text(e.value.toString(), style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildSurveysTable(List<SurveyForm> surveys) {
    if (surveys.isEmpty) {
      return pw.Text('No surveys configured.', style: const pw.TextStyle(color: PdfColors.grey));
    }

    final headers = ['Title', 'Status', 'Creator ID', 'Questions Info'];

    final data = surveys.map((survey) {
      final questionSummary = survey.questions.map((q) => '- ${q.title} (${q.type.name})').join('\n');
      
      return [
        survey.title,
        survey.isActive ? 'Active' : 'Inactive',
        survey.creatorId ?? '-',
        questionSummary,
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(4),
      },
    );
  }
}
