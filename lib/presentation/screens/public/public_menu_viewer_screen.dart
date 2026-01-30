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
  // Use getter to access instance lazily to avoid init crashes
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  
  List<MenuSection> _menus = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Defer loading until after the first frame so 'context' is fully available
    // for GoRouterState.of(context)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPublicMenus();
    });
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
      
      // Filter isActive in memory to avoid composite index usage
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
          
          
          if (menu.isActive) {
            menusList.add(menu);
          }
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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              // If opened directly via deep link, go to public landing
              final state = GoRouterState.of(context);
              final ownerId = state.uri.queryParameters['uid'];
              if (ownerId != null) {
                context.go('/public?uid=$ownerId');
              } else {
                context.go('/public');
              }
            }
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  // Cart state: dishId -> quantity
  final Map<String, int> _cart = {};
  final TextEditingController _tableNumberController = TextEditingController();

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

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPublicMenus,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _menus.length,
              itemBuilder: (context, index) {
                final menu = _menus[index];
                return _buildMenuSection(menu);
              },
            ),
          ),
        ),
        if (_cart.isNotEmpty) _buildBottomOrderBar(),
      ],
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
    // Unique key for the cart is simpler if IDs are unique across sections
    // If not, we might need a composite key, but let's assume unique IDs for now
    final qty = _cart[dish.id] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
                const SizedBox(height: 8),
                Text(
                  '\$${dish.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Quantity Controls
          if (qty == 0)
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _cart[dish.id] = 1;
                });
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Add'),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: () {
                      setState(() {
                        if (qty > 1) {
                          _cart[dish.id] = qty - 1;
                        } else {
                          _cart.remove(dish.id);
                        }
                      });
                    },
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                  Text(
                    '$qty',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () {
                      setState(() {
                        _cart[dish.id] = qty + 1;
                      });
                    },
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomOrderBar() {
    double total = 0.0;
    int itemCount = 0;

    // Calculate total
    for (var section in _menus) {
      for (var dish in section.dishes) {
        if (_cart.containsKey(dish.id)) {
          final qty = _cart[dish.id]!;
          total += dish.price * qty;
          itemCount += qty;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$itemCount Items',
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _showTableNumberDialog(total),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Place Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showTableNumberDialog(double total) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Table Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please enter your table number to complete the order.'),
            const SizedBox(height: 16),
            TextField(
              controller: _tableNumberController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Table Number',
                hintText: 'e.g., 5',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final tableNum = _tableNumberController.text.trim();
              if (tableNum.isNotEmpty) {
                Navigator.of(context).pop();
                _submitOrder(tableNum, total);
              }
            },
            child: const Text('Confirm Order'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder(String tableNumber, double totalAmount) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final state = GoRouterState.of(context);
      final ownerId = state.uri.queryParameters['uid'];
      
      // Prepare items list
      List<Map<String, dynamic>> orderItems = [];
      for (var section in _menus) {
        for (var dish in section.dishes) {
          if (_cart.containsKey(dish.id)) {
            orderItems.add({
              'dishId': dish.id,
              'name': dish.name,
              'price': dish.price,
              'quantity': _cart[dish.id],
              'total': dish.price * _cart[dish.id]!,
            });
          }
        }
      }

      final orderData = {
        'ownerId': ownerId,
        'tableNumber': tableNumber,
        'items': orderItems,
        'totalAmount': totalAmount,
        'status': 'pending', // pending, completed, cancelled
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('orders').add(orderData);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        
        // Show success
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Order Placed!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                Text('Your order for Table $tableNumber has been sent to the kitchen.'),
                const SizedBox(height: 8),
                Text('Total: \$${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _cart.clear();
                    _tableNumberController.clear();
                  });
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
