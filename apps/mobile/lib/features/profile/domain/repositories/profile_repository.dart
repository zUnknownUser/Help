import '../../../../core/result/result.dart';
import '../entities/user_profile.dart';
import '../entities/user_role.dart';
import '../entities/profile_details.dart';
import '../failures/profile_failure.dart';

typedef ProfileResult<T> = Result<T, ProfileFailure>;

abstract interface class ProfileRepository {
  Future<ProfileResult<UserProfile>> getCurrent();

  Future<ProfileResult<UserProfile>> register({
    required String displayName,
    required UserRole role,
  });

  Future<ProfileResult<UserProfile>> update(ProfileUpdate update);

  Future<ProfileResult<void>> uploadAvatar(String filePath);

  Future<ProfileResult<PortfolioItem>> uploadPortfolio(
    String filePath, {
    String caption,
  });

  Future<ProfileResult<void>> deletePortfolio(String id);

  Future<ProfileResult<UserProfile>> syncEmail();
}
