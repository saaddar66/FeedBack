import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void configureDatabase() {
  // Initialize sqflite FFI for Desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    print('Initialized sqflite FFI for desktop.');
  }
}
