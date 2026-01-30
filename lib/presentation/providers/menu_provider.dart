import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/menu_models.dart';
import 'dart:developer' as developer;

/// State management provider for menu data
/// Manages all menu-related state and business logic
/// Uses ChangeNotifier to notify UI of state changes
class MenuProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State variables
  List<MenuSection> _menus = [];
  MenuSection? _editingMenu;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Getters
  List<MenuSection> get menus => _menus;
  MenuSection? get editingMenu => _editingMenu;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;

  /// Loads all menu sections for a specific user
  Future<void> loadMenus({String? userId}) async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('menu_sections');
      
      if (userId != null && userId.isNotEmpty) {
        query = query.where('ownerId', isEqualTo: userId);
      }
      
      final snapshot = await query.get();
      
      List<MenuSection> menusList = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          menusList.add(MenuSection.fromMap(data));
        } catch (e) {
          developer.log('Skipping invalid menu entry: ${doc.id}', error: e, name: 'MenuProvider');
        }
      }

      // Sort by creation date (newest first)
      menusList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _menus = menusList;
      _isLoading = false;
      _hasError = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      _errorMessage = e.toString();
      developer.log('Error loading menus: $e', error: e, name: 'MenuProvider');
      notifyListeners();
      rethrow;
    }
  }

  /// Starts editing a menu section (or creates a new one if null)
  void startEditingMenu(MenuSection? menu, {String? ownerId}) {
    if (menu != null) {
      // Edit existing menu - create a deep copy
      _editingMenu = MenuSection(
        id: menu.id,
        title: menu.title,
        description: menu.description,
        dishes: menu.dishes.map((d) => MenuDish(
          id: d.id,
          name: d.name,
          description: d.description,
          price: d.price,
          isAvailable: d.isAvailable,
          createdAt: d.createdAt,
        )).toList(),
        isActive: menu.isActive,
        createdAt: menu.createdAt,
        updatedAt: menu.updatedAt,
        ownerId: menu.ownerId,
      );
    } else {
      // Create new menu - generate ID using Firestore doc ID
      final newDocRef = _firestore.collection('menu_sections').doc();
      final now = DateTime.now();
      _editingMenu = MenuSection(
        id: newDocRef.id,
        title: '',
        description: '',
        dishes: [],
        isActive: false,
        createdAt: now,
        updatedAt: now,
        ownerId: ownerId,
      );
    }
    notifyListeners();
  }

  /// Updates the title of the editing menu
  void updateEditingMenuTitle(String title) {
    if (_editingMenu == null) return;
    _editingMenu = _editingMenu!.copyWith(title: title, updatedAt: DateTime.now());
    notifyListeners();
  }

  /// Updates the description of the editing menu
  void updateEditingMenuDescription(String description) {
    if (_editingMenu == null) return;
    _editingMenu = _editingMenu!.copyWith(description: description, updatedAt: DateTime.now());
    notifyListeners();
  }

  /// Adds a new dish to the editing menu
  void addDish(MenuDish dish) {
    if (_editingMenu == null) return;
    final updatedDishes = List<MenuDish>.from(_editingMenu!.dishes)..add(dish);
    _editingMenu = _editingMenu!.copyWith(dishes: updatedDishes, updatedAt: DateTime.now());
    notifyListeners();
  }

  /// Updates a dish at a specific index
  void updateDish(int index, MenuDish dish) {
    if (_editingMenu == null || index < 0 || index >= _editingMenu!.dishes.length) return;
    final updatedDishes = List<MenuDish>.from(_editingMenu!.dishes);
    updatedDishes[index] = dish;
    _editingMenu = _editingMenu!.copyWith(dishes: updatedDishes, updatedAt: DateTime.now());
    notifyListeners();
  }

  /// Removes a dish at a specific index
  void removeDish(int index) {
    if (_editingMenu == null || index < 0 || index >= _editingMenu!.dishes.length) return;
    final updatedDishes = List<MenuDish>.from(_editingMenu!.dishes)..removeAt(index);
    _editingMenu = _editingMenu!.copyWith(dishes: updatedDishes, updatedAt: DateTime.now());
    notifyListeners();
  }

  /// Reorders dishes in the editing menu
  void reorderDishes(int oldIndex, int newIndex) {
    if (_editingMenu == null) return;
    
    final updatedDishes = List<MenuDish>.from(_editingMenu!.dishes);
    
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    
    final dish = updatedDishes.removeAt(oldIndex);
    updatedDishes.insert(newIndex, dish);
    
    _editingMenu = _editingMenu!.copyWith(dishes: updatedDishes, updatedAt: DateTime.now());
    notifyListeners();
  }

  /// Saves the current editing menu to Firestore
  Future<void> saveEditingMenu() async {
    if (_editingMenu == null) {
      throw Exception('No menu is being edited');
    }

    try {
      final menuData = _editingMenu!.toMap();
      
      // Save to Firestore
      await _firestore
          .collection('menu_sections')
          .doc(_editingMenu!.id)
          .set(menuData);

      // Update local list
      final existingIndex = _menus.indexWhere((m) => m.id == _editingMenu!.id);
      if (existingIndex >= 0) {
        _menus[existingIndex] = _editingMenu!;
      } else {
        _menus.add(_editingMenu!);
      }

      // Re-sort
      _menus.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      notifyListeners();
    } catch (e) {
      developer.log('Error saving menu: $e', error: e, name: 'MenuProvider');
      rethrow;
    }
  }

  /// Deletes a menu section by ID
  Future<void> deleteMenu(String menuId) async {
    try {
      await _firestore.collection('menu_sections').doc(menuId).delete();

      // Remove from local list
      _menus.removeWhere((m) => m.id == menuId);
      
      notifyListeners();
    } catch (e) {
      developer.log('Error deleting menu: $e', error: e, name: 'MenuProvider');
      rethrow;
    }
  }

  /// Toggles a menu section's active state
  Future<void> toggleMenuActive(String menuId) async {
    try {
      final menuIndex = _menus.indexWhere((m) => m.id == menuId);
      if (menuIndex < 0) {
        throw Exception('Menu not found');
      }

      final menu = _menus[menuIndex];
      final newActiveState = !menu.isActive;

      // Update in Firestore
      await _firestore.collection('menu_sections').doc(menuId).update({
        'isActive': newActiveState,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Update local state
      _menus[menuIndex] = menu.copyWith(
        isActive: newActiveState,
        updatedAt: DateTime.now(),
      );

      notifyListeners();
    } catch (e) {
      developer.log('Error toggling menu active: $e', error: e, name: 'MenuProvider');
      rethrow;
    }
  }

  /// Clears the editing menu
  void clearEditingMenu() {
    _editingMenu = null;
    notifyListeners();
  }
}
