import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:csv/csv.dart';
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

  Future<void> _importCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      final csvContent = utf8.decode(file.bytes!, allowMalformed: true);
      final rows = const CsvToListConverter().convert(csvContent);

      if (rows.isEmpty) return;

      // Extract section info from first valid row
      bool sectionUpdated = false;
      int importedCount = 0;
      final provider = context.read<MenuProvider>();

      for (var row in rows) {
        if (row.isEmpty) continue;
        
        // Expected format: section_title, section_desc, dish_name, dish_desc, price, is_available
        if (row.length < 3) continue; // Minimum 3 columns required (title, desc, dish_name)

        final sectionTitle = row[0].toString().trim();
        final sectionDesc = row.length > 1 ? row[1].toString().trim() : '';
        final dishName = row[2].toString().trim();
        final dishDesc = row.length > 3 ? row[3].toString().trim() : '';
        
        // Parse dish price
        double price = 0.0;
        if (row.length > 4) {
          final priceRaw = row[4];
          if (priceRaw is num) {
            price = priceRaw.toDouble();
          } else {
            price = double.tryParse(priceRaw.toString().replaceAll('\$', '').trim()) ?? 0.0;
          }
        }

        // Parse availability
        bool isAvailable = true;
        if (row.length > 5) {
          final availRaw = row[5].toString().toLowerCase().trim();
          isAvailable = availRaw != 'false' && availRaw != '0' && availRaw != 'no';
        }

        // Update section info once
        if (!sectionUpdated) {
          if (sectionTitle.isNotEmpty) _titleController.text = sectionTitle;
          if (sectionDesc.isNotEmpty) _descriptionController.text = sectionDesc;
          
          provider.updateEditingMenuTitle(_titleController.text);
          provider.updateEditingMenuDescription(_descriptionController.text);
          sectionUpdated = true;
        }

        if (dishName.isEmpty) continue;

        final newDish = MenuDish(
          id: DateTime.now().millisecondsSinceEpoch.toString() + importedCount.toString(),
          name: dishName,
          description: dishDesc,
          price: price,
          isAvailable: isAvailable,
        );

        provider.addDish(newDish);
        importedCount++;
      }

      if (importedCount > 0) {
        setState(() {
          _currentSection = provider.editingMenu;
          _hasUnsavedChanges = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported $importedCount dishes from CSV'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  void _toggleDishVisibility(int index, MenuDish dish) {
    final updatedDish = dish.copyWith(isAvailable: !dish.isAvailable);
    final provider = context.read<MenuProvider>();
    provider.updateDish(index, updatedDish);
    
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
    // Track selected image file/bytes
    FilePickerResult? _pickedImage;
    String? _currentImageUrl = dish?.imageUrl;
    final _dialogFormKey = GlobalKey<FormState>();
    bool _isUploading = false; // Local state for dialog

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(dish == null ? 'Add Dish' : 'Edit Dish'),
            content: SingleChildScrollView(
              child: Form(
                key: _dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image Picker Section
                    GestureDetector(
                      onTap: () async {
                         final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            allowMultiple: false,
                            withData: true, // Need bytes for web/upload
                         );
                         if (result != null) {
                           setState(() {
                             _pickedImage = result;
                           });
                         }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[400]!),
                          image: _pickedImage != null && _pickedImage!.files.first.bytes != null
                                ? DecorationImage(
                                    image: MemoryImage(_pickedImage!.files.first.bytes!),
                                    fit: BoxFit.cover,
                                  )
                                : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(_currentImageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null),
                        ),
                        child: (_pickedImage == null && (_currentImageUrl == null || _currentImageUrl!.isEmpty))
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                                  Text('Tap to add image', style: TextStyle(color: Colors.grey)),
                                ],
                              )
                            : null,
                      ),
                    ),
                    if (_pickedImage != null || (_currentImageUrl != null && _currentImageUrl!.isNotEmpty))
                       Padding(
                         padding: const EdgeInsets.only(top: 8),
                         child: TextButton.icon(
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Remove Image', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                               setState(() {
                                 _pickedImage = null;
                                 _currentImageUrl = null;
                               });
                            },
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                         ),
                       ),
                    
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: dishNameController,
                      decoration: const InputDecoration(
                        labelText: 'Dish Name *',
                        hintText: 'e.g., Margherita Pizza',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: dishDescController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'e.g., Fresh mozzarella, tomato, basil',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: dishPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Price *',
                        hintText: 'e.g., 12.99',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                         if (val == null || val.trim().isEmpty) return 'Price is required';
                         final price = double.tryParse(val.trim());
                         if (price == null) return 'Invalid price';
                         if (price <= 0) return 'Price must be greater than 0';
                         return null;
                      },
                    ),
                    if (_isUploading) ...[
                       const SizedBox(height: 16),
                       const LinearProgressIndicator(),
                       const Text('Uploading image...', style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: _isUploading ? null : () async {
                  if (!_dialogFormKey.currentState!.validate()) return;
                  
                  setState(() => _isUploading = true);
                  
                  // Handle Image Upload if new image picked
                  String? finalImageUrl = _currentImageUrl;
                  
                  if (_pickedImage != null && _pickedImage!.files.first.bytes != null) {
                      try {
                          final fileBytes = _pickedImage!.files.first.bytes!;
                          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_pickedImage!.files.first.name}';
                          // We need 'firebase_storage' package for this
                          final storageRef = FirebaseStorage.instance
                              .ref()
                              .child('dishes')
                              .child(fileName); // Simple path
                          
                          final metadata = SettableMetadata(
                              contentType: 'image/jpeg', // Force jpeg or detect? mime_type in picker result usually
                              customMetadata: {'uploaded_by': 'admin_app'},
                          );

                          // Upload
                          // Note: This relies on firebase_storage import which we need to add to file imports
                          await storageRef.putData(fileBytes, metadata);
                          finalImageUrl = await storageRef.getDownloadURL();
                          
                      } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error uploading image: $e')),
                          );
                          setState(() => _isUploading = false);
                          return;
                      }
                  }

                  final price = double.parse(dishPriceController.text.trim());
                  
                  final updatedDish = MenuDish(
                    id: dish?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: dishNameController.text.trim(),
                    description: dishDescController.text.trim(),
                    price: price,
                    isAvailable: dish?.isAvailable ?? true,
                    createdAt: dish?.createdAt,
                    imageUrl: finalImageUrl,
                  );

                  final provider = context.read<MenuProvider>();

                  if (index != null) {
                    provider.updateDish(index, updatedDish);
                  } else {
                    provider.addDish(updatedDish);
                  }

                  // Update parent state is tricky from inside dialog if using setState of dialog
                  // But 'provider' update is global state.
                  // We just need to trigger rebuild of main screen.
                  // The main screen rebuilds on 'setState' inside _saveMenuSection BUT
                  // _showDishDialog calls setState on parent previously inside action.
                  // Since we are async now, we can't easily access parent setState directly unless passed down 
                  // or handled after await.
                  // Actually, just calling provider methods updates the data object in provider.
                  // We need to sync local _currentSection with provider.editingMenu.
                  
                  // Close dialog first
                  if (context.mounted) Navigator.pop(context);
                  
                  // Then update parent UI
                  this.setState(() {
                      _currentSection = provider.editingMenu;
                      _hasUnsavedChanges = true;
                  });
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
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
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _importCsv,
              tooltip: 'Import from CSV',
            ),
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: dish.isAvailable ? Colors.black : Colors.grey,
                                decoration: dish.isAvailable ? null : TextDecoration.lineThrough,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (dish.description.isNotEmpty)
                                  Text(
                                    dish.description,
                                    style: TextStyle(
                                      color: dish.isAvailable ? null : Colors.grey,
                                    ),
                                  ),
                                Text(
                                  '\$${dish.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: dish.isAvailable ? Colors.green : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                    decoration: dish.isAvailable ? null : TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    dish.isAvailable ? Icons.visibility : Icons.visibility_off,
                                    size: 20,
                                    color: dish.isAvailable ? Colors.green : Colors.grey,
                                  ),
                                  onPressed: () => _toggleDishVisibility(index, dish),
                                  tooltip: dish.isAvailable ? 'Hide Dish' : 'Show Dish',
                                ),
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
