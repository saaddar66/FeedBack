import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to manage authentication state using Firebase Auth
class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  UserModel? _currentUser;
  StreamSubscription<User?>? _authSubscription;
  
  // Expose current user state
  UserModel? get user => _currentUser;
  bool get isLoggedIn => _currentUser != null; // Checks if our app model is loaded
  bool get isFirebaseLoggedIn => _auth.currentUser != null; // Checks low-level auth

  AuthProvider() {
    initAuth();
  }

  /// Initializes auth state on app start
  Future<void> initAuth() async {
    // Listen to Firebase Auth changes and store subscription for cleanup
    _authSubscription = _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        _currentUser = null;
        notifyListeners();
      } else {
        // Fetch full profile from RTDB
        await _loadUserProfile(firebaseUser);
      }
    });
  }

  /// Loads user profile from DatabaseHelper (Realtime DB)
  Future<void> _loadUserProfile(User firebaseUser) async {
    try {
      final userProfile = await DatabaseHelper.instance.getUserProfile(firebaseUser.uid);
      if (userProfile != null) {
        _currentUser = userProfile;
        
        // Persist last active user ID for public form attribution (QR code)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_active_user_id', firebaseUser.uid);
        
        notifyListeners();
      } else {
        // Fallback if profile missing: create minimal model from Auth data
        _currentUser = UserModel(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Admin',
          email: firebaseUser.email ?? '',
          phone: '',
          businessName: '',
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  /// Logs in using Firebase Auth
  Future<void> loginWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // Listener in initAuth will handle setting _currentUser
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Login failed';
    }
  }

  /// Signs up new user with Firebase Auth and saves profile to RTDB
  Future<void> signupWithEmail({
    required String email, 
    required String password,
    required String name,
    required String phone,
    required String businessName,
  }) async {
    try {
      // 1. Create Auth User
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      final firebaseUser = credential.user;
      if (firebaseUser == null) throw 'User creation failed';

      // 2. Update Display Name
      await firebaseUser.updateDisplayName(name);

      // 3. Create User Profile Model
      final newUser = UserModel(
        id: firebaseUser.uid,
        name: name,
        email: email,
        phone: phone,
        businessName: businessName,
      );

      // 4. Save to Realtime Database
      await DatabaseHelper.instance.createUserProfile(newUser);
      
      // Listener will handle loading
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Signup failed';
    }
  }

  /// Logs out the current user
  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Cancel stream subscription to prevent memory leaks
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }

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
    await DatabaseHelper.instance.updateUserProfile(updatedUser);
    
    // Sync to Firebase Auth if name/email changed (optional, best effort)
    try {
        final fUser = _auth.currentUser;
        if (fUser != null) {
            if (name != null) await fUser.updateDisplayName(name);
            if (email != null) await fUser.verifyBeforeUpdateEmail(email); 
        }
    } catch (e) {
        print('Warning: Failed to update Firebase Auth profile: $e');
    }
    
    // Update local state
    _currentUser = updatedUser;
    notifyListeners();
  }
}
