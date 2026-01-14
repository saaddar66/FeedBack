import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:feedy/config/database_config.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feedy/data/repositories/feedback_repository.dart';
import 'package:feedy/data/database/database_helper.dart';
import 'package:feedy/domain/use_cases/submit_feedback_use_case.dart';
import 'package:feedy/presentation/providers/feedback_provider.dart';
import 'package:feedy/presentation/providers/public_submission_provider.dart';
import 'package:feedy/presentation/providers/auth_provider.dart';
import 'package:feedy/presentation/screens/welcome_screen.dart';
import 'package:feedy/presentation/screens/signup_screen.dart';
// Admin screens
import 'package:feedy/presentation/screens/admin/login_screen.dart';
import 'package:feedy/presentation/screens/admin/dashboard_screen.dart';
import 'package:feedy/presentation/screens/admin/configuration_screen.dart';
import 'package:feedy/presentation/screens/admin/survey_list_screen.dart';
import 'package:feedy/presentation/screens/admin/settings_screen.dart';
import 'package:feedy/presentation/screens/admin/feedback_list_screen.dart';
import 'package:feedy/presentation/screens/admin/survey_response_list_screen.dart';
// Public screens
import 'package:feedy/presentation/screens/public/feedback_form_screen.dart';
import 'package:feedy/presentation/screens/public/survey_screen.dart';
import 'package:feedy/presentation/screens/public/qr_feedback_web_screen.dart';
import 'package:feedy/presentation/screens/public/thank_you_screen.dart';
// Import firebase_options.dart after running: flutterfire configure
import 'firebase_options.dart';

import 'dart:ui'; // For PlatformDispatcher
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Main entry point of the application
/// Initializes Firebase and sets up the app with Provider for state management
void main() async {
  // Ensure Flutter bindings are initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables for secure key management
  await dotenv.load(fileName: ".env");
  
  // Initialize database factory based on platform (Web, Desktop, Mobile)
  configureDatabase();
  
  // Initialize Firebase (and Crashlytics)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Enable Crashlytics collection
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

  } catch (e) {
    print('Firebase initialization failed: $e');
    // Continue anyway, DatabaseHelper generally handles offline/mock
  }
  
  // Initialize the database singleton
  final databaseHelper = DatabaseHelper.instance;
  // Note: We removed explicit "Mock Mode" fallback for production. 
  // It will now try to use Firebase Offline persistence.
  
  // Create repository instance that will handle all data operations and abstraction
  final feedbackRepository = FeedbackRepository(databaseHelper);
  
  // Initialize use cases for dependency injection into providers
  final submitFeedbackUseCase = SubmitFeedbackUseCase(feedbackRepository);
  
  // Start the Flutter app with necessary dependencies injected
  runApp(MyApp(
    feedbackRepository: feedbackRepository,
    submitFeedbackUseCase: submitFeedbackUseCase,
  ));
}

/// Root widget of the application
/// Sets up the MaterialApp with theme, Provider for state management, and GoRouter for navigation
class MyApp extends StatelessWidget {
  final FeedbackRepository feedbackRepository;
  final SubmitFeedbackUseCase submitFeedbackUseCase;

  const MyApp({
    super.key,
    required this.feedbackRepository,
    required this.submitFeedbackUseCase,
  });

  @override
  Widget build(BuildContext context) {
    // Create router configuration with URL-based routes
    final router = GoRouter(
      initialLocation: '/', // Welcome screen as entry point
      routes: [
        // Initial route - Welcome screen
        GoRoute(
          path: '/',
          builder: (context, state) => const WelcomeScreen(),
        ),
        // Auth flow
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignupScreen(),
        ),
        // Admin flow
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/config',
          builder: (context, state) => const SurveyListScreen(),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => const ConfigurationScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        // Result views (Admin)
        GoRoute(
          path: '/feedback-results',
          builder: (context, state) => const FeedbackListScreen(),
        ),
        GoRoute(
          path: '/survey-results',
          builder: (context, state) => const SurveyResponseListScreen(),
        ),
        // Public flow
        GoRoute(
          path: '/feedback',
          builder: (context, state) => const FeedbackFormScreen(),
        ),
        GoRoute(
          path: '/survey',
          builder: (context, state) => const SurveyScreen(),
        ),
        // QR code web form
        GoRoute(
          path: '/qr-feedback',
          builder: (context, state) => const QrFeedbackWebScreen(),
        ),
        // Thank you page
        GoRoute(
          path: '/thank-you',
          builder: (context, state) => const ThankYouScreen(),
        ),
      ],
    );

    // Provide providers to the widget tree using MultiProvider
    return MultiProvider(
      providers: [
        // Auth provider (session management)
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        // Admin provider (full access)
        ChangeNotifierProvider(
          create: (_) => FeedbackProvider(feedbackRepository),
        ),
        // Public provider (submission only)
        ChangeNotifierProvider(
          create: (_) => PublicSubmissionProvider(submitFeedbackUseCase),
        ),
      ],
      child: MaterialApp.router(
        title: 'Feedy - Feedback Collection',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C63FF),
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.interTextTheme().apply(
            fontFamily: GoogleFonts.inter().fontFamily,
            bodyColor: Colors.black87,
            displayColor: Colors.black87,
          ),
          fontFamily: GoogleFonts.inter().fontFamily,
          fontFamilyFallback: const ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: const Color(0xFF6C63FF), width: 2),
            ),
          ),
        ),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

