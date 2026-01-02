import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Welcome screen that serves as the entry point of the application
/// Displays app title and provides navigation to feedback form and admin login
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content: Column with centered vertical layout
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App title at the top
                  const Text(
                    'Feedy',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Feedback Collection',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 64),
                  // Give Feedback button at bottom center
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/survey'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text(
                        'Give Feedback',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Admin Login button at top right
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              onPressed: () => context.go('/login'),
              icon: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: Colors.blue),
                  SizedBox(width: 4),
                  Icon(Icons.person_outline, color: Colors.blue),
                ],
              ),
              tooltip: 'Admin Login',
            ),
          ),
        ],
      ),
    );
  }
}

