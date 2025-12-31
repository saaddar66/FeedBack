import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Widget that displays a bar chart showing the distribution of ratings (1-5)
/// Each bar represents the count of feedback entries for that rating
/// Bars are color-coded: green for 4-5, orange for 3, red for 1-2
class RatingChart extends StatelessWidget {
  final Map<int, int> ratingDistribution; // Map of rating -> count

  const RatingChart({super.key, required this.ratingDistribution});

  @override
  Widget build(BuildContext context) {
    // Show empty state if no data available
    if (ratingDistribution.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'No rating data available',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // Calculate maximum value for Y-axis scaling
    final maxValue = ratingDistribution.values.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rating Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue.toDouble() + 1, // Add padding at top
                  // Enable touch interactions to show tooltips
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.grey[800]!,
                    ),
                  ),
                  // Configure axis titles
                  titlesData: FlTitlesData(
                    show: true,
                    // Bottom axis shows rating numbers (1-5)
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    // Left axis shows count values
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  // Grid lines for better readability
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                  ),
                  borderData: FlBorderData(show: false),
                  // Generate bars for each rating (1-5)
                  barGroups: List.generate(5, (index) {
                    final rating = index + 1;
                    final count = ratingDistribution[rating] ?? 0;
                    return BarChartGroupData(
                      x: rating,
                      barRods: [
                        BarChartRodData(
                          toY: count.toDouble(),
                          color: _getRatingColor(rating), // Color based on rating
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a color based on rating value
  /// Green for ratings 4-5 (positive), Orange for 3 (neutral), Red for 1-2 (negative)
  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }
}
