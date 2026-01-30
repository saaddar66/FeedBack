import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feedy/data/repositories/feedback_repository.dart';
import 'package:feedy/data/database/database_helper.dart';
import 'package:feedy/domain/use_cases/submit_feedback_use_case.dart';
import 'package:feedy/presentation/providers/feedback_provider.dart';
import 'package:feedy/presentation/providers/public_submission_provider.dart';
import 'package:feedy/presentation/providers/auth_provider.dart';
import 'package:feedy/presentation/providers/menu_provider.dart';
import 'package:feedy/presentation/screens/welcome_screen.dart';
import 'package:feedy/presentation/screens/signup_screen.dart';
import 'package:feedy/presentation/screens/forgot_password_screen.dart';
// Admin screens
import 'package:feedy/presentation/screens/admin/login_screen.dart';
import 'package:feedy/presentation/screens/admin/dashboard_screen.dart';
import 'package:feedy/presentation/screens/admin/configuration_screen.dart';
import 'package:feedy/presentation/screens/admin/survey_list_screen.dart';
import 'package:feedy/presentation/screens/admin/settings_screen.dart';
import 'package:feedy/presentation/screens/admin/feedback_list_screen.dart';
import 'package:feedy/presentation/screens/admin/survey_response_list_screen.dart';
import 'package:feedy/presentation/screens/admin/menu_list_screen.dart';
import 'package:feedy/presentation/screens/admin/menu_editor_screen.dart';
import 'package:feedy/presentation/screens/admin/order_views.dart';
import 'package:feedy/core/routes/route_paths.dart';
// Public screens
import 'package:feedy/presentation/screens/public/feedback_form_screen.dart';
import 'package:feedy/presentation/screens/public/survey_screen.dart';
import 'package:feedy/presentation/screens/public/qr_feedback_web_screen.dart';
import 'package:feedy/presentation/screens/public/public_landing_screen.dart';
import 'package:feedy/presentation/screens/public/public_menu_viewer_screen.dart';
import 'package:feedy/presentation/screens/public/thank_you_screen.dart';
import 'package:feedy/data/database/firestore_database_impl.dart';
import 'package:feedy/data/database/base_database.dart';
import 'dart:ui';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';



import 'package:feedy/presentation/screens/splash_screen.dart';

/// Main entry point of the application
void main() {
  // Ensure Flutter bindings are initialized before any widgets
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;
  
  // Dependencies
  late FeedbackRepository _feedbackRepository;
  late SubmitFeedbackUseCase _submitFeedbackUseCase;
  
  // State
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    
    // Initialize dependencies immediately (sync) so providers can be built
    // The actual DB init happens async in _initializeApp
    final databaseHelper = DatabaseHelper.instance;
    _feedbackRepository = FeedbackRepository(databaseHelper);
    _submitFeedbackUseCase = SubmitFeedbackUseCase(_feedbackRepository);

    _router = GoRouter(
      debugLogDiagnostics: true,

      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('Page not found: ${state.uri.path}'),
        ),
      ),
      
      routes: [
        // Public routes (Prioritized)
        GoRoute(
          path: '/public',
          name: 'public_landing',
          builder: (context, state) {
            developer.log('Building PublicLandingScreen for path: ${state.uri.path}', name: 'Router');
            return const PublicLandingScreen();
          },
        ),
        GoRoute(
          path: '/public/menu',
          name: 'public_menu',
          builder: (context, state) => const PublicMenuViewerScreen(),
        ),
        
        // Root / Welcome
        GoRoute(
          path: '/',
          name: 'welcome',
          builder: (context, state) {
            developer.log('Building WelcomeScreen for path: ${state.uri.path}', name: 'Router');
            return const WelcomeScreen();
          },
          redirect: (context, state) {
            final uid = state.uri.queryParameters['uid'];
            if (uid != null && uid.isNotEmpty) {
               developer.log('Redirecting / to /public because UID found', name: 'Router');
               return '/public?uid=$uid';
            }
            return null;
          },
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
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),

        // Admin flow
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/orders',
          builder: (context, state) => const OrderListScreen(),
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
          path: '/menu',
          redirect: (context, state) {
            final uid = state.uri.queryParameters['uid'];
            if (uid != null && uid.isNotEmpty) {
              return '/public/menu?uid=$uid';
            }
            return null;
          },
          builder: (context, state) => const MenuListScreen(),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => const MenuEditorScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),

        // Result views
        GoRoute(
          path: '/feedback-results',
          builder: (context, state) => const FeedbackListScreen(),
        ),
        GoRoute(
          path: '/survey-results',
          builder: (context, state) => const SurveyResponseListScreen(),
        ),

        // Other Public flow
        GoRoute(
          path: '/feedback',
          builder: (context, state) => const FeedbackFormScreen(),
        ),
        GoRoute(
          path: '/survey',
          builder: (context, state) => const SurveyScreen(),
        ),
        GoRoute(
          path: '/qr-feedback',
          builder: (context, state) => const QrFeedbackWebScreen(),
        ),
        GoRoute(
          path: '/thank-you',
          builder: (context, state) => const ThankYouScreen(),
        ),
      ],
    );

    // Start async init
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await dotenv.load(fileName: ".env");

      final BaseDatabase database = FirestoreDatabaseImpl();
      DatabaseHelper.instance.configure(database);

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      await DatabaseHelper.instance.init();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      developer.log('Initialization failed', error: e);
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FeedbackProvider(_feedbackRepository)),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => PublicSubmissionProvider(_submitFeedbackUseCase)),
      ],
      child: MaterialApp.router(
        title: 'Feedy',
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
        routerConfig: _router,
        builder: (context, child) {
          if (_error != null) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Failed to start app', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
            );
          }

          if (!_isInitialized) {
            return const SplashScreen();
          }

          return child!;
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

