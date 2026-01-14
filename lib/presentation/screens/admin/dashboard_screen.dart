import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/rating_chart.dart';
import '../../widgets/trends_chart.dart';
import '../../widgets/filter_dialog.dart';
import '../../models/selector_models.dart';
import '../../../data/models/feedback_model.dart';

/// Production-ready dashboard with stats charts filters and recent feedback
/// Features loading states error handling pull to refresh and responsive layout
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _hasError = false;
  String _errorMessage = '';
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  /// Loads all dashboard data with comprehensive error handling
  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    
    setState(() {
      _hasError = false;
    });

    try {
      // Set current user context before loading data
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        context.read<FeedbackProvider>().setCurrentUser(userId);
      }
      
      await context.read<FeedbackProvider>().loadFeedback();
      
      if (mounted) {
        setState(() => _lastRefreshTime = DateTime.now());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
        _showErrorSnackbar('Error loading dashboard: $e');
      }
    }
  }

  /// Handles logout with confirmation dialog
  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      context.read<AuthProvider>().logout();
      context.go('/');
    }
  }

  /// Shows success message in green snackbar
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows error message in red snackbar with retry
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadDashboardData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Feedback Dashboard'),
            if (user != null)
              Text(
                'Welcome, ${user.name}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          // Filter button with active indicator badge
          Selector<FeedbackProvider, bool>(
            selector: (_, provider) => provider.hasActiveFilters,
            builder: (context, hasFilters, _) {
              return IconButton(
                icon: Badge(
                  isLabelVisible: hasFilters,
                  child: const Icon(Icons.filter_list),
                ),
                onPressed: () => _showFilterDialog(context),
                tooltip: 'Filter',
              );
            },
          ),
          
          // Refresh button with loading state
          Selector<FeedbackProvider, bool>(
            selector: (_, provider) => provider.isLoading,
            builder: (context, isLoading, _) {
              return IconButton(
                icon: isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: isLoading ? null : _loadDashboardData,
                tooltip: 'Refresh',
              );
            },
          ),
          
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      
      body: Selector<FeedbackProvider, bool>(
        selector: (_, provider) => provider.isLoading,
        builder: (context, isLoading, child) {
          // Show loading on first load only
          if (isLoading && context.read<FeedbackProvider>().feedbackList.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading dashboard...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Show error state if data loading failed
          if (_hasError && context.read<FeedbackProvider>().feedbackList.isEmpty) {
            return _buildErrorState();
          }

          return _buildDashboardContent();
        },
      ),
      
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// Builds error state with retry button
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load dashboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Builds main dashboard content with pull to refresh
  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadDashboardData();
        if (mounted) {
          _showSuccessSnackbar('Dashboard refreshed');
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
          
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Last refresh time indicator
                if (_lastRefreshTime != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          'Last updated: ${_getTimeSinceRefresh()}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                
                // Stats Cards with optimized selector
                _buildStatsCardsSelector(),
                const SizedBox(height: 16),
                
                // Quick action buttons
                _buildQuickActionsRow(),
                const SizedBox(height: 16),
                
                // Active filters info card
                _buildFiltersInfoSelector(),
                
                // Charts area responsive layout
                if (isDesktop)
                  _buildChartsRowSelector()
                else
                  _buildChartsColumnSelector(),
                
                const SizedBox(height: 24),
                
                // Recent feedback list
                _buildRecentFeedbackSelector(),
                
                // Bottom padding for better scrolling
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds quick action buttons for navigation
  Widget _buildQuickActionsRow() {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.list_alt,
            label: 'All Feedback',
            color: Colors.blue,
            onTap: () => context.go('/feedback-results'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.assessment_outlined,
            label: 'All Surveys',
            color: Colors.purple,
            onTap: () => context.go('/survey-results'),
          ),
        ),
      ],
    );
  }

  /// Builds statistics cards with total count and average rating
  Widget _buildStatsCardsSelector() {
    return Selector<FeedbackProvider, StatsData>(
      selector: (_, provider) => StatsData(
        provider.totalFeedback,
        provider.averageRating,
      ),
      builder: (context, stats, child) {
        return Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Total Feedback',
                value: stats.totalFeedback.toString(),
                icon: Icons.feedback,
                color: Colors.blue,
                subtitle: stats.totalFeedback == 1 ? 'response' : 'responses',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Avg Rating',
                value: stats.averageRating.toStringAsFixed(1),
                icon: Icons.star,
                color: Colors.amber,
                subtitle: _getRatingLabel(stats.averageRating),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds charts in row layout for desktop view
  Widget _buildChartsRowSelector() {
    return Selector<FeedbackProvider, ChartData>(
      selector: (_, provider) => ChartData(
        provider.ratingDistribution,
        provider.trendsData,
      ),
      builder: (context, data, child) {
        // Show empty state if no data
        if (data.ratingDistribution.isEmpty && data.trendsData.isEmpty) {
          return _buildEmptyChartsState();
        }
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RatingChart(
                ratingDistribution: data.ratingDistribution,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: TrendsChart(
                trendsData: data.trendsData,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds charts in column layout for mobile tablet view
  Widget _buildChartsColumnSelector() {
    return Selector<FeedbackProvider, ChartData>(
      selector: (_, provider) => ChartData(
        provider.ratingDistribution,
        provider.trendsData,
      ),
      builder: (context, data, child) {
        if (data.ratingDistribution.isEmpty && data.trendsData.isEmpty) {
          return _buildEmptyChartsState();
        }
        
        return Column(
          children: [
            RatingChart(
              ratingDistribution: data.ratingDistribution,
            ),
            const SizedBox(height: 24),
            TrendsChart(
              trendsData: data.trendsData,
            ),
          ],
        );
      },
    );
  }

  /// Builds empty state for charts when no data
  Widget _buildEmptyChartsState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.bar_chart_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No chart data available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds active filters information card with clear button
  Widget _buildFiltersInfoSelector() {
    return Selector<FeedbackProvider, FilterData>(
      selector: (_, provider) => FilterData(
        selectedMinRating: provider.selectedMinRating,
        selectedMaxRating: provider.selectedMaxRating,
        startDate: provider.startDate,
        endDate: provider.endDate,
      ),
      builder: (context, filters, child) {
        final provider = context.read<FeedbackProvider>();
        final hasFilters = provider.selectedMinRating != null ||
            provider.selectedMaxRating != null ||
            provider.startDate != null ||
            provider.endDate != null;

        if (!hasFilters) {
          return const SizedBox.shrink();
        }

        return Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(Icons.filter_alt, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _buildFilterText(provider),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    provider.clearFilters();
                    _showSuccessSnackbar('Filters cleared');
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds human readable filter description text
  String _buildFilterText(FeedbackProvider provider) {
    final parts = <String>[];
    
    if (provider.selectedMinRating != null || provider.selectedMaxRating != null) {
      final min = provider.selectedMinRating ?? 1;
      final max = provider.selectedMaxRating ?? 5;
      parts.add('Rating: $min-$max ⭐');
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
    
    return 'Active Filters: ${parts.join(' • ')}';
  }

  /// Builds recent feedback list with tap to view details
  Widget _buildRecentFeedbackSelector() {
    return Selector<FeedbackProvider, List<FeedbackModel>>(
      selector: (_, provider) => provider.feedbackList,
      builder: (context, feedbackList, child) {
        if (feedbackList.isEmpty) {
          return _buildEmptyFeedbackState();
        }

        final recentFeedback = feedbackList.take(5).toList();
        
        return Card(
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Feedback',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => context.go('/feedback-results'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentFeedback.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final feedback = recentFeedback[index];
                  return _buildFeedbackListItem(feedback, index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds single feedback list item with rating and details
  Widget _buildFeedbackListItem(FeedbackModel feedback, int index) {
    return ListTile(
      leading: Hero(
        tag: 'feedback_${feedback.id ?? index}',
        child: CircleAvatar(
          backgroundColor: _getRatingColor(feedback.rating),
          child: Icon(
            _getRatingIcon(feedback.rating),
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
      title: Text(
        feedback.name ?? 'Anonymous User',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            feedback.comments.isEmpty ? 'No comments' : feedback.comments,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getRatingColor(feedback.rating).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${feedback.rating} ⭐',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _getRatingColor(feedback.rating),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM d').format(feedback.createdAt),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      isThreeLine: true,
      onTap: () => context.go('/feedback-results'),
    );
  }

  /// Builds empty state when no feedback exists
  Widget _buildEmptyFeedbackState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                'No feedback yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Feedback will appear here once customers submit responses',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds bottom navigation bar with settings icons
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavButton(
                icon: Icons.settings_applications,
                label: 'Survey Config',
                onPressed: () => context.go('/config'),
                color: Colors.blue,
              ),
              _BottomNavButton(
                icon: Icons.settings,
                label: 'Settings',
                onPressed: () => context.go('/settings'),
                color: Colors.grey[700]!,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns time since last refresh in human readable format
  String _getTimeSinceRefresh() {
    if (_lastRefreshTime == null) return 'Never';
    
    final difference = DateTime.now().difference(_lastRefreshTime!);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return DateFormat('h:mm a').format(_lastRefreshTime!);
    }
  }

  /// Returns rating label based on average rating value
  String _getRatingLabel(double rating) {
    if (rating >= 4.5) return 'Excellent';
    if (rating >= 4.0) return 'Very Good';
    if (rating >= 3.5) return 'Good';
    if (rating >= 3.0) return 'Average';
    if (rating >= 2.0) return 'Below Average';
    return 'Poor';
  }

  /// Returns color based on rating value
  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }

  /// Returns icon based on rating value
  IconData _getRatingIcon(int rating) {
    if (rating >= 4) return Icons.sentiment_very_satisfied;
    if (rating >= 3) return Icons.sentiment_neutral;
    return Icons.sentiment_very_dissatisfied;
  }

  /// Shows filter dialog to set rating and date filters
  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const FilterDialog(),
    );
  }
}

/// Stat card widget showing metric with icon and gradient
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = icon == Icons.feedback
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
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick action card for navigation buttons
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom navigation button with icon and label
class _BottomNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _BottomNavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}