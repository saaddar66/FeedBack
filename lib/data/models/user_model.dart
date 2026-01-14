/// Model class representing an Admin User
/// Stored locally in SQLite database for authentication
class UserModel {
  final String? id;           // Unique ID (Firebase UID)
  final String name;          // User's full name
  final String email;         // User's email (used for login)
  final String phone;         // Contact phone number
  final String businessName;  // Usage/Business context
  final String? password;     // Optional: not strictly needed to store locally with Firebase Auth

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.businessName,
    this.password,
  });

  /// Converts the user object to a Map
  /// Used for inserting into the Database (or RTDB)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'business_name': businessName,
      // We generally don't sync password to RTDB for security, Auth handles it
    };
  }

  /// Creates a UserModel from a database Map (row)
  /// Used when reading from the Database
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toString(), // Ensure string
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      businessName: map['business_name'] ?? '',
      password: null, // Password not retrieved from profile
    );
  }

  /// Creates a copy of this user with the given fields replaced with new values
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? businessName,
    String? password,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      businessName: businessName ?? this.businessName,
      password: password ?? this.password,
    );
  }
}
