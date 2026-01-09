
import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/local/sqlite_database_helper.dart';

/// Provider to manage authentication state
class AuthProvider with ChangeNotifier {
  UserModel? _currentUser;

  UserModel? get user => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Sets the logged-in user
  void login(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Logs out the current user
  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  /// Optional: Check for existing session (if persisted anywhere besides just memory)
  /// For now, we rely on LoginScreen to set this.

  /// Updates current user profile with name, email and phone
  Future<void> updateUserProfile({String? name, String? email, String? phone}) async {
    if (_currentUser == null) return;
    
    // Create updated user model
    final updatedUser = _currentUser!.copyWith(
      name: name ?? _currentUser!.name,
      email: email ?? _currentUser!.email,
      phone: phone ?? _currentUser!.phone,
    );

    // Update in database
    await SqliteDatabaseHelper.instance.updateUser(updatedUser);
    
    // Update local state
    _currentUser = updatedUser;
    notifyListeners();
  }
}
