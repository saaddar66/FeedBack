import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:feedy/data/repositories/feedback_repository.dart';
import 'package:feedy/data/database/database_helper.dart';
import 'package:feedy/presentation/providers/feedback_provider.dart';
import 'package:feedy/presentation/screens/dashboard_screen.dart';
import 'package:feedy/presentation/screens/feedback_form_screen.dart';
// Import firebase_options.dart after running: flutterfire configure
import 'firebase_options.dart';

/// Main entry point of the application
/// Initializes Firebase and sets up the app with Provider for state management
void main() async {
  // Ensure Flutter bindings are initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  // After running 'flutterfire configure', uncomment the line below and comment the defaultOptions line
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization failed: $e');
    // Continue anyway, DatabaseHelper will handle mock mode
  }
  
  // Initialize the database singleton instance
  final databaseHelper = DatabaseHelper.instance;
  await databaseHelper.initDatabase();
  
  // Create repository instance that will handle all data operations
  final feedbackRepository = FeedbackRepository(databaseHelper);
  
  // Start the Flutter app
  runApp(MyApp(feedbackRepository: feedbackRepository));
}

/// Root widget of the application
/// Sets up the MaterialApp with theme, Provider for state management, and GoRouter for navigation
class MyApp extends StatelessWidget {
  final FeedbackRepository feedbackRepository;

  const MyApp({super.key, required this.feedbackRepository});

  @override
  Widget build(BuildContext context) {
    // Create router configuration with URL-based routes
    final router = GoRouter(
      initialLocation: '/dashboard', // Default route
      routes: [
        // Main screen with bottom navigation (handles both routes)
        GoRoute(
          path: '/',
          redirect: (context, state) => '/dashboard',
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const MainScreen(
            initialIndex: 0,
          ),
        ),
        GoRoute(
          path: '/feedback',
          builder: (context, state) => const MainScreen(
            initialIndex: 1,
          ),
        ),
      ],
    );

    // Provide FeedbackProvider to the widget tree using Provider package
    return ChangeNotifierProvider(
      create: (_) => FeedbackProvider(feedbackRepository),
      child: MaterialApp.router(
        title: 'Feedy - Feedback Collection',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Main screen widget that contains bottom navigation
/// Manages navigation between Dashboard and Feedback Form screens
/// Supports URL-based routing for web browsers
class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Current selected tab index (0 = Dashboard, 1 = Feedback Form)
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync tab index with current route when URL changes (e.g., browser back/forward)
    final location = GoRouterState.of(context).uri.path;
    if (location == '/dashboard' && _currentIndex != 0) {
      setState(() => _currentIndex = 0);
    } else if (location == '/feedback' && _currentIndex != 1) {
      setState(() => _currentIndex = 1);
    }
  }

  // List of screens corresponding to each tab
  final List<Widget> _screens = [
    const DashboardScreen(),
    const FeedbackFormScreen(),
  ];

  // List of routes corresponding to each tab
  final List<String> _routes = [
    '/dashboard',
    '/feedback',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive Breakpoint: 640px (Mobile vs Tablet/Desktop)
          if (constraints.maxWidth < 640) {
            // Mobile View: Bottom Navigation
            return Scaffold(
              body: _screens[_currentIndex],
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() => _currentIndex = index);
                  context.go(_routes[index]);
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard),
                    label: 'Dashboard',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.feedback),
                    label: 'Feedback',
                  ),
                ],
              ),
            );
          } else {
            // Desktop/Web View: Side Navigation Rail
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                    context.go(_routes[index]);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.feedback),
                      label: Text('Feedback'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: _screens[_currentIndex],
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
