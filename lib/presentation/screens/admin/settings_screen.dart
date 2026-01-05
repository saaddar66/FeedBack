import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Settings screen for admin to edit profile details
/// Contains form fields for name, email, and phone number
/// Allows updating profile information with validation
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  
  // Loading state during save
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with empty text
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Validates and saves the profile changes
  /// Shows success message via SnackBar
  Future<void> _saveChanges() async {
    // Validate form fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    // Mock save operation - simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() => _isSaving = false);

    if (mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
          tooltip: 'Back',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header text
                  const Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Update your profile information',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  
                  // Full Name input field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Email input field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Phone input field (optional)
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 32),
                  
                  // Save Changes button at the bottom
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

