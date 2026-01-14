import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/public_submission_provider.dart';

/// QR code-based web feedback form for public users
/// Mobile-first, responsive design
/// Uses PublicSubmissionProvider for secure submission-only access
class QrFeedbackWebScreen extends StatefulWidget {
  const QrFeedbackWebScreen({super.key});

  @override
  State<QrFeedbackWebScreen> createState() => _QrFeedbackWebScreenState();
}

class _QrFeedbackWebScreenState extends State<QrFeedbackWebScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  
  // Text controllers for form fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _commentsController = TextEditingController();
  
  // Selected rating (defaults to 3)
  int _selectedRating = 3;

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _nameController.dispose();
    _emailController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  /// Validates and submits the feedback form
  /// Navigates to thank you page on success
  Future<void> _submitFeedback() async {
    // Validate form fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Get ownerId from query parameters
    final state = GoRouterState.of(context);
    final ownerId = state.uri.queryParameters['uid'];

    final provider = context.read<PublicSubmissionProvider>();
    // Submit feedback through provider
    final success = await provider.submitPublicFeedback(
      name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      rating: _selectedRating,
      comments: _commentsController.text.trim(),
      ownerId: ownerId,
    );
    
    // Clear error if success (though we navigate away) or keep it if failed
    if (success) {
        provider.clearError();
    } else {
        // Validation error is already set in provider if any
    }

    if (mounted) {
      if (success) {
        // Navigate to thank you page on success
        context.go('/thank-you');
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to submit feedback. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const Text(
                      'We value your feedback!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please share your thoughts with us. Name and email are optional.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Name input field (optional)
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Email input field (optional, with validation)
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        // Validate email format if provided
                        if (value != null && value.isNotEmpty) {
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Rating selection section
                    const Text(
                      'Rating *',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Rating emoji buttons (1-5)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        final rating = index + 1;
                        final isSelected = _selectedRating == rating;
                        final emoji = _getRatingEmoji(rating);
                        
                        return AnimatedScale(
                          scale: isSelected ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: IconButton(
                            onPressed: () => setState(() => _selectedRating = rating),
                            icon: Text(
                              emoji,
                              style: TextStyle(
                                fontSize: 40,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade400,
                              ),
                            ),
                            tooltip: _getRatingLabel(rating),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    
                    // Rating label (Poor, Fair, Good, etc.)
                    Text(
                      _getRatingLabel(_selectedRating),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: _getRatingColor(_selectedRating),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Comments input field (required)
                    TextFormField(
                      controller: _commentsController,
                      decoration: const InputDecoration(
                        labelText: 'Comments *',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (value) {
                        // Comments are required
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your comments';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    // Submit button
                    Consumer<PublicSubmissionProvider>(
                      builder: (context, provider, child) {
                        return ElevatedButton(
                          onPressed: provider.isSubmitting ? null : _submitFeedback,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                          ),
                          child: provider.isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Submit Feedback',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Returns an emoji based on rating value
  /// 1=😠, 2=☹️, 3=😐, 4=🙂, 5=🤩
  String _getRatingEmoji(int rating) {
    switch (rating) {
      case 1:
        return '😠';
      case 2:
        return '☹️';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '🤩';
      default:
        return '😐';
    }
  }

  /// Returns a color based on rating value
  /// Green for 4-5, Orange for 3, Red for 1-2
  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }

  /// Returns a human-readable label for the rating
  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}

