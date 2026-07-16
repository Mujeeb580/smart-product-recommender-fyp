import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'api_service.dart';
import '../core/api_config.dart';

/// Firebase Authentication Service with Backend Integration
class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // GoogleSignIn with web support - lazily initialized for non-web platforms
  // Avoid instantiating on web to prevent duplicate GSI initialization
  GoogleSignIn? _googleSignIn;

  GoogleSignIn _getGoogleSignIn() {
    _googleSignIn ??= GoogleSignIn(
      // serverClientId is optional - used for backend authentication
      // For web, the clientId is automatically read from the meta tag
      scopes: ['email', 'profile'],
    );
    return _googleSignIn!;
  }

  final ApiService _apiService = ApiService();

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  /// Sign up with email and password
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      // Create user in Firebase
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Register user in backend (optional - for additional data storage)
      try {
        await _apiService.post(
          ApiConfig.authRegister,
          body: {
            'email': email,
            'password': password,
          },
        );
      } catch (e) {
        // Log backend registration error but don't fail
        debugPrint('Backend registration error: $e');
      }

      // Save token
      final token = await userCredential.user?.getIdToken();
      if (token != null) {
        await _saveToken(token);
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }

  /// Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user token for API calls
      final token = await userCredential.user?.getIdToken();
      if (token != null) {
        await _saveToken(token);
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  /// Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final UserCredential userCredential;

      if (kIsWeb) {
        final GoogleAuthProvider provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');

        // Use Firebase's web popup flow to avoid Google Sign-In web token-client timeouts.
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        // Trigger Google Sign-In flow (mobile/native)
        final GoogleSignInAccount? googleUser =
            await _getGoogleSignIn().signIn();

        if (googleUser == null) {
          // User cancelled the sign-in
          return null;
        }

        // Obtain auth details from request
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Create a new credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase with the Google credential
        userCredential = await _auth.signInWithCredential(credential);
      }

      // Save user token for API calls
      final token = await userCredential.user?.getIdToken();
      if (token != null) {
        await _saveToken(token);
      }

      // Optionally register user in backend
      try {
        if (userCredential.additionalUserInfo?.isNewUser ?? false) {
          await _apiService.post(
            ApiConfig.authRegister,
            body: {
              'email': userCredential.user?.email ?? '',
              'displayName': userCredential.user?.displayName ?? '',
              'photoURL': userCredential.user?.photoURL ?? '',
            },
          );
        }
      } catch (e) {
        debugPrint('Backend registration error: $e');
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Firebase and (if used) GoogleSignIn on non-web
      final futures = <Future>[_auth.signOut()];
      if (!kIsWeb) {
        futures.add(_getGoogleSignIn().signOut());
      }
      await Future.wait(futures);
      await _clearToken();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  /// Get ID token for API requests
  Future<String?> getIdToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting ID token: $e');
      return null;
    }
  }

  /// Verify token with backend
  Future<bool> verifyToken(String token) async {
    try {
      await _apiService.get(
        ApiConfig.authVerifyToken,
        headers: ApiConfig.authHeaders(token),
      );
      return true;
    } catch (e) {
      debugPrint('Token verification failed: $e');
      return false;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }

  /// Reauthenticate an email/password user and update their password.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      final email = user?.email;
      if (user == null || email == null || email.isEmpty) {
        throw Exception('No signed-in email account was found.');
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Password update failed: ${e.toString()}');
    }
  }

  /// Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateProfile(
          displayName: displayName,
          photoURL: photoURL,
        );
        await user.reload();
      }
    } catch (e) {
      throw Exception('Profile update failed: ${e.toString()}');
    }
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
        await _clearToken();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Account deletion failed: ${e.toString()}');
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) return true;

    // On a cold mobile start, allow Firebase time to restore the user from its
    // native persisted session before deciding that the user is signed out.
    final restoredUser = await _auth.authStateChanges().first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => _auth.currentUser,
        );
    return restoredUser != null;
  }

  /// Save token to local storage
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  /// Get saved token
  Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Clear token from local storage
  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password is too weak. Please use a stronger password.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'requires-recent-login':
        return 'Please sign in again to complete this action.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      default:
        return e.message ?? 'Authentication error occurred.';
    }
  }
}
