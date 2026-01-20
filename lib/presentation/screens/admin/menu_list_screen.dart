import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/survey_models.dart';

/// OMS Screen for managing Menu Categories and Dishes
class MenuListScreen extends StatefulWidget {
  const MenuListScreen({super.key});

  @override
  State<MenuListScreen> createState() => _MenuListScreenState();
}

class _MenuListScreenState extends State<MenuListScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final Set<String> _processingIds = {}; 

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  /// Fetches menu categories tied to the specific Restaurant/User ID
  // Loads all "Surveys" (Menu Sections) for the current user from the provider
  Future<void> _loadMenus() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final userId = context.read<AuthProvider>().user?.id.toString(); // Get current admin ID
      // Logic remains the same: fetching forms tied to creatorId
      await context.read<FeedbackProvider>().loadSurveys(userId: userId); // Fetch data from Firebase
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        _showErrorSnackbar('Error loading menu: $e');
      }
    }
  }

  /// Creates a new Menu Section (e.g., "Appetizers")
  // Initializes a new blank Survey object which will act as a Menu Section
  Future<void> _createNewMenuSection() async {
    try {
      final userId = context.read<AuthProvider>().user?.id.toString();
      // Start editing a blank form tied to this user
      context.read<FeedbackProvider>().startEditingSurvey(null, creatorId: userId); // Prepare provider state
      await context.push('/config/edit'); // Navigate to the editor screen
      if (mounted) await _loadMenus();
    } catch (e) {
      if (mounted) _showErrorSnackbar('Error creating section: $e');
    }
  }

  /// Opens a section to add/edit Dishes
  // Loads an existing section into the editor to modify dishes (questions)
  Future<void> _editMenuSection(SurveyForm section) async {
    if (_processingIds.contains(section.id)) return;
    context.read<FeedbackProvider>().startEditingSurvey(section);
    await context.push('/config/edit');
    if (mounted) await _loadMenus();
  }

  // ... (Keep the existing _deleteSurvey and _toggleSurveyActive logic, just rename variables) ...

  @override
  Widget build(BuildContext context) {
    // We are still watching 'surveys' but interpreting them as 'Menu Sections'
    final menuSections = context.watch<FeedbackProvider>().surveys; // Listen to real-time updates

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadMenus,
          ),
        ],
      ),
      body: _buildBody(menuSections),
      floatingActionButton: (!_isLoading && !_hasError)
          ? FloatingActionButton.extended(
              onPressed: _createNewMenuSection,
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Add Section'),
            )
          : null,
    );
  }

  Widget _buildBody(List<SurveyForm> sections) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    if (sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_meals_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Your digital menu is empty', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _createNewMenuSection, child: const Text('Create Appetizers or Mains')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sections.length,
      itemBuilder: (context, index) => _buildMenuCard(context, sections[index]),
    );
  }

  Widget _buildMenuCard(BuildContext context, SurveyForm section) {
    final isProcessing = _processingIds.contains(section.id);
    
    return Opacity(
      opacity: isProcessing ? 0.5 : 1.0,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: section.isActive ? const BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
        ),
        child: ListTile(
          onTap: isProcessing ? null : () => _editMenuSection(section),
          title: Text(section.title.isEmpty ? 'New Section' : section.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          // Shows dish count (questions) and last edit timestamp
          subtitle: Text('${section.questions.length} Dishes • Last updated ${DateFormat('MMM d').format(section.createdAt)}'),
          trailing: IconButton(
            icon: Icon(Icons.visibility, color: section.isActive ? Colors.blue : Colors.grey),
            tooltip: section.isActive ? 'Displayed on Digital Menu' : 'Hidden from Menu',
            onPressed: () => _toggleSurveyActive(section), // Logic to toggle visibility
          ),
        ),
      ),
    );
  }
  
  void _showErrorSnackbar(String msg) { /* same as original */ }
  void _showSuccessSnackbar(String msg) { /* same as original */ }
}