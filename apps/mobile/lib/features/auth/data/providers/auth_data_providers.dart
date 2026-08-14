import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/http_client_provider.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/password_reset_repository.dart';
import '../data_sources/auth_remote_data_source.dart';
import '../data_sources/firebase_auth_remote_data_source.dart';
import '../data_sources/http_password_reset_remote_data_source.dart';
import '../data_sources/password_reset_remote_data_source.dart';
import '../repositories/auth_repository_impl.dart';
import '../repositories/password_reset_repository_impl.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final googleSignInProvider = Provider<GoogleSignIn>(
  (ref) => GoogleSignIn.instance,
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => FirebaseAuthRemoteDataSource(
    ref.watch(firebaseAuthProvider),
    ref.watch(googleSignInProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider)),
);

final passwordResetRemoteDataSourceProvider =
    Provider<PasswordResetRemoteDataSource>(
      (ref) => HttpPasswordResetRemoteDataSource(
        client: ref.watch(httpClientProvider),
        baseUrl: AppConfig.apiBaseUrl,
      ),
    );

final passwordResetRepositoryProvider = Provider<PasswordResetRepository>(
  (ref) => PasswordResetRepositoryImpl(
    ref.watch(passwordResetRemoteDataSourceProvider),
  ),
);
