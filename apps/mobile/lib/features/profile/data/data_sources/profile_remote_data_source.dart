import '../../domain/entities/user_role.dart';
import '../models/user_profile_model.dart';

abstract interface class ProfileRemoteDataSource {
  Future<UserProfileModel> getCurrent();

  Future<UserProfileModel> register({
    required String displayName,
    required UserRole role,
  });
}
