import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// Widget that displays two line charts showing feedback trends over time
/// First chart shows daily feedback count, second chart shows daily average rating
/// Both charts use the same date axis for easy comparison
class TrendsChart extends StatelessWidget {
  final List<Map<String, dynamic>> trendsData; // List of daily trend data

  const TrendsChart({super.key, required this.trendsData});

  @override
  Widget build(BuildContext context) {
    // Show empty state if no data available
    if (trendsData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'No trends data available',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // Calculate maximum count for Y-axis scaling of first chart
    final maxCount = trendsData
        .map((e) => (e['count'] as num).toInt())
        .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Feedback Trends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // First chart: Daily feedback count
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    // Bottom axis shows formatted dates
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= trendsData.length) {
                            return const Text('');
                          }
                          try {
                            final dateStr = trendsData[value.toInt()]['date'] as String;
                            final date = DateTime.parse(dateStr);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MMM d').format(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          } catch (e) {
                            return const Text('');
                          }
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
                  borderData: FlBorderData(show: false),
                  // Line chart data points for feedback count
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(trendsData.length, (index) {
                        final count = (trendsData[index]['count'] as num).toDouble();
                        return FlSpot(index.toDouble(), count);
                      }),
                      isCurved: true, // Smooth curved line
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true), // Show data points
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1), // Fill area under line
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: maxCount.toDouble() + 1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Second chart: Daily average rating
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    // Bottom axis shows formatted dates (same as first chart)
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= trendsData.length) {
                            return const Text('');
                          }
                          try {
                            final dateStr = trendsData[value.toInt()]['date'] as String;
                            final date = DateTime.parse(dateStr);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MMM d').format(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          } catch (e) {
                            return const Text('');
                          }
                        },
                      ),
                    ),
                    // Left axis shows rating values (0-5)
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
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
                  borderData: FlBorderData(show: false),
                  // Line chart data points for average rating
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(trendsData.length, (index) {
                        final avgRating = (trendsData[index]['avg_rating'] as num).toDouble();
                        return FlSpot(index.toDouble(), avgRating);
                      }),
                      isCurved: true, // Smooth curved line
                      color: Colors.amber,
                      barWidth: 3,
                      dotData: const FlDotData(show: true), // Show data points
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.amber.withOpacity(0.1), // Fill area under line
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: 5.0, // Rating scale is always 0-5
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Legend explaining the two charts
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: Colors.blue, label: 'Feedback Count'),
                const SizedBox(width: 16),
                _LegendItem(color: Colors.amber, label: 'Avg Rating'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Legend item widget showing a colored circle and label
/// Used to explain what each line in the trends chart represents
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
