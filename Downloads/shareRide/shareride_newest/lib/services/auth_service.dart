import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  // Expose auth instance for advanced operations
  FirebaseAuth get auth => _auth;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // User changes stream (includes profile updates)
  Stream<User?> get userChanges => _auth.userChanges();

  // Check if user email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      // Validate inputs
      _validateEmail(email);
      _validatePassword(password);

      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      // Validate inputs
      _validateEmail(email);
      _validatePassword(password);
      _validateDisplayName(displayName);

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update user profile
      await result.user?.updateDisplayName(displayName.trim());
      await result.user?.reload();

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Create a GoogleAuthProvider for web
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        // Sign in with popup for web
        UserCredential result = await _auth.signInWithPopup(googleProvider);
        return result;
      } else {
        // Mobile implementation
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          throw 'Google sign-in was cancelled by user';
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        UserCredential result = await _auth.signInWithCredential(credential);
        return result;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Google sign-in failed: ${e.toString()}';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      _validateEmail(email);
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      if (user.emailVerified) {
        throw 'Email is already verified';
      }

      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Check if email is already registered
  Future<bool> isEmailRegistered(String email) async {
    try {
      _validateEmail(email);
      List<String> signInMethods = await _auth.fetchSignInMethodsForEmail(email.trim());
      return signInMethods.isNotEmpty;
    } on FirebaseAuthException catch (e) {
      // If email is not found, it's not registered
      if (e.code == 'user-not-found') {
        return false;
      }
      throw _handleAuthException(e);
    }
  }

  // Get sign-in methods for email
  Future<List<String>> getSignInMethods(String email) async {
    try {
      _validateEmail(email);
      return await _auth.fetchSignInMethodsForEmail(email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Update user profile - FIXED: removed duplicate phoneNumber parameters
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
    String? phoneNumber, // Only one phoneNumber parameter
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      if (displayName != null) {
        _validateDisplayName(displayName);
        await user.updateDisplayName(displayName.trim());
      }

      if (photoURL != null) {
        await user.updatePhotoURL(photoURL.trim());
      }

      // Note: Firebase Auth doesn't directly support updating phone number
      // in updateProfile. For phone number updates, you'd typically use 
      // updatePhoneNumber() with phone authentication or store it in Firestore
      if (phoneNumber != null) {
        // This would require phone number verification
        // For now, we'll skip this as it requires additional verification steps
        debugPrint('Phone number update requires verification and is not implemented in this method');
      }

      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Update password (requires recent authentication)
  Future<void> updatePassword(String newPassword) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      _validatePassword(newPassword);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'Please sign in again before updating your password';
      }
      throw _handleAuthException(e);
    }
  }

  // Update email (requires recent authentication and verification)
  Future<void> updateEmail(String newEmail) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      _validateEmail(newEmail);
      await user.verifyBeforeUpdateEmail(newEmail.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'Please sign in again before updating your email';
      }
      throw _handleAuthException(e);
    }
  }

  // Re-authenticate user with password
  Future<void> reauthenticateWithPassword(String password) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      if (user.email == null) {
        throw 'User email not available';
      }

      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Re-authenticate with Google
  Future<void> reauthenticateWithGoogle() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      // Get fresh Google credentials
      UserCredential result = await signInWithGoogle();
      
      if (result.credential != null) {
        await user.reauthenticateWithCredential(result.credential!);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Delete user account
  Future<void> deleteAccount() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'Please sign in again before deleting your account';
      }
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google if user signed in with Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Input validation methods
  void _validateEmail(String email) {
    if (email.trim().isEmpty) {
      throw 'Email cannot be empty';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim())) {
      throw 'Please enter a valid email address';
    }
  }

  void _validatePassword(String password) {
    if (password.isEmpty) {
      throw 'Password cannot be empty';
    }
    if (password.length < 6) {
      throw 'Password must be at least 6 characters long';
    }
  }

  void _validateDisplayName(String displayName) {
    if (displayName.trim().isEmpty) {
      throw 'Display name cannot be empty';
    }
    if (displayName.trim().length < 2) {
      throw 'Display name must be at least 2 characters long';
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
    
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in credentials.';
      case 'invalid-credential':
        return 'The credential received is malformed or has expired.';
      case 'credential-already-in-use':
        return 'This credential is already associated with a different user account.';
      case 'requires-recent-login':
        return 'Please sign in again to complete this action.';
      case 'email-change-needs-verification':
        return 'Email change requires verification. Check your new email for verification link.';
      case 'invalid-action-code':
        return 'The action code is invalid or has expired.';
      case 'expired-action-code':
        return 'The action code has expired. Please request a new one.';
      case 'invalid-continue-uri':
        return 'The continue URL provided in the request is invalid.';
      case 'missing-continue-uri':
        return 'A continue URL must be provided in the request.';
      case 'unauthorized-continue-uri':
        return 'The continue URL provided in the request is not authorized.';
      default:
        return e.message ?? 'An unknown authentication error occurred.';
    }
  }
}