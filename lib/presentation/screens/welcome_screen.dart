import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../providers/auth_provider.dart';
import '../widgets/double_back_to_close_wrapper.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? _lastActiveUserId;
  String? _lastActiveBusinessName;

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
        _lastActiveBusinessName = prefs.getString('last_active_business_name');
      });
    }
  }

  /// Retrieves the owner ID from AuthProvider or local storage
  String? _getOwnerId(BuildContext context) {
    String? ownerId;
    try {
      final authProvider = context.read<AuthProvider>();
      ownerId = authProvider.user?.id;
    } catch (e) {
      // If provider not available, fall back to last active user
    }
    return ownerId ?? _lastActiveUserId;
  }

  /// Retrieves the business name from AuthProvider or local storage
  String? _getBusinessName(BuildContext context) {
    String? businessName;
    try {
      final authProvider = context.read<AuthProvider>();
      businessName = authProvider.user?.businessName;
    } catch (e) {
      // If provider not available, fall back to last active user
    }
    return businessName ?? _lastActiveBusinessName;
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

    final ownerId = _getOwnerId(context);

    // Append ownerId if available
    if (ownerId != null && ownerId.isNotEmpty) {
      return '$baseUrl?uid=$ownerId';
    }


    // If no ownerId, still return URL but log warning
    developer.log('WARNING: QR code generated without ownerId. Survey responses may not appear in app.', name: 'WelcomeScreen');
    return baseUrl;
  }



  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive QR code
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = (screenWidth * 0.5).clamp(150.0, 250.0); // 50% of width, min 150, max 250
    final ownerId = _getOwnerId(context);
    final hasValidOwner = ownerId != null && ownerId.isNotEmpty;
    final businessName = _getBusinessName(context);
    
    return DoubleBackToCloseWrapper(
      child: Scaffold(
        body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            children: [
              // Main content: Column with centered vertical layout
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40), // Top spacing
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
                              if (hasValidOwner) ...[
                                QrImageView(
                                  data: _getQrCodeUrl(context),
                                  version: QrVersions.auto,
                                  size: qrSize, // Responsive size
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
                              ] else
                                Container(
                                  width: qrSize,
                                  height: qrSize,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.lock_outline, size: 32, color: Colors.grey[400]),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Login to display your unique QR code',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (businessName != null && businessName.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Linked to: $businessName',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blueGrey),
                                  ),
                                )
                              else if (_lastActiveUserId != null)
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
                            final ownerId = _getOwnerId(context);
                            if (ownerId != null) {
                              route += '?uid=$ownerId';
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
                      const SizedBox(height: 40), // Bottom spacing
                    ],
                  ),
                ),
              ),
              // Admin Login button at top right
              Positioned(
                top: 0,
                right: 0,
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
        ),
      ),
      ),
    );
  }
}

