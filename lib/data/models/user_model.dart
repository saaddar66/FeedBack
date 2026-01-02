/// Model class representing an Admin User
/// Stored locally in SQLite database for authentication
class UserModel {
  final int? id;              // Unique ID (auto-incremented by SQLite)
  final String name;          // User's full name
  final String email;         // User's email (used for login)
  final String phone;         // Contact phone number
  final String businessName;  // Usage/Business context
  final String password;      // Hashed password string

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.businessName,
    required this.password,
  });

  /// Converts the user object to a Map
  /// Used for inserting into the SQLite 'users' table
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'business_name': businessName,
      'password': password,
    };
  }

  /// Creates a UserModel from a database Map (row)
  /// Used when reading from the SQLite 'users' table
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      phone: map['phone'],
      businessName: map['business_name'],
      password: map['password'],
    );
  }
}
