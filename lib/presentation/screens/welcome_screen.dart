import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Welcome screen that serves as the entry point of the application
/// Displays app title, QR code for feedback, and navigation to feedback form and admin login
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? _lastActiveUserId;

  @override
  void initState() {
    super.initState();
    _loadLastActiveUser();
  }

  Future<void> _loadLastActiveUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _lastActiveUserId = prefs.getString('last_active_user_id');
      });
    }
  }

  /// Generates the QR code URL for the feedback form
  /// Uses the current web URL or constructs a relative path
  /// Prioritizes current logged-in user, then last active user
  String _getQrCodeUrl(BuildContext context) {
    String baseUrl;
    if (kIsWeb) {
      // For web, use the current origin + /#/survey route
      final uri = Uri.base;
      baseUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/#/survey';
    } else {
      // For mobile/desktop, point to the hosted web app's survey route
      baseUrl = 'https://feedy-cebf6.web.app/#/survey'; 
    }

    // Try to get current logged-in user ID first (most reliable)
    String? ownerId;
    try {
      final authProvider = context.read<AuthProvider>();
      ownerId = authProvider.user?.id;
    } catch (e) {
      // If provider not available, fall back to last active user
    }

    // Fall back to last active user if no current user
    ownerId ??= _lastActiveUserId;

    // Append ownerId if available
    if (ownerId != null && ownerId.isNotEmpty) {
      return '$baseUrl?uid=$ownerId';
    }
    
    // If no ownerId, still return URL but log warning
    print('WARNING: QR code generated without ownerId. Survey responses may not appear in app.');
    return baseUrl;
  }

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
                  const SizedBox(height: 32),
                  // QR Code for feedback
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Scan to Give Feedback',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          QrImageView(
                            data: _getQrCodeUrl(context),
                            version: QrVersions.auto,
                            size: 200.0,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scan with your phone',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_lastActiveUserId != null)
                             Padding(
                               padding: const EdgeInsets.only(top: 4.0),
                                 child: Text(
                                   _lastActiveUserId!.length > 4 
                                      ? 'Linked to Admin ID: ${_lastActiveUserId!.substring(0, 4)}...'
                                      : 'Linked to Admin ID: $_lastActiveUserId',
                                   style: const TextStyle(fontSize: 10, color: Colors.grey),
                                 ),
                             ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Give Feedback button at bottom center
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                          String route = '/survey';
                          if (_lastActiveUserId != null) {
                            route += '?uid=$_lastActiveUserId';
                          }
                          context.go(route);
                      },
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

