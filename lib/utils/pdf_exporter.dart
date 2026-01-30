import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../data/database/database_helper.dart';
import '../data/models/feedback_model.dart';
import '../data/models/survey_models.dart';

class PDFExporter {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Generates and previews a PDF containing all app data with improved formatting
  Future<void> exportAllData({String? userId}) async {
    final pdf = pw.Document();
    
    // Fetch all data with user filtering
    final feedbackList = await _dbHelper.getAllFeedback(userId: userId);
    final surveyResponses = await _dbHelper.getAllSurveyResponses(ownerId: userId);
    final surveys = await _dbHelper.getAllSurveys(creatorId: userId);

    // Calculate statistics
    final stats = _calculateStatistics(feedbackList);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildCoverPage(feedbackList.length, surveyResponses.length, surveys.length),
            pw.SizedBox(height: 40),
            
            // Executive Summary
            _buildSectionHeader('Executive Summary', level: 1),
            _buildStatisticsSection(stats),
            pw.SizedBox(height: 20),
            
            // Feedback Section
            _buildSectionHeader('Feedback Responses', level: 1, count: feedbackList.length),
            pw.SizedBox(height: 10),
            _buildFeedbackTable(feedbackList),
            pw.SizedBox(height: 30),

            // Survey Responses Section
            _buildSectionHeader('Survey Responses', level: 1, count: surveyResponses.length),
            pw.SizedBox(height: 10),
            _buildSurveyResponsesList(surveyResponses, surveys),
            pw.SizedBox(height: 30),

            // Surveys Configuration Section
            _buildSectionHeader('Survey Configuration', level: 1, count: surveys.length),
            pw.SizedBox(height: 10),
            _buildSurveysTable(surveys),
          ];
        },
      ),
    );

    // Show native share/print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'feedy_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );
  }

  /// Builds a professional cover page
  pw.Widget _buildCoverPage(int feedbackCount, int responseCount, int surveyCount) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(40),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'FEEDY',
            style: pw.TextStyle(
              fontSize: 48,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Data Export Report',
            style: pw.TextStyle(
              fontSize: 24,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.blue700, thickness: 2),
          pw.SizedBox(height: 40),
          _buildStatCard('Total Feedback', feedbackCount.toString(), PdfColors.blue),
          pw.SizedBox(height: 20),
          _buildStatCard('Survey Responses', responseCount.toString(), PdfColors.green),
          pw.SizedBox(height: 20),
          _buildStatCard('Active Surveys', surveyCount.toString(), PdfColors.orange),
          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.blue700, thickness: 2),
          pw.SizedBox(height: 20),
          pw.Text(
            'Generated: ${DateFormat('MMMM d, yyyy • h:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// Builds a stat card for the cover page
  pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    // Get a lighter version of the color for background
    final bgColor = _getLightColor(color);
    
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: pw.Border.all(color: color, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
          ),
          pw.SizedBox(width: 20),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds section header with improved styling
  pw.Widget _buildSectionHeader(String title, {int level = 1, int? count}) {
    final fontSize = level == 1 ? 20.0 : 16.0;
    final color = level == 1 ? PdfColors.blue700 : PdfColors.grey800;
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: color, width: 2),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          if (count != null) ...[
            pw.SizedBox(width: 10),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: pw.BoxDecoration(
                color: _getLightColor(color),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Text(
                '$count',
                style: pw.TextStyle(
                  fontSize: fontSize - 4,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Calculates statistics from feedback data
  Map<String, dynamic> _calculateStatistics(List<FeedbackModel> feedbackList) {
    if (feedbackList.isEmpty) {
      return {
        'total': 0,
        'averageRating': 0.0,
        'ratingDistribution': <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      };
    }

    final total = feedbackList.length;
    final averageRating = feedbackList.map((f) => f.rating).reduce((a, b) => a + b) / total;
    
    final ratingDistribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (var feedback in feedbackList) {
      ratingDistribution[feedback.rating] = (ratingDistribution[feedback.rating] ?? 0) + 1;
    }

    return {
      'total': total,
      'averageRating': averageRating,
      'ratingDistribution': ratingDistribution,
    };
  }

  /// Builds statistics section with visual elements
  pw.Widget _buildStatisticsSection(Map<String, dynamic> stats) {
    final total = stats['total'] as int;
    final avgRating = stats['averageRating'] as double;
    final distribution = stats['ratingDistribution'] as Map<int, int>;

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatBox('Total Responses', total.toString(), PdfColors.blue),
              _buildStatBox('Avg Rating', avgRating.toStringAsFixed(1), PdfColors.green),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Rating Distribution',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 10),
          ...distribution.entries.map((entry) {
            final rating = entry.key;
            final count = entry.value;
            final percentage = total > 0 ? (count / total * 100) : 0.0;
            
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
                children: [
                  pw.Container(
                    width: 30,
                    child: pw.Text(
                      '$rating ⭐',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Stack(
        children: [
                        pw.Container(
                          height: 20,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey300,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                          ),
                        ),
                        pw.Container(
                          width: (percentage / 100) * 500, // Approximate width
                          height: 20,
                          decoration: pw.BoxDecoration(
                            color: _getRatingColor(rating),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    '$count (${percentage.toStringAsFixed(1)}%)',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Builds a stat box
  pw.Widget _buildStatBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: _getLightColor(color),
        border: pw.Border.all(color: color, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  /// Gets color for rating
  PdfColor _getRatingColor(int rating) {
    if (rating >= 4) return PdfColors.green;
    if (rating >= 3) return PdfColors.orange;
    return PdfColors.red;
  }

  /// Gets a light version of a color for backgrounds
  PdfColor _getLightColor(PdfColor color) {
    // Map common colors to their light versions
    if (color == PdfColors.blue || color == PdfColors.blue700) {
      return PdfColors.blue50;
    } else if (color == PdfColors.green) {
      return PdfColors.green50;
    } else if (color == PdfColors.orange) {
      return PdfColors.orange50;
    } else if (color == PdfColors.red) {
      return PdfColors.red50;
    } else if (color == PdfColors.grey800) {
      return PdfColors.grey200;
    }
    // Default to grey100 for unknown colors
    return PdfColors.grey100;
  }

  /// Builds improved feedback table
  pw.Widget _buildFeedbackTable(List<FeedbackModel> feedbackList) {
    if (feedbackList.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Center(
          child: pw.Text(
            'No feedback data available.',
            style: const pw.TextStyle(color: PdfColors.grey, fontSize: 12),
          ),
        ),
      );
    }

    final headers = ['#', 'Name', 'Email', 'Rating', 'Date', 'Comments'];
    final data = feedbackList.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final feedback = entry.value;
      return [
        index.toString(),
        feedback.name ?? 'Anonymous',
        feedback.email ?? '-',
        '${feedback.rating} ⭐',
        DateFormat('MMM d, y').format(feedback.createdAt),
        feedback.comments.length > 50 
            ? '${feedback.comments.substring(0, 50)}...' 
            : feedback.comments,
      ];
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FixedColumnWidth(50),
        4: const pw.FixedColumnWidth(80),
        5: const pw.FlexColumnWidth(3),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: headers.map((header) => pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              header,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.blue700,
              ),
            ),
          )).toList(),
        ),
        // Data rows
        ...data.map((row) => pw.TableRow(
          children: row.map((cell) => pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              cell.toString(),
              style: const pw.TextStyle(fontSize: 9),
            ),
          )).toList(),
        )),
      ],
    );
  }

  /// Builds improved survey responses list
  pw.Widget _buildSurveyResponsesList(
    List<Map<String, dynamic>> responses,
    List<SurveyForm> surveys,
  ) {
    if (responses.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Center(
          child: pw.Text(
            'No survey responses available.',
            style: const pw.TextStyle(color: PdfColors.grey, fontSize: 12),
          ),
        ),
      );
    }

    final questionTitleMap = <String, String>{};
    for (var survey in surveys) {
      for (var question in survey.questions) {
        questionTitleMap[question.id] = question.title;
      }
    }

    return pw.Column(
      children: responses.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final response = entry.value;
        final id = response['id']?.toString() ?? 'Unknown';
        final dateStr = response['submittedAt']?.toString();
        final date = dateStr != null 
            ? DateFormat('MMM d, y • h:mm a').format(DateTime.tryParse(dateStr) ?? DateTime.now())
            : 'Unknown Date';
        
        // Handle both formats: answers wrapped or at root level
        Map<String, dynamic> answers;
        if (response.containsKey('answers') && response['answers'] is Map) {
          answers = Map<String, dynamic>.from(response['answers'] as Map);
        } else {
          // Extract answer fields from root (backwards compatibility)
          answers = <String, dynamic>{};
          final metadataFields = {'id', 'submittedAt', 'owner_id', 'ownerId', 'userName', 'userEmail', 'answers'};
          response.forEach((key, value) {
            if (!metadataFields.contains(key)) {
              answers[key.toString()] = value;
            }
          });
        }

        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 15),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            border: pw.Border.all(color: PdfColors.grey400, width: 1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Response #$index',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                      color: PdfColors.blue700,
                    ),
                  ),
                  pw.Text(
                    date,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.grey400, height: 1),
              pw.SizedBox(height: 8),
              ...answers.entries.map((e) {
                final questionId = e.key;
                final questionTitle = questionTitleMap[questionId] ?? 'Question: $questionId';
                final answer = e.value.toString();

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 120,
                        child: pw.Text(
                          '$questionTitle:',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          answer.length > 100 ? '${answer.substring(0, 100)}...' : answer,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
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

  /// Builds improved surveys table
  pw.Widget _buildSurveysTable(List<SurveyForm> surveys) {
    if (surveys.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Center(
          child: pw.Text(
            'No surveys configured.',
            style: const pw.TextStyle(color: PdfColors.grey, fontSize: 12),
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FixedColumnWidth(60),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(3),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            'Title',
            'Status',
            'Questions',
            'Question Details',
          ].map((header) => pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              header,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.blue700,
              ),
            ),
          )).toList(),
        ),
        // Data rows
        ...surveys.map((survey) {
          final questionDetails = survey.questions.map((q) {
            return '• ${q.title} (${q.type.name})';
          }).join('\n');

          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  survey.title,
                  style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: survey.isActive 
                        ? PdfColors.green50
                        : PdfColors.red50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    survey.isActive ? 'Active' : 'Inactive',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: survey.isActive ? PdfColors.green : PdfColors.red,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  '${survey.questions.length}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  questionDetails,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}
