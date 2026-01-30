import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/menu_provider.dart';
import '../../../data/models/menu_models.dart';

/// Menu editor screen for creating and editing menu sections
/// Completely independent from survey logic
class MenuEditorScreen extends StatefulWidget {
  const MenuEditorScreen({super.key});

  @override
  State<MenuEditorScreen> createState() => _MenuEditorScreenState();
}

class _MenuEditorScreenState extends State<MenuEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  MenuSection? _currentSection;

  @override
  void initState() {
    super.initState();
    _loadCurrentSection();
  }

  void _loadCurrentSection() {
    final provider = context.read<MenuProvider>();
    _currentSection = provider.editingMenu;
    
    if (_currentSection != null) {
      _titleController.text = _currentSection!.title;
      _descriptionController.text = _currentSection!.description;
    }

    _titleController.addListener(_markAsChanged);
    _descriptionController.addListener(_markAsChanged);
  }

  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  Future<void> _saveMenuSection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<MenuProvider>();

      // Update the editing menu title and description
      provider.updateEditingMenuTitle(_titleController.text.trim());
      provider.updateEditingMenuDescription(_descriptionController.text.trim());
      
      // Save to Firestore
      await provider.saveEditingMenu();

      if (mounted) {
        _hasUnsavedChanges = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu section saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addDish() {
    _showDishDialog(null, null);
  }

  void _editDish(MenuDish dish, int index) {
    _showDishDialog(dish, index);
  }

  void _deleteDish(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Dish?'),
        content: const Text('This dish will be removed from the menu section.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final provider = context.read<MenuProvider>();
    provider.removeDish(index);
    
    setState(() {
      _currentSection = provider.editingMenu;
      _hasUnsavedChanges = true;
    });
  }

  void _showDishDialog(MenuDish? dish, int? index) {
    final dishNameController = TextEditingController(text: dish?.name ?? '');
    final dishDescController = TextEditingController(text: dish?.description ?? '');
    final dishPriceController = TextEditingController(
      text: dish != null ? dish.price.toStringAsFixed(2) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dish == null ? 'Add Dish' : 'Edit Dish'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dishNameController,
                decoration: const InputDecoration(
                  labelText: 'Dish Name *',
                  hintText: 'e.g., Margherita Pizza',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dishDescController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g., Fresh mozzarella, tomato, basil',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dishPriceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  hintText: 'e.g., 12.99',
                  prefixText: '\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final dishName = dishNameController.text.trim();
              if (dishName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dish name is required')),
                );
                return;
              }

              // Parse price
              double price = 0.0;
              try {
                price = double.parse(dishPriceController.text.trim());
              } catch (e) {
                // Keep price as 0.0 if parsing fails
              }

              final updatedDish = MenuDish(
                id: dish?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                name: dishName,
                description: dishDescController.text.trim(),
                price: price,
                isAvailable: dish?.isAvailable ?? true,
                createdAt: dish?.createdAt,
              );

              final provider = context.read<MenuProvider>();

              if (index != null) {
                provider.updateDish(index, updatedDish);
              } else {
                provider.addDish(updatedDish);
              }

              setState(() {
                _currentSection = provider.editingMenu;
                _hasUnsavedChanges = true;
              });

              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dishes = _currentSection?.dishes ?? [];

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(_currentSection?.id.isEmpty ?? true ? 'New Menu Section' : 'Edit Menu Section'),
          actions: [
            if (_hasUnsavedChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Unsaved',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveMenuSection,
              tooltip: 'Save Section',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Section Details Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Section Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Section Name *',
                                hintText: 'e.g., Appetizers, Main Course',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value?.trim().isEmpty ?? true) {
                                  return 'Section name is required';
                                }
                                return null;
                              },
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description (Optional)',
                                hintText: 'Brief description of this menu section',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Dishes Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dishes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addDish,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Dish'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Dishes List
                    if (dishes.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.restaurant,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No dishes yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _addDish,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Your First Dish'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...dishes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final dish = entry.value;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${index + 1}'),
                            ),
                            title: Text(
                              dish.name.isEmpty ? 'Unnamed Dish' : dish.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (dish.description.isNotEmpty)
                                  Text(dish.description),
                                Text(
                                  '\$${dish.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _editDish(dish, index),
                                  tooltip: 'Edit Dish',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                  onPressed: () => _deleteDish(index),
                                  tooltip: 'Delete Dish',
                                ),
                              ],
                            ),
                            isThreeLine: dish.description.isNotEmpty,
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}
