import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../errors/auth_data_exception.dart';
import '../models/auth_user_model.dart';
import 'auth_remote_data_source.dart';

class FirebaseAuthRemoteDataSource implements AuthRemoteDataSource {
  FirebaseAuthRemoteDataSource(this._firebaseAuth, this._googleSignIn);

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;

  @override
  Stream<AuthUserModel?> watchAuthState() {
    return _firebaseAuth.userChanges().map(_toModel);
  }

  @override
  Future<AuthUserModel> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 20));
      final user = credential.user;
      try {
        await user
            ?.updateDisplayName(displayName)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Display name is also persisted in our profile API and must not block
        // account creation when Firebase profile propagation is slow.
      }
      final created = _requireUser(_firebaseAuth.currentUser ?? user);
      return AuthUserModel(
        id: created.id,
        email: created.email,
        displayName: displayName.trim(),
        photoUrl: created.photoUrl,
        emailVerified: created.emailVerified,
      );
    } on TimeoutException catch (error) {
      final current = _firebaseAuth.currentUser;
      if (current?.email?.trim().toLowerCase() == email.trim().toLowerCase()) {
        return _toModel(current)!;
      }
      throw AuthDataException(
        AuthDataErrorCode.network,
        debugMessage: '$error',
      );
    } on FirebaseAuthException catch (error) {
      throw _fromFirebase(error);
    }
  }

  @override
  Future<AuthUserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 20));
      return _requireUser(credential.user);
    } on TimeoutException catch (error) {
      throw AuthDataException(
        AuthDataErrorCode.network,
        debugMessage: '$error',
      );
    } on FirebaseAuthException catch (error) {
      throw _fromFirebase(error);
    }
  }

  @override
  Future<AuthUserModel> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthDataException(
          AuthDataErrorCode.configuration,
          debugMessage: 'Google Sign-In não retornou um ID token.',
        );
      }

      final googleCredential = GoogleAuthProvider.credential(idToken: idToken);
      final credential = await _firebaseAuth
          .signInWithCredential(googleCredential)
          .timeout(const Duration(seconds: 20));
      return _requireUser(credential.user);
    } on TimeoutException catch (error) {
      throw AuthDataException(
        AuthDataErrorCode.network,
        debugMessage: '$error',
      );
    } on GoogleSignInException catch (error) {
      throw _fromGoogle(error);
    } on FirebaseAuthException catch (error) {
      throw _fromFirebase(error);
    }
  }

  @override
  Future<AuthUserModel> refreshCurrentUser() async {
    try {
      await _firebaseAuth.currentUser?.reload().timeout(
        const Duration(seconds: 10),
      );
      return _requireUser(_firebaseAuth.currentUser);
    } on TimeoutException catch (error) {
      throw AuthDataException(
        AuthDataErrorCode.network,
        debugMessage: '$error',
      );
    } on FirebaseAuthException catch (error) {
      throw _fromFirebase(error);
    }
  }

  @override
  Future<void> requestEmailChange({
    required String newEmail,
    String? currentPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthDataException(AuthDataErrorCode.invalidCredentials);
    }
    try {
      await _reauthenticate(user, currentPassword);
      await user
          .verifyBeforeUpdateEmail(newEmail.trim().toLowerCase())
          .timeout(const Duration(seconds: 20));
    } on TimeoutException catch (error) {
      throw AuthDataException(
        AuthDataErrorCode.network,
        debugMessage: '$error',
      );
    } on GoogleSignInException catch (error) {
      throw _fromGoogle(error);
    } on FirebaseAuthException catch (error) {
      throw _fromFirebase(error);
    }
  }

  Future<void> _reauthenticate(User user, String? currentPassword) async {
    final providers = user.providerData.map((item) => item.providerId).toSet();
    if (providers.contains(EmailAuthProvider.PROVIDER_ID)) {
      final email = user.email;
      if (email == null || (currentPassword ?? '').isEmpty) {
        throw const AuthDataException(AuthDataErrorCode.recentLoginRequired);
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword!),
      );
      return;
    }
    if (providers.contains(GoogleAuthProvider.PROVIDER_ID)) {
      await _ensureGoogleInitialized();
      final account = await _googleSignIn.authenticate();
      final token = account.authentication.idToken;
      if (token == null) {
        throw const AuthDataException(AuthDataErrorCode.configuration);
      }
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: token),
      );
      return;
    }
    throw const AuthDataException(AuthDataErrorCode.recentLoginRequired);
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut().timeout(const Duration(seconds: 10));
    } on TimeoutException catch (error) {
      throw AuthDataException(
        AuthDataErrorCode.network,
        debugMessage: '$error',
      );
    } on FirebaseAuthException catch (error) {
      throw _fromFirebase(error);
    }

    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut().timeout(const Duration(seconds: 10));
    } on GoogleSignInException catch (error) {
      if (_fromGoogle(error).code != AuthDataErrorCode.configuration) rethrow;
    }
  }

  Future<void> _ensureGoogleInitialized() {
    return _googleInitialization ??= _googleSignIn.initialize().timeout(
      const Duration(seconds: 20),
    );
  }

  AuthUserModel _requireUser(User? user) {
    final model = _toModel(user);
    if (model == null) {
      throw const AuthDataException(
        AuthDataErrorCode.unknown,
        debugMessage: 'Firebase retornou uma credencial sem usuário.',
      );
    }
    return model;
  }

  AuthUserModel? _toModel(User? user) {
    if (user == null) return null;
    return AuthUserModel(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
    );
  }

  AuthDataException _fromFirebase(FirebaseAuthException error) {
    final code = switch (error.code) {
      'invalid-credential' ||
      'user-disabled' ||
      'user-not-found' ||
      'wrong-password' => AuthDataErrorCode.invalidCredentials,
      'network-request-failed' => AuthDataErrorCode.network,
      'too-many-requests' => AuthDataErrorCode.tooManyRequests,
      'email-already-in-use' => AuthDataErrorCode.emailAlreadyInUse,
      'invalid-email' => AuthDataErrorCode.invalidEmail,
      'requires-recent-login' => AuthDataErrorCode.recentLoginRequired,
      'weak-password' => AuthDataErrorCode.weakPassword,
      'operation-not-allowed' => AuthDataErrorCode.configuration,
      _ => AuthDataErrorCode.unknown,
    };
    return AuthDataException(code, debugMessage: error.message);
  }

  AuthDataException _fromGoogle(GoogleSignInException error) {
    final code = switch (error.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted => AuthDataErrorCode.cancelled,
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        AuthDataErrorCode.configuration,
      _ => AuthDataErrorCode.unknown,
    };
    return AuthDataException(code, debugMessage: error.description);
  }
}
