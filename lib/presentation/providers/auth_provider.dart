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
  
  bool _isLoading = true;

  // Expose current user state
  UserModel? get user => _currentUser;
  bool get isLoggedIn => _currentUser != null; // Checks if our app model is loaded
  bool get isFirebaseLoggedIn => _auth.currentUser != null; // Checks low-level auth
  bool get isLoading => _isLoading;

  AuthProvider() {
    initAuth();
  }

  /// Initializes auth state on app start
  Future<void> initAuth() async {
    // Listen to Firebase Auth changes and store subscription for cleanup
    _authSubscription = _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
      } else {
        // Fetch full profile from RTDB
        await _loadUserProfile(firebaseUser);
        _isLoading = false;
        notifyListeners();
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
        await prefs.setString('last_active_business_name', userProfile.businessName);
        
        notifyListeners();
      } else {
        // Fallback if profile missing: create minimal model from Auth data
        _currentUser = UserModel(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'User',
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

  /// Logs in using Firebase Auth with account lockout logic
  Future<void> loginWithEmail(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Check if currently locked out
    final lockoutTimestamp = prefs.getInt('auth_lockout_until');
    if (lockoutTimestamp != null) {
      final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutTimestamp);
      if (DateTime.now().isBefore(lockoutTime)) {
        final remaining = lockoutTime.difference(DateTime.now());
        final mins = remaining.inMinutes;
        final secs = remaining.inSeconds % 60;
        throw 'Account locked. Try again in ${mins > 0 ? '$mins m ' : ''}$secs s';
      } else {
        // Lockout expired, clear it
        await prefs.remove('auth_lockout_until');
        await prefs.setInt('auth_failed_attempts', 0);
      }
    }

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // 2. Login successful, reset counters
      await prefs.remove('auth_failed_attempts');
      await prefs.remove('auth_lockout_until');
      
      // Listener in initAuth will handle setting _currentUser
    } on FirebaseAuthException catch (e) {
      // 3. Login failed, handle lockout logic
      if (e.code == 'invalid-credential' || e.code == 'user-not-found' || e.code == 'wrong-password') {
        int attempts = (prefs.getInt('auth_failed_attempts') ?? 0) + 1;
        await prefs.setInt('auth_failed_attempts', attempts);
        
        if (attempts >= 5) {
          final lockoutTime = DateTime.now().add(const Duration(minutes: 2));
          await prefs.setInt('auth_lockout_until', lockoutTime.millisecondsSinceEpoch);
          throw 'Too many failed attempts. Account locked for 2 minutes.';
        } else {
           throw 'Invalid credentials. ${5 - attempts} attempts remaining.';
        }
      }
      
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

      // 5. Update local state immediately to avoid race conditions or default display names
      _currentUser = newUser;
      notifyListeners();
      
      // Listener will also fire, but our local state is now correct proactively
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

  /// Sends password reset email to the provided email address
  /// Throws descriptive error messages for better UX
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw 'No account found with this email address.';
        case 'invalid-email':
          throw 'Invalid email address format.';
        case 'too-many-requests':
          throw 'Too many attempts. Please try again later.';
        default:
          throw e.message ?? 'Failed to send password reset email.';
      }
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
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
    
    // Sync to Firebase Auth if name/email changed
    try {
        final fUser = _auth.currentUser;
        if (fUser != null) {
            if (name != null && name != fUser.displayName) {
              await fUser.updateDisplayName(name);
            }
            if (email != null && email != fUser.email) {
              // Sends a verification email to the new address.
              // The email on the account won't update until the user clicks the link.
              await fUser.verifyBeforeUpdateEmail(email); 
            }
        }
    } catch (e) {
        print('Warning: Failed to update Firebase Auth profile: $e');
        // We don't throw here to avoid blocking the DB update success, 
        // but we might want to inform the UI if it's critical. 
        // For now, let's allow the flow to continue as the DB is updated.
        if (e.toString().contains('requires-recent-login')) {
           throw 'Security Check: Please logout and login again to update your email.';
        }
    }
    
    // Update local state
    _currentUser = updatedUser;
    notifyListeners();
  }
}
