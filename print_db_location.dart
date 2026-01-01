import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'feedy_users.db');
  print('Database is located at: $path');
}
