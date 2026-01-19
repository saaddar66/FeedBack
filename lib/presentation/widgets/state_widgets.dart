import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final String message;
  const LoadingWidget({super.key, this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}

class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorStateWidget({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Icon(Icons.error_outline, size: 48, color: Colors.red),
             const SizedBox(height: 16),
             Text(
               message,
               textAlign: TextAlign.center,
               style: const TextStyle(fontSize: 16),
             ),
             if (onRetry != null) ...[
               const SizedBox(height: 24),
               ElevatedButton.icon(
                 onPressed: onRetry,
                 icon: const Icon(Icons.refresh),
                 label: const Text('Retry'),
               ),
             ],
          ],
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyStateWidget({super.key, required this.message, this.icon = Icons.inbox});

  @override
  Widget build(BuildContext context) {
     return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Icon(icon, size: 64, color: Colors.grey.shade300),
             const SizedBox(height: 16),
             Text(
               message,
               textAlign: TextAlign.center,
               style: const TextStyle(color: Colors.grey, fontSize: 16),
             ),
          ],
        ),
      ),
    );
  }
}
