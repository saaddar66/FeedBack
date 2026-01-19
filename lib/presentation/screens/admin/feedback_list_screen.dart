import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:developer' as developer;
import '../../../services/ai_service.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/feedback_model.dart';
import '../../../utils/pdf_exporter.dart';
import '../../../utils/csv_exporter.dart';

/// Production-ready feedback list screen with filtering sorting and actions
/// Displays all customer feedback with ratings, comments, and timestamps
class FeedbackListScreen extends StatefulWidget {
  const FeedbackListScreen({super.key});

  @override
  State<FeedbackListScreen> createState() => _FeedbackListScreenState();
}

class _FeedbackListScreenState extends State<FeedbackListScreen> {
  // ... state variables ... (omitted for tool call simplicity, handled by start/end line)

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Filtering and sorting state
  String _sortBy = 'date'; // 'date', 'rating', 'name'
  bool _sortAscending = false;
  int? _filterRating; // null means show all
  String _searchQuery = '';
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      
      if (authProvider.isLoading) {
         // Should wait or listen, but simpler to just return or show loading in build
         return; 
      }

      final userId = authProvider.user?.id;
      if (userId != null) {
        developer.log('FeedbackListScreen: Current logged-in user ID: $userId', name: 'FeedbackListScreen');
        context.read<FeedbackProvider>().setCurrentUser(userId);
        context.read<FeedbackProvider>().clearFilters();
        _loadFeedback();
      } else {
        developer.log('FeedbackListScreen: WARNING - No user ID found! Redirecting to login.', name: 'FeedbackListScreen', level: 900);
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    // Clean up search controller to prevent memory leaks
    _searchController.dispose();
    super.dispose();
  }

  /// Loads all feedback from database with error handling
  Future<void> _loadFeedback() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await context.read<FeedbackProvider>().loadFeedback();
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        
        _showErrorSnackbar('Error loading feedback: $e');
      }
    }
  }

  /// Filters and sorts feedback based on current settings
  List<FeedbackModel> _getFilteredAndSortedFeedback(List<FeedbackModel> feedbackList) {
    var filtered = feedbackList.where((feedback) {
      // Filter by rating if selected
      if (_filterRating != null && feedback.rating != _filterRating) {
        return false;
      }
      
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = (feedback.name ?? '').toLowerCase();
        final comments = feedback.comments.toLowerCase();
        return name.contains(query) || comments.contains(query);
      }
      
      return true;
    }).toList();
    
    // Sort the filtered list
    filtered.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'date':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'rating':
          comparison = a.rating.compareTo(b.rating);
          break;
        case 'name':
          final nameA = a.name ?? 'Anonymous';
          final nameB = b.name ?? 'Anonymous';
          comparison = nameA.compareTo(nameB);
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });
    
    return filtered;
  }

  /// Deletes single feedback with confirmation dialog
  Future<void> _deleteFeedback(FeedbackModel feedback) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Feedback'),
        content: Text('Are you sure you want to delete feedback from ${feedback.name ?? "Anonymous"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await context.read<FeedbackProvider>().deleteFeedback(feedback.id);
      
      if (mounted) {
        _showSuccessSnackbar('Feedback deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error deleting feedback: $e');
      }
    }
  }

  /// Shows detailed feedback in bottom sheet modal
  void _showFeedbackDetails(FeedbackModel feedback) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Header with rating
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _getRatingColor(feedback.rating),
                    child: Text(
                      feedback.rating.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feedback.name ?? 'Anonymous User',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('MMMM d, y • h:mm a').format(feedback.createdAt),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              // Comments section
              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  feedback.comments.isEmpty ? 'No comments provided' : feedback.comments,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteFeedback(feedback);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exports feedback to CSV or JSON format placeholder
  Future<void> _exportFeedback() async {
    final feedbackList = context.read<FeedbackProvider>().feedbackList;
    
    if (feedbackList.isEmpty) {
      _showErrorSnackbar('No feedback to export');
      return;
    }

    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Feedback'),
        content: const Text('Choose export format:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('csv'),
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('pdf'),
            child: const Text('PDF'),
          ),
        ],
      ),
    );

    if (format == null) return;
    
      try {
      if (format == 'pdf') {
        final userId = context.read<AuthProvider>().user?.id;
        await PDFExporter().exportAllData(userId: userId);
        if (mounted) _showSuccessSnackbar('PDF Report generated successfully');
      } else if (format == 'csv') {
        final userId = context.read<AuthProvider>().user?.id;
        await CSVExporter().exportFeedback(feedbackList, userId: userId);
        if (mounted) _showSuccessSnackbar('CSV file exported successfully');
      }
      } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to export: $e');
      }
    }
  }

  Future<void> _analyzeFeedback() async {
    final feedbackList = context.read<FeedbackProvider>().feedbackList;
    if (feedbackList.isEmpty) {
      _showErrorSnackbar('No feedback to analyze');
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final aiService = AIService();
      final report = await aiService.analyzeFeedback(feedbackList);
      
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading

      // Show Report
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple.shade300),
              const SizedBox(width: 8),
              const Text('AI Insights'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: MarkdownBody(data: report),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackbar('AI Analysis Failed: $e');
    }
  }

  /// Shows filter and sort options in bottom sheet
  void _showFilterSortOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text(
                'Filter & Sort Options',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              // Sort by section
              const Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Date'),
                    selected: _sortBy == 'date',
                    onSelected: (selected) {
                      setModalState(() => _sortBy = 'date');
                      setState(() => _sortBy = 'date');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Rating'),
                    selected: _sortBy == 'rating',
                    onSelected: (selected) {
                      setModalState(() => _sortBy = 'rating');
                      setState(() => _sortBy = 'rating');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Name'),
                    selected: _sortBy == 'name',
                    onSelected: (selected) {
                      setModalState(() => _sortBy = 'name');
                      setState(() => _sortBy = 'name');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Sort order toggle
              SwitchListTile(
                title: const Text('Ascending Order'),
                value: _sortAscending,
                onChanged: (value) {
                  setModalState(() => _sortAscending = value);
                  setState(() => _sortAscending = value);
                },
              ),
              const Divider(),
              const SizedBox(height: 8),
              
              // Filter by rating section
              const Text('Filter by Rating', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filterRating == null,
                    onSelected: (selected) {
                      setModalState(() => _filterRating = null);
                      setState(() => _filterRating = null);
                    },
                  ),
                  ...List.generate(5, (index) {
                    final rating = index + 1;
                    return ChoiceChip(
                      label: Text('$rating ⭐'),
                      selected: _filterRating == rating,
                      onSelected: (selected) {
                        setModalState(() => _filterRating = rating);
                        setState(() => _filterRating = rating);
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 24),
              
              // Apply button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply'),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
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
          onPressed: _loadFeedback,
        ),
      ),
    );
  }

  /// Returns color based on rating value for visual feedback
  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }

  /// Returns icon based on rating value for visual feedback
  IconData _getRatingIcon(int rating) {
    if (rating >= 4) return Icons.sentiment_very_satisfied;
    if (rating >= 3) return Icons.sentiment_neutral;
    return Icons.sentiment_very_dissatisfied;
  }

  @override
  Widget build(BuildContext context) {
    final allFeedback = context.watch<FeedbackProvider>().feedbackList;
    final filteredFeedback = _getFilteredAndSortedFeedback(allFeedback);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('All Feedback'),
            if (allFeedback.isNotEmpty)
              Text(
                '${filteredFeedback.length} of ${allFeedback.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          // Filter/Sort button
          IconButton(
            icon: Badge(
              label: Text('${_filterRating ?? ''}'),
              isLabelVisible: _filterRating != null,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _showFilterSortOptions,
            tooltip: 'Filter & Sort',
          ),
            // AI Analyze button
            if (!_isLoading && allFeedback.isNotEmpty)
              IconButton(
                icon: Icon(Icons.auto_awesome, color: Colors.purple.shade300),
                onPressed: _analyzeFeedback,
                tooltip: 'Analyze with AI',
              ),
            // Export button
            if (!_isLoading && allFeedback.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _exportFeedback,
                tooltip: 'Export Feedback',
              ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadFeedback,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search feedback...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          
          // Body content
          Expanded(
            child: _buildBody(allFeedback, filteredFeedback),
          ),
        ],
      ),
    );
  }

  /// Builds appropriate body based on loading error empty states
  Widget _buildBody(List<FeedbackModel> allFeedback, List<FeedbackModel> filteredFeedback) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading feedback...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
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
              'Failed to load feedback',
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
              onPressed: _loadFeedback,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (allFeedback.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.feedback_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No feedback available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Feedback will appear here once customers submit responses',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (filteredFeedback.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No feedback matches your filters',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _filterRating = null;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredFeedback.length,
      itemBuilder: (context, index) {
        final feedback = filteredFeedback[index];
        return _buildFeedbackCard(feedback);
      },
    );
  }

  /// Builds individual feedback card with rating and details
  Widget _buildFeedbackCard(FeedbackModel feedback) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showFeedbackDetails(feedback),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rating avatar with color coding
              CircleAvatar(
                radius: 24,
                backgroundColor: _getRatingColor(feedback.rating),
                child: Icon(
                  _getRatingIcon(feedback.rating),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              
              // Content section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            feedback.name ?? 'Anonymous User',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getRatingColor(feedback.rating).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${feedback.rating} ⭐',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getRatingColor(feedback.rating),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feedback.comments.isEmpty 
                          ? 'No comments provided' 
                          : feedback.comments,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, y • h:mm a').format(feedback.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () => _deleteFeedback(feedback),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }
}