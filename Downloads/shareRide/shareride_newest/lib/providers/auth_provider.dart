import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  User? _user;
  bool _isLoading = false;
  String? _error;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String? get userId => _user?.uid;
  String? get userEmail => _user?.email;
  String? get userDisplayName => _user?.displayName;

  
  AuthProvider() {
  print('AuthProvider: Constructor called');
  
  // Listen to auth state changes
  _authService.authStateChanges.listen((User? user) {
    print('AuthProvider: Auth state changed - User: ${user?.uid ?? 'null'}');
    _user = user;
    notifyListeners();
  }, onError: (error) {
    print('AuthProvider: Auth state change error: $error');
    _setError(error.toString());
  });
  
  print('AuthProvider: Constructor completed');
}

  // Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    try {
      _setLoading(true);
      clearError();

      final userCredential = await _authService.signInWithEmailAndPassword(email, password);
      
      if (userCredential != null) {
        _user = userCredential.user;
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);

      final userCredential = await _authService.signInWithGoogle();
      
      if (userCredential != null) {
        _user = userCredential.user;
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Register with email and password
  Future<bool> register(String email, String password, String displayName) async {
    try {
      _setLoading(true);
      clearError();

      final userCredential = await _authService.registerWithEmailAndPassword(
        email,
        password,
        displayName,
      );
      
      if (userCredential != null) {
        _user = userCredential.user;
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      clearError();

      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _setLoading(true);
      clearError();

      await _authService.signOut();
      _user = null;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Update user profile
  Future<bool> updateProfile({String? displayName, String? phoneNumber}) async {
    try {
      _setLoading(true);
      clearError();

      await _authService.updateUserProfile(
        displayName: displayName,
        phoneNumber: phoneNumber,
      );

      // Refresh user data
      await _user?.reload();
      _user = _authService.currentUser;
      
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Check authentication status
  Future<void> checkAuthStatus() async {
    _user = _authService.currentUser;
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Get user display name with fallback
  String getUserDisplayName() {
    if (_user?.displayName != null && _user!.displayName!.isNotEmpty) {
      return _user!.displayName!;
    }
    if (_user?.email != null) {
      return _user!.email!.split('@')[0];
    }
    return 'User';
  }

  // Get user initials for avatar
  String getUserInitials() {
    final displayName = getUserDisplayName();
    final parts = displayName.split(' ');
    
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    
    return 'U';
  }

  // Check if email is verified
  bool get isEmailVerified => _user?.emailVerified ?? false;

  // Send email verification
  Future<bool> sendEmailVerification() async {
    try {
      if (_user != null && !_user!.emailVerified) {
        await _user!.sendEmailVerification();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Reload user data
  Future<void> reloadUser() async {
    try {
      if (_user != null) {
        await _user!.reload();
        _user = _authService.currentUser;
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Check if user signed in with Google
  bool get isSignedInWithGoogle {
    if (_user?.providerData.isEmpty ?? true) return false;
    
    return _user!.providerData.any((info) => 
      info.providerId == 'google.com'
    );
  }

  // Get sign-in provider
  String getSignInProvider() {
    if (_user?.providerData.isEmpty ?? true) return 'Unknown';
    
    final providerId = _user!.providerData.first.providerId;
    switch (providerId) {
      case 'google.com':
        return 'Google';
      case 'password':
        return 'Email/Password';
      case 'microsoft.com':
        return 'Microsoft';
      default:
        return providerId;
    }
  }
}


  