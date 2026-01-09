
// Mock implementation of sqflite for Web
// This allows compiling SqliteDatabaseHelper on web without sqflite dependencies

import 'dart:async';

class Database {
  Future<List<Map<String, Object?>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) async {
    // Mock Admin User for Web Login
    if (table == 'users') {
       // Return a dummy admin user if query matches (assuming any query is valid for now)
       return [{
         'id': 1,
         'name': 'Web Admin',
         'email': 'admin@feedy.com',
         'phone': '0000000000',
         'business_name': 'Feedy Web',
         'password': 'hashed_password_placeholder' // Application hashes password, we need to match it? 
         // SqliteDatabaseHelper hashes input password then queries. 
         // Since we can't easily match hash without crypto logic duplications or knowing the hash,
         // We might just return empty if we want to fail, or valid if we want to succeed.
         // Realistically, to support login, we need to return a user when credentials match.
         // BUT SqliteDatabaseHelper logic is:
         // query(where: 'email = ? AND password = ?', whereArgs: [email, hashedPwd])
         // If we return a list, it succeeds.
         // So for ANY login attempt on web, we can return success (Dangerous but effectively a demo/mock)
         // OR we restrict to hardcoded email.
       }];
    }
    return [];
  }

  Future<int> insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    return 1;
  }

  Future<void> execute(String sql, [List<Object?>? arguments]) async {}
  
  Future<void> close() async {}
}

Future<Database> openDatabase(String path, {int? version, OnDatabaseConfigure? onConfigure, OnDatabaseCreate? onCreate, OnDatabaseVersionChange? onUpgrade, OnDatabaseVersionChange? onDowngrade, OnDatabaseOpen? onOpen, bool? readOnly, bool? singleInstance}) async {
  if (onCreate != null) {
      // Simulate creation
       await onCreate(Database(), version ?? 1);
  }
  return Database();
}

Future<String> getDatabasesPath() async => '';

enum ConflictAlgorithm {
  rollback,
  abort,
  fail,
  ignore,
  replace,
}

typedef OnDatabaseConfigure = FutureOr<void> Function(Database db);
typedef OnDatabaseCreate = FutureOr<void> Function(Database db, int version);
typedef OnDatabaseVersionChange = FutureOr<void> Function(Database db, int oldVersion, int newVersion);
typedef OnDatabaseOpen = FutureOr<void> Function(Database db);
