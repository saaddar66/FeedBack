import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A wrapper widget that implements "Double tap back to exit" functionality.
/// 
/// Intercepts the system back button/gesture. 
/// On first press, shows a Snackbar "Press back again to exit".
/// On second press within 2 seconds, closes the application.
class DoubleBackToCloseWrapper extends StatefulWidget {
  final Widget child;
  final String message;

  const DoubleBackToCloseWrapper({
    super.key,
    required this.child,
    this.message = 'Press back again to exit',
  });

  @override
  State<DoubleBackToCloseWrapper> createState() => _DoubleBackToCloseWrapperState();
}

class _DoubleBackToCloseWrapperState extends State<DoubleBackToCloseWrapper> {
  DateTime? _lastPressedTime;

  @override
  Widget build(BuildContext context) {
    // Check if standard navigation is possible
    final bool canPop = Navigator.canPop(context);

    return PopScope(
      canPop: canPop, 
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // If the framework already popped the route, do nothing.
          return;
        }

        final now = DateTime.now();
        final backButtonHasNotBeenPressedOrSnackBarHasClosed = 
            _lastPressedTime == null || 
            now.difference(_lastPressedTime!) > const Duration(seconds: 2);

        if (backButtonHasNotBeenPressedOrSnackBarHasClosed) {
          _lastPressedTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.message),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              width: 250, // Compact width for a clean look
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          // Double tap detected: exit the app
          await SystemNavigator.pop();
        }
      },
      child: widget.child,
    );
  }
}
