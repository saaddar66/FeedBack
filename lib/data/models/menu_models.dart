/// Model class representing a dish in a menu section
class MenuDish {
  final String id;
  String name;
  String description;
  double price;
  bool isAvailable;
  final DateTime createdAt;

  MenuDish({
    required this.id,
    required this.name,
    this.description = '',
    this.price = 0.0,
    this.isAvailable = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Creates a copy of the dish with updated values
  MenuDish copyWith({
    String? name,
    String? description,
    double? price,
    bool? isAvailable,
  }) {
    return MenuDish(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt,
    );
  }

  /// Converts the dish object to a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'isAvailable': isAvailable,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Creates a MenuDish from a database Map
  factory MenuDish.fromMap(Map<String, dynamic> map) {
    // Robust parsing for price
    double parsedPrice = 0.0;
    if (map['price'] is num) {
      parsedPrice = (map['price'] as num).toDouble();
    } else if (map['price'] != null) {
      parsedPrice = double.tryParse(map['price'].toString()) ?? 0.0;
    }

    // Robust parsing for isAvailable
    bool parsedIsAvailable = true;
    if (map.containsKey('isAvailable')) {
      final val = map['isAvailable'];
      if (val is bool) {
        parsedIsAvailable = val;
      } else {
        parsedIsAvailable = val.toString().toLowerCase() == 'true';
      }
    }

    return MenuDish(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      price: parsedPrice,
      isAvailable: parsedIsAvailable,
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  /// Safely parses a DateTime from various formats
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return DateTime.now();
    }
  }
}

/// Model class representing a complete menu section
class MenuSection {
  final String id;
  String title;
  String description;
  List<MenuDish> dishes;
  bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ownerId;

  MenuSection({
    required this.id,
    required this.title,
    this.description = '',
    List<MenuDish>? dishes,
    this.isActive = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.ownerId,
  })  : dishes = dishes ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Creates a copy of the menu section with updated values
  MenuSection copyWith({
    String? title,
    String? description,
    List<MenuDish>? dishes,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return MenuSection(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      dishes: dishes ?? this.dishes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      ownerId: ownerId,
    );
  }

  /// Converts the menu section object to a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dishes': dishes.map((d) => d.toMap()).toList(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'ownerId': ownerId,
    };
  }

  /// Creates a MenuSection from a database Map
  factory MenuSection.fromMap(Map<String, dynamic> map) {
    List<MenuDish> parsedDishes = [];

    if (map['dishes'] != null) {
      final dishesData = map['dishes'];

      try {
        if (dishesData is List) {
          // Handle as List (standard JSON array)
          for (var d in dishesData) {
            if (d != null && d is Map) {
              try {
                parsedDishes.add(MenuDish.fromMap(Map<String, dynamic>.from(d)));
              } catch (e) {
                print('Skipping invalid dish in list: $e');
              }
            }
          }
        } else if (dishesData is Map) {
          // Handle as Map (Firebase object structure {id: {data}})
          dishesData.forEach((key, value) {
            if (value != null && value is Map) {
              try {
                final dishMap = Map<String, dynamic>.from(value);
                // Ensure ID is set (use key if ID is missing in value)
                final existingId = dishMap['id'];
                if (existingId == null || existingId.toString().isEmpty) {
                  dishMap['id'] = key.toString();
                }
                parsedDishes.add(MenuDish.fromMap(dishMap));
              } catch (e) {
                print('Skipping invalid dish ($key): $e');
              }
            }
          });
        }
      } catch (e) {
        print('Error processing dishes structure: $e');
      }
    }

    return MenuSection(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled Menu',
      description: map['description']?.toString() ?? '',
      dishes: parsedDishes,
      isActive: map['isActive'] == true || map['isActive'] == 'true',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      ownerId: map['ownerId']?.toString(),
    );
  }

  /// Safely parses a DateTime from various formats
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return DateTime.now();
    }
  }
}
