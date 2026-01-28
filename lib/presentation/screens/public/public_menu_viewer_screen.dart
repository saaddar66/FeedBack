import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/menu_models.dart';
import 'dart:developer' as developer;

/// Public read-only menu viewer for customers
/// Displays active menus without requiring authentication
/// Loads data directly from Firebase RTDB
class PublicMenuViewerScreen extends StatefulWidget {
  const PublicMenuViewerScreen({super.key});

  @override
  State<PublicMenuViewerScreen> createState() => _PublicMenuViewerScreenState();
}

class _PublicMenuViewerScreenState extends State<PublicMenuViewerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<MenuSection> _menus = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPublicMenus();
  }

  /// Loads active menus for public viewing
  Future<void> _loadPublicMenus() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Get ownerId from query parameters
      final state = GoRouterState.of(context);
      final ownerId = state.uri.queryParameters['uid'];

      developer.log('Loading public menus for owner: $ownerId', name: 'PublicMenuDebug');

      Query<Map<String, dynamic>> query = _firestore.collection('menu_sections');
      
      // Filter by owner if provided
      if (ownerId != null && ownerId.isNotEmpty) {
        query = query.where('ownerId', isEqualTo: ownerId);
      }
      
      // Only show active menus
      query = query.where('isActive', isEqualTo: true);
      
      final snapshot = await query.get();
      
      List<MenuSection> menusList = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          final menu = MenuSection.fromMap(data);
          
          developer.log('Found menu: "${menu.title}" (ID: ${menu.id}) - Active: ${menu.isActive}, Owner: ${menu.ownerId}', 
              name: 'PublicMenuDebug');
          
          menusList.add(menu);
        } catch (e) {
          developer.log('Skipping invalid menu entry: ${doc.id}', error: e, name: 'PublicMenuViewer');
        }
      }

      developer.log('Loaded ${menusList.length} active menus', name: 'PublicMenuDebug');

      // Sort by title
      menusList.sort((a, b) => a.title.compareTo(b.title));

      if (mounted) {
        setState(() {
          _menus = menusList;
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error loading public menus: $e', error: e, name: 'PublicMenuViewer');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Our Menu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading menu...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load menu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPublicMenus,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_menus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No menu available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check back later',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPublicMenus,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _menus.length,
        itemBuilder: (context, index) {
          final menu = _menus[index];
          return _buildMenuSection(menu);
        },
      ),
    );
  }

  Widget _buildMenuSection(MenuSection menu) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Icon(
                  Icons.restaurant,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menu.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (menu.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          menu.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            
            // Dishes list
            if (menu.dishes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No items in this section',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ...menu.dishes.where((d) => d.isAvailable).map((dish) {
                return _buildDishItem(dish);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDishItem(MenuDish dish) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dish details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (dish.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    dish.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Price
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '\$${dish.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
