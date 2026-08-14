import '../../../../core/result/result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/failures/profile_failure.dart';
import '../../domain/repositories/profile_repository.dart';
import '../data_sources/profile_remote_data_source.dart';
import '../errors/profile_data_exception.dart';
import '../models/user_profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  Future<ProfileResult<UserProfile>> getCurrent() => _guard(_remote.getCurrent);

  @override
  Future<ProfileResult<UserProfile>> register({
    required String displayName,
    required UserRole role,
  }) => _guard(() => _remote.register(displayName: displayName, role: role));

  Future<ProfileResult<UserProfile>> _guard(
    Future<UserProfileModel> Function() operation,
  ) async {
    try {
      final model = await operation();
      return Success(model.toEntity());
    } on ProfileDataException catch (error) {
      return FailureResult(
        ProfileFailure(
          _failureType(error.code),
          debugMessage: error.debugMessage,
        ),
      );
    } catch (error) {
      return FailureResult(
        ProfileFailure(ProfileFailureType.unknown, debugMessage: '$error'),
      );
    }
  }
}

ProfileFailureType _failureType(ProfileDataErrorCode code) => switch (code) {
  ProfileDataErrorCode.notFound => ProfileFailureType.notFound,
  ProfileDataErrorCode.unauthorized => ProfileFailureType.unauthorized,
  ProfileDataErrorCode.invalidData => ProfileFailureType.invalidData,
  ProfileDataErrorCode.network => ProfileFailureType.network,
  ProfileDataErrorCode.unavailable => ProfileFailureType.unavailable,
  ProfileDataErrorCode.unknown => ProfileFailureType.unknown,
};
