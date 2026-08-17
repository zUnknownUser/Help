import '../../domain/entities/user_role.dart';
import '../../domain/entities/profile_details.dart';
import '../models/user_profile_model.dart';

abstract interface class ProfileRemoteDataSource {
  Future<UserProfileModel> getCurrent();

  Future<UserProfileModel> register({
    required String displayName,
    required UserRole role,
  });

  Future<UserProfileModel> update(ProfileUpdate update);

  Future<void> uploadAvatar(String filePath);

  Future<PortfolioItem> uploadPortfolio(String filePath, {String caption});

  Future<void> deletePortfolio(String id);

  Future<UserProfileModel> syncEmail();
}
