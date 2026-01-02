import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';

/// Helper class for managing the local SQLite database
/// Handles Admin User authentication, creation, and retrieval
/// Stores data securely on the device
class SqliteDatabaseHelper {
  // Singleton instance
  static final SqliteDatabaseHelper instance = SqliteDatabaseHelper._init();
  static Database? _database;

  SqliteDatabaseHelper._init();

  /// Returns the active database connection
  /// Initializes it if not already open
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('feedy_users.db');
    return _database!;
  }

  /// Initializes the SQLite database at the default location
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  /// Creates the database schema (Users table)
  Future<void> _createDB(Database db, int version) async {
    const userTable = '''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        business_name TEXT NOT NULL,
        password TEXT NOT NULL
      )
    ''';
    await db.execute(userTable);
  }

  /// Hashes a password using SHA-256 for secure storage
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Inserts a new user into the database
  /// Automatically hashes the password before storage
  Future<int> insertUser(UserModel user) async {
    final db = await instance.database;
    // Create a new map from user but with hashed password
    final userMap = user.toMap();
    userMap['password'] = _hashPassword(user.password);
    
    return await db.insert('users', userMap);
  }

  /// Authenticates a user by email and password
  /// Returns the UserModel if credentials match, otherwise null
  Future<UserModel?> getUser(String email, String password) async {
    final db = await instance.database;
    final hashedPassword = _hashPassword(password);
    
    final maps = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, hashedPassword],
    );

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }
  
  /// Checks if an email is already registered
  /// Used during signup to prevent duplicates
  Future<bool> checkEmailExists(String email) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    return maps.isNotEmpty;
  }

  /// Closes the database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
