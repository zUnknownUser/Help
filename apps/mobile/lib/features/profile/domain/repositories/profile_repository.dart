import '../../../../core/result/result.dart';
import '../entities/user_profile.dart';
import '../entities/user_role.dart';
import '../failures/profile_failure.dart';

typedef ProfileResult<T> = Result<T, ProfileFailure>;

abstract interface class ProfileRepository {
  Future<ProfileResult<UserProfile>> getCurrent();

  Future<ProfileResult<UserProfile>> register({
    required String displayName,
    required UserRole role,
  });
}
