import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_data_providers.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/use_cases/sign_in_with_email.dart';
import '../../domain/use_cases/sign_in_with_google.dart';
import '../../domain/use_cases/sign_out.dart';
import '../controllers/auth_controller.dart';
import '../../domain/use_cases/request_password_reset.dart';
import '../controllers/password_reset_controller.dart';
import '../controllers/password_reset_state.dart';

final signInWithEmailProvider = Provider<SignInWithEmail>(
  (ref) => SignInWithEmail(ref.watch(authRepositoryProvider)),
);

final signInWithGoogleProvider = Provider<SignInWithGoogle>(
  (ref) => SignInWithGoogle(ref.watch(authRepositoryProvider)),
);

final signOutProvider = Provider<SignOut>(
  (ref) => SignOut(ref.watch(authRepositoryProvider)),
);

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchAuthState(),
  retry: (_, _) => null,
);

final authControllerProvider =
    NotifierProvider.autoDispose<AuthController, AuthFormState>(
      AuthController.new,
    );

final requestPasswordResetProvider = Provider<RequestPasswordReset>(
  (ref) => RequestPasswordReset(ref.watch(passwordResetRepositoryProvider)),
);

final passwordResetControllerProvider =
    NotifierProvider.autoDispose<PasswordResetController, PasswordResetState>(
      PasswordResetController.new,
    );
