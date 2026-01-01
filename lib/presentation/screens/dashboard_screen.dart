import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/feedback_provider.dart';
import '../widgets/rating_chart.dart';
import '../widgets/trends_chart.dart';
import '../widgets/filter_dialog.dart';
import '../../data/models/feedback_model.dart';

/// Dashboard screen displaying feedback statistics, charts, and recent feedback
/// Shows total feedback count, average rating, rating distribution chart,
/// trends over time, and a list of recent feedback entries
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load feedback data after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedbackProvider>().loadFeedback();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback Dashboard'),
        actions: [
          // Configuration button to navigate to configuration screen
          IconButton(
            icon: const Icon(Icons.settings_applications),
            onPressed: () => context.go('/config'),
            tooltip: 'Survey Configuration',
          ),
          // Settings button to navigate to settings screen
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
            tooltip: 'Settings',
          ),
          // Filter button to open filter dialog
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
            tooltip: 'Filter',
          ),
          // Refresh button to reload feedback data
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FeedbackProvider>().loadFeedback(),
            tooltip: 'Refresh',
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/'),
            tooltip: 'Logout',
          ),
        ],
      ),
      // Use Selector for loading state to minimize rebuilds
      body: Selector<FeedbackProvider, bool>(
        selector: (_, provider) => provider.isLoading,
        builder: (context, isLoading, child) {
          // Show loading indicator while data is being fetched
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => context.read<FeedbackProvider>().loadFeedback(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
                
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // S1: Stats Cards - Only rebuilds when totalFeedback or averageRating changes
                      _buildStatsCardsSelector(),
                      const SizedBox(height: 24),
                      
                      // S2: Filters
                      _buildFiltersInfoSelector(),
                      
                      // S3: Charts Area - Only rebuilds when ratingDistribution or trendsData changes
                      if (isDesktop)
                        // Desktop: Side-by-Side Charts
                        _buildChartsRowSelector()
                      else
                        // Tablet/Mobile: Stacked Charts
                        _buildChartsColumnSelector(),
                      
                      const SizedBox(height: 24),
                      // S4: Recent Feedback
                      _buildRecentFeedbackSelector(),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Builds the statistics cards row using Selector
  /// Only rebuilds when totalFeedback or averageRating changes
  Widget _buildStatsCardsSelector() {
    return Selector<FeedbackProvider, Map<String, dynamic>>(
      selector: (_, provider) => {
        'totalFeedback': provider.totalFeedback,
        'averageRating': provider.averageRating,
      },
      builder: (context, stats, child) {
        return Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Total Feedback',
                value: stats['totalFeedback'].toString(),
                icon: Icons.feedback,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Avg Rating',
                value: (stats['averageRating'] as double).toStringAsFixed(1),
                icon: Icons.star,
                color: Colors.amber,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the charts row for desktop view using Selector
  Widget _buildChartsRowSelector() {
    return Selector<FeedbackProvider, Map<String, dynamic>>(
      selector: (_, provider) => {
        'ratingDistribution': provider.ratingDistribution,
        'trendsData': provider.trendsData,
      },
      builder: (context, data, child) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RatingChart(
                ratingDistribution: data['ratingDistribution'] as Map<int, int>,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: TrendsChart(
                trendsData: data['trendsData'] as List<Map<String, dynamic>>,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the charts column for mobile/tablet view using Selector
  Widget _buildChartsColumnSelector() {
    return Selector<FeedbackProvider, Map<String, dynamic>>(
      selector: (_, provider) => {
        'ratingDistribution': provider.ratingDistribution,
        'trendsData': provider.trendsData,
      },
      builder: (context, data, child) {
        return Column(
          children: [
            RatingChart(
              ratingDistribution: data['ratingDistribution'] as Map<int, int>,
            ),
            const SizedBox(height: 24),
            TrendsChart(
              trendsData: data['trendsData'] as List<Map<String, dynamic>>,
            ),
          ],
        );
      },
    );
  }

  /// Builds the filter information card using Selector
  /// Shows active filters and provides a button to clear them
  /// Only displays if at least one filter is active
  Widget _buildFiltersInfoSelector() {
    return Selector<FeedbackProvider, Map<String, dynamic>>(
      selector: (_, provider) => {
        'selectedMinRating': provider.selectedMinRating,
        'selectedMaxRating': provider.selectedMaxRating,
        'startDate': provider.startDate,
        'endDate': provider.endDate,
      },
      builder: (context, filters, child) {
        final provider = context.read<FeedbackProvider>();
        return _buildFiltersInfo(provider);
      },
    );
  }

  /// Builds the filter information card
  /// Shows active filters and provides a button to clear them
  /// Only displays if at least one filter is active
  Widget _buildFiltersInfo(FeedbackProvider provider) {
    final hasFilters = provider.selectedMinRating != null ||
        provider.selectedMaxRating != null ||
        provider.startDate != null ||
        provider.endDate != null;

    // Don't show anything if no filters are active
    if (!hasFilters) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.filter_alt, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _buildFilterText(provider),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            // Button to clear all filters
            TextButton(
              onPressed: () {
                provider.clearFilters();
              },
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a human-readable string describing active filters
  /// Formats rating range and date range filters
  String _buildFilterText(FeedbackProvider provider) {
    final parts = <String>[];
    if (provider.selectedMinRating != null || provider.selectedMaxRating != null) {
      final min = provider.selectedMinRating ?? 1;
      final max = provider.selectedMaxRating ?? 5;
      parts.add('Rating: $min-$max');
    }
    if (provider.startDate != null || provider.endDate != null) {
      final start = provider.startDate != null
          ? DateFormat('MMM d').format(provider.startDate!)
          : 'Start';
      final end = provider.endDate != null
          ? DateFormat('MMM d').format(provider.endDate!)
          : 'End';
      parts.add('Date: $start - $end');
    }
    return parts.join(' • ');
  }

  /// Builds the recent feedback list widget using Selector
  /// Only rebuilds when feedbackList changes
  Widget _buildRecentFeedbackSelector() {
    return Selector<FeedbackProvider, List<FeedbackModel>>(
      selector: (_, provider) => provider.feedbackList,
      builder: (context, feedbackList, child) {
        final provider = context.read<FeedbackProvider>();
        return _buildRecentFeedback(provider);
      },
    );
  }

  /// Builds the recent feedback list widget
  /// Shows up to 5 most recent feedback entries
  /// Displays rating, name (or Anonymous), comments preview, and date
  Widget _buildRecentFeedback(FeedbackProvider provider) {
    if (provider.feedbackList.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'No feedback yet',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Recent Feedback',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          // List of feedback items (max 5)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: provider.feedbackList.length > 5 ? 5 : provider.feedbackList.length,
            itemBuilder: (context, index) {
              final feedback = provider.feedbackList[index];
              final heroTag = 'feedback_${feedback.id ?? index}';
              return ListTile(
                // Circular avatar with rating number, color-coded by rating value
                leading: Hero(
                  tag: heroTag,
                  child: CircleAvatar(
                    backgroundColor: _getRatingColor(feedback.rating),
                    child: Text(
                      feedback.rating.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // Name or "Anonymous" if no name provided
                title: Text(
                  feedback.name ?? 'Anonymous',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                // Comments preview (max 2 lines)
                subtitle: Text(
                  feedback.comments,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Formatted creation date
                trailing: Text(
                  DateFormat('MMM d').format(feedback.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Returns a color based on rating value
  /// Green for 4-5, Orange for 3, Red for 1-2
  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }

  /// Shows the filter dialog to allow users to set filters
  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const FilterDialog(),
    );
  }
}

/// Reusable stat card widget
/// Displays an icon, value, and title in a card format with glassmorphic gradient
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Determine gradient colors based on card type
    final isTotalFeedback = icon == Icons.feedback;
    final gradientColors = isTotalFeedback
        ? [Colors.blue.shade50, Colors.white]
        : [Colors.amber.shade50, Colors.white];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
