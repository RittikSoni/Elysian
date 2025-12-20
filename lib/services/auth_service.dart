import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:elysian/services/storage_service.dart';

/// Service for handling Google Sign-In authentication with Firebase
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() {
    initialize();
    return _instance;
  }
  AuthService._internal();

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  /// initialize google sign in
  static void initialize() async {
    await _googleSignIn.initialize(
      serverClientId:
          '869780405180-h6piqg3tq98n3cu7d3i5b9kdtk524anv.apps.googleusercontent.com',
    );
  }

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  GoogleSignInAccount? _currentUser;
  User? _firebaseUser;

  /// Get current signed-in user (Google)
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Get current Firebase user
  User? get firebaseUser => _firebaseUser;

  /// Check if user is signed in
  bool get isSignedIn => _firebaseUser != null;

  /// Get user email
  String? get userEmail => _firebaseUser?.email ?? _currentUser?.email;

  /// Get user display name
  String? get userDisplayName =>
      _firebaseUser?.displayName ?? _currentUser?.displayName;

  /// Get user photo URL
  String? get userPhotoUrl => _firebaseUser?.photoURL ?? _currentUser?.photoUrl;

  /// Sign in with Google and Firebase Authentication
  Future<GoogleSignInAccount?> signIn() async {
    try {
      // Step 1: Sign in with Google
      final account = await _googleSignIn.authenticate();

      _currentUser = account;

      // Step 2: Get authentication credentials from Google
      final googleAuth = account.authentication;

      // Step 3: Create Firebase credential
      // In Google Sign In v7+, accessToken is handled separately for authorization.
      // Firebase Auth primarily uses idToken for authentication.
      final credential = GoogleAuthProvider.credential(
        accessToken:
            null, // accessToken is no longer in authentication object in v7
        idToken: googleAuth.idToken,
      );

      // Step 4: Sign in to Firebase with Google credential
      // Handle keychain errors gracefully on iOS
      try {
        final userCredential = await _firebaseAuth.signInWithCredential(
          credential,
        );
        _firebaseUser = userCredential.user;

        // Clear any sign-out flag since user is signing in
        await StorageService.setUserSignedOut(false);

        debugPrint('Google Sign-In successful: ${account.email}');
        debugPrint('Firebase Auth successful: ${_firebaseUser?.email}');
      } catch (firebaseError) {
        // Handle keychain errors specifically
        if (firebaseError.toString().contains('keychain') ||
            firebaseError.toString().contains('keychain-error')) {
          debugPrint('Keychain error detected, attempting workaround...');
          // Try to sign out from Firebase first, then retry
          try {
            await _firebaseAuth.signOut();
            // Retry once
            final userCredential = await _firebaseAuth.signInWithCredential(
              credential,
            );
            _firebaseUser = userCredential.user;
            await StorageService.setUserSignedOut(false);
            debugPrint('Firebase Auth successful after keychain retry');
          } catch (retryError) {
            debugPrint('Firebase Auth retry failed: $retryError');
            // Clear Google sign-in if Firebase fails
            await _googleSignIn.signOut();
            _currentUser = null;
            rethrow;
          }
        } else {
          // Other Firebase errors
          await _googleSignIn.signOut();
          _currentUser = null;
          rethrow;
        }
      }

      return account;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      // If Firebase auth fails, still clear Google sign-in
      if (_currentUser != null) {
        await _googleSignIn.signOut();
        _currentUser = null;
      }
      rethrow;
    }
  }

  /// Sign out from both Google and Firebase
  Future<void> signOut() async {
    try {
      // Set flag that user explicitly signed out
      await StorageService.setUserSignedOut(true);

      // Sign out from Firebase first
      try {
        await _firebaseAuth.signOut();
      } catch (e) {
        debugPrint('Firebase sign-out error (non-critical): $e');
        // Continue even if Firebase sign-out fails
      }
      _firebaseUser = null;

      // Then sign out from Google
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Google sign-out error (non-critical): $e');
        // Continue even if Google sign-out fails
      }
      _currentUser = null;

      debugPrint('Sign-Out successful');
    } catch (e) {
      debugPrint('Sign-Out error: $e');
      // Don't rethrow - ensure state is cleared even if there's an error
      _firebaseUser = null;
      _currentUser = null;
    }
  }

  /// Get the last signed-in account (if any) and authenticate with Firebase
  Future<GoogleSignInAccount?> getLastSignedInAccount() async {
    try {
      // Check if user explicitly signed out
      final userSignedOut = await StorageService.getUserSignedOut();
      if (userSignedOut == true) {
        debugPrint('User previously signed out, not restoring session');
        // Clear any lingering Firebase Auth state
        try {
          await _firebaseAuth.signOut();
        } catch (e) {
          debugPrint('Error clearing Firebase Auth state: $e');
        }
        _firebaseUser = null;
        _currentUser = null;
        return null;
      }

      // Check Firebase Auth first
      try {
        _firebaseUser = _firebaseAuth.currentUser;
      } catch (e) {
        // Handle keychain errors gracefully
        if (e.toString().contains('keychain') ||
            e.toString().contains('keychain-error')) {
          debugPrint(
            'Keychain error when checking Firebase Auth, treating as signed out',
          );
          _firebaseUser = null;
        } else {
          rethrow;
        }
      }

      if (_firebaseUser != null) {
        // User is already authenticated with Firebase
        // Try to get Google account for display purposes
        try {
          final account = await _googleSignIn
              .attemptLightweightAuthentication();
          _currentUser = account;
        } catch (e) {
          // Google sign-in might have expired, but Firebase auth is still valid
          debugPrint(
            'Silent Google sign-in failed, but Firebase auth is valid: $e',
          );
        }

        debugPrint('Firebase Auth user found: ${_firebaseUser?.email}');
        return _currentUser;
      }

      // Try silent Google sign-in
      final account = await _googleSignIn.attemptLightweightAuthentication();
      if (account != null) {
        _currentUser = account;

        // Authenticate with Firebase using Google credentials
        try {
          final googleAuth = account.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: null,
            idToken: googleAuth.idToken,
          );

          // Handle keychain errors
          try {
            final userCredential = await _firebaseAuth.signInWithCredential(
              credential,
            );
            _firebaseUser = userCredential.user;
            await StorageService.setUserSignedOut(false);
            debugPrint('Silent sign-in successful: ${account.email}');
          } catch (firebaseError) {
            if (firebaseError.toString().contains('keychain') ||
                firebaseError.toString().contains('keychain-error')) {
              debugPrint('Keychain error during silent auth, clearing state');
              await _googleSignIn.signOut();
              _currentUser = null;
              return null;
            }
            rethrow;
          }
        } catch (e) {
          debugPrint('Firebase silent auth error: $e');
          // Clear Google sign-in if Firebase auth fails
          await _googleSignIn.signOut();
          _currentUser = null;
          return null;
        }

        return account;
      }
      return null;
    } catch (e) {
      debugPrint('Silent sign-in error: $e');
      return null;
    }
  }

  /// Check if user is currently signed in
  Future<bool> checkSignInStatus() async {
    try {
      // Check if user explicitly signed out
      final userSignedOut = await StorageService.getUserSignedOut();
      if (userSignedOut == true) {
        return false;
      }

      // Check Firebase Auth first
      try {
        _firebaseUser = _firebaseAuth.currentUser;
      } catch (e) {
        if (e.toString().contains('keychain') ||
            e.toString().contains('keychain-error')) {
          debugPrint('Keychain error when checking Firebase Auth');
          _firebaseUser = null;
        } else {
          rethrow;
        }
      }

      if (_firebaseUser != null) {
        return true;
      }

      // Fallback to Google sign-in check
      final account = await _googleSignIn.attemptLightweightAuthentication();
      if (account != null) {
        _currentUser = account;
        // Try to authenticate with Firebase
        try {
          final googleAuth = account.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: null,
            idToken: googleAuth.idToken,
          );

          try {
            final userCredential = await _firebaseAuth.signInWithCredential(
              credential,
            );
            _firebaseUser = userCredential.user;
            await StorageService.setUserSignedOut(false);
            return true;
          } catch (firebaseError) {
            if (firebaseError.toString().contains('keychain') ||
                firebaseError.toString().contains('keychain-error')) {
              debugPrint('Keychain error during auth check');
              return false;
            }
            rethrow;
          }
        } catch (e) {
          debugPrint('Firebase auth check error: $e');
          return false;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Check sign-in status error: $e');
      return false;
    }
  }
}
