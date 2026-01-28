import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/menu_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/menu_models.dart';
import 'package:intl/intl.dart';

/// Production-ready screen displaying all menu sections with loading states
/// Allows creating, editing, deleting, and toggling active menu status
class MenuListScreen extends StatefulWidget {
  const MenuListScreen({super.key});

  @override
  State<MenuListScreen> createState() => _MenuListScreenState();
}

class _MenuListScreenState extends State<MenuListScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final Set<String> _processingIds = {}; // Track operations in progress

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  /// Loads all menus with proper loading and error states
  Future<void> _loadMenus() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final userId = context.read<AuthProvider>().user?.id.toString();
      await context.read<MenuProvider>().loadMenus(userId: userId); // Fetch all menus for this user
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        
        _showErrorSnackbar('Error loading menus: $e');
      }
    }
  }

  /// Creates new menu and navigates to editor
  Future<void> _createNewMenu() async {
    try {
      final userId = context.read<AuthProvider>().user?.id.toString();
      context.read<MenuProvider>().startEditingMenu(null, ownerId: userId); // Initialize blank menu
      await context.push('/menu/edit');
      
      if (mounted) {
         await _loadMenus(); // Refresh list after returning
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error creating menu: $e');
      }
    }
  }

  /// Opens existing menu in edit mode
  Future<void> _editMenu(MenuSection menu) async {
    if (_processingIds.contains(menu.id)) return;
    
    try {
      context.read<MenuProvider>().startEditingMenu(menu); // Load menu into editor state
      await context.push('/menu/edit');
      
      if (mounted) {
         await _loadMenus(); // Refresh list to show any changes
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error editing menu: $e');
      }
    }
  }

  /// Deletes menu with optimistic UI update and rollback
  void _deleteMenu(BuildContext context, MenuSection menu) {
    if (_processingIds.contains(menu.id)) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Menu'),
        content: Text('Are you sure you want to delete "${menu.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              
              // Mark as processing
              setState(() => _processingIds.add(menu.id));
              
              try {
                await context.read<MenuProvider>().deleteMenu(menu.id); // Permanently remove menu
                
                if (context.mounted) {
                  _showSuccessSnackbar('Menu deleted successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  _showErrorSnackbar('Failed to delete menu: $e');
                }
              } finally {
                if (mounted) {
                  setState(() => _processingIds.remove(menu.id));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Toggles menu active status
  Future<void> _toggleMenuActive(MenuSection menu) async {
    if (_processingIds.contains(menu.id)) return;
    
    // Mark as processing
    setState(() => _processingIds.add(menu.id));
    
    final wasActive = menu.isActive;
    
    try {
      await context.read<MenuProvider>().toggleMenuActive(menu.id); // Set active/inactive in DB
      
      if (mounted) {
        _showSuccessSnackbar(wasActive ? 'Menu deactivated' : 'Menu activated');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error toggling menu: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(menu.id));
      }
    }
  }

  /// Shows success message in green snackbar
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows error message in red snackbar
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadMenus,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menus = context.watch<MenuProvider>().menus; // Listen to menu list changes


    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadMenus,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(menus),
      floatingActionButton: (!_isLoading && !_hasError)
          ? FloatingActionButton(
              onPressed: _createNewMenu,
              tooltip: 'Create New Menu',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// Builds appropriate body based on loading error empty states
  Widget _buildBody(List<MenuSection> menus) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading menus...',
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
              'Failed to load menus',
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
              onPressed: _loadMenus,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (menus.isEmpty) {
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
              'No menus found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first menu to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createNewMenu,
              icon: const Icon(Icons.add),
              label: const Text('Create New Menu'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final menu = menus[index];
        return _buildMenuCard(context, menu);
      },
    );
  }

  /// Builds menu card with all actions and loading states
  Widget _buildMenuCard(BuildContext context, MenuSection menu) {
    final isProcessing = _processingIds.contains(menu.id); // Check if operation pending for this item

    
    return Opacity(
      opacity: isProcessing ? 0.5 : 1.0,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: menu.isActive 
              ? const BorderSide(color: Colors.green, width: 2) 
              : BorderSide.none,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: isProcessing ? null : () => _editMenu(menu),
          title: Text(
            menu.title.isEmpty ? 'Untitled Menu' : menu.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${menu.dishes.length} Dishes • Created ${DateFormat('MMM d, y').format(menu.createdAt)}',
              ),
              if (menu.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    menu.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isProcessing)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                // Power button with validation
                IconButton(
                  icon: Icon(
                    Icons.power_settings_new,
                    color: menu.isActive ? Colors.green : Colors.red,
                    size: 28,
                  ),
                  tooltip: menu.isActive ? 'Active (Turn Off)' : 'Inactive (Turn On)',
                  onPressed: () {
                    // Validate before toggling
                    if (menu.dishes.isEmpty) {
                      _showErrorSnackbar('Cannot activate a menu with no dishes');
                      return;
                    }
                    _toggleMenuActive(menu);
                  },
                ),
                const SizedBox(width: 8),
                // Delete button with validation
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () {
                    // Warn if deleting the only active menu
                    final menus = context.read<MenuProvider>().menus;
                    final activeMenus = menus.where((m) => m.isActive).length;
                    
                    if (menu.isActive && activeMenus == 1) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Warning'),
                          content: const Text(
                            'This is your only active menu. Deleting it will leave you with no active menus. Continue?'
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _deleteMenu(context, menu);
                              },
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete Anyway'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      _deleteMenu(context, menu);
                    }
                  },
                ),
              ],
            ],
          ),
          isThreeLine: menu.description.isNotEmpty,
        ),
      ),
    );
  }
}