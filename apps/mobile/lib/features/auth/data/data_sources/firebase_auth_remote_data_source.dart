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
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      await user?.updateDisplayName(displayName);
      await user?.reload();
      return _requireUser(_firebaseAuth.currentUser ?? user);
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
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _requireUser(credential.user);
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
      final credential = await _firebaseAuth.signInWithCredential(
        googleCredential,
      );
      return _requireUser(credential.user);
    } on GoogleSignInException catch (error) {
      throw _fromGoogle(error);
    } on FirebaseAuthException catch (error) {
      throw _fromFirebase(error);
    }
  }

  @override
  Future<AuthUserModel> refreshCurrentUser() async {
    try {
      await _firebaseAuth.currentUser?.reload();
      return _requireUser(_firebaseAuth.currentUser);
    } on FirebaseAuthException catch (error) {
      throw _fromFirebase(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (error) {
      throw _fromFirebase(error);
    }

    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    } on GoogleSignInException catch (error) {
      if (_fromGoogle(error).code != AuthDataErrorCode.configuration) rethrow;
    }
  }

  Future<void> _ensureGoogleInitialized() {
    return _googleInitialization ??= _googleSignIn.initialize();
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
      'invalid-email' ||
      'invalid-credential' ||
      'user-disabled' ||
      'user-not-found' ||
      'wrong-password' => AuthDataErrorCode.invalidCredentials,
      'network-request-failed' => AuthDataErrorCode.network,
      'too-many-requests' => AuthDataErrorCode.tooManyRequests,
      'email-already-in-use' => AuthDataErrorCode.emailAlreadyInUse,
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
