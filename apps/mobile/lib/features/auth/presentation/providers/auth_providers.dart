import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_data_providers.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/use_cases/sign_in_with_email.dart';
import '../../domain/use_cases/sign_in_with_google.dart';
import '../../domain/use_cases/sign_out.dart';
import '../../domain/use_cases/register_with_email.dart';
import '../../domain/use_cases/refresh_current_user.dart';
import '../../domain/use_cases/request_email_verification.dart';
import '../controllers/auth_controller.dart';
import '../../domain/use_cases/request_password_reset.dart';
import '../controllers/password_reset_controller.dart';
import '../controllers/password_reset_state.dart';
import '../controllers/registration_controller.dart';
import '../controllers/registration_state.dart';
import '../controllers/email_verification_controller.dart';
import '../controllers/email_verification_state.dart';
import '../../../chat/data/providers/chat_data_providers.dart';
import '../../../notifications/data/push_providers.dart';
import '../../../../core/notifications/app_badge_service.dart';

final signInWithEmailProvider = Provider<SignInWithEmail>(
  (ref) => SignInWithEmail(ref.watch(authRepositoryProvider)),
);

final signInWithGoogleProvider = Provider<SignInWithGoogle>(
  (ref) => SignInWithGoogle(ref.watch(authRepositoryProvider)),
);

final signOutProvider = Provider<Future<void> Function()>((ref) {
  final signOut = SignOut(ref.watch(authRepositoryProvider));
  return () async {
    await ref.read(pushRegistrationServiceProvider).unregister();
    ref.read(chatRealtimeCoordinatorProvider).stop();
    await signOut();
    await const PlatformAppBadgeService().update(0);
  };
});

final registerWithEmailProvider = Provider<RegisterWithEmail>(
  (ref) => RegisterWithEmail(ref.watch(authRepositoryProvider)),
);

final refreshCurrentUserProvider = Provider<RefreshCurrentUser>(
  (ref) => RefreshCurrentUser(ref.watch(authRepositoryProvider)),
);

final requestEmailVerificationProvider = Provider<RequestEmailVerification>(
  (ref) =>
      RequestEmailVerification(ref.watch(emailVerificationRepositoryProvider)),
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

final registrationControllerProvider =
    NotifierProvider.autoDispose<RegistrationController, RegistrationState>(
      RegistrationController.new,
    );

final emailVerificationControllerProvider =
    NotifierProvider.autoDispose<
      EmailVerificationController,
      EmailVerificationState
    >(EmailVerificationController.new);
