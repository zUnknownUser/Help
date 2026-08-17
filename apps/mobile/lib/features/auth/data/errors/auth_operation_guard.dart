import '../../../../core/result/result.dart';
import '../../domain/failures/auth_failure.dart';
import 'auth_data_exception.dart';

Future<Result<T, AuthFailure>> guardAuthDataOperation<T>(
  Future<T> Function() operation,
) async {
  try {
    return Success<T, AuthFailure>(await operation());
  } on AuthDataException catch (error) {
    return FailureResult<T, AuthFailure>(
      AuthFailure(_toFailureType(error.code), debugMessage: error.debugMessage),
    );
  } catch (error) {
    return FailureResult<T, AuthFailure>(
      AuthFailure(AuthFailureType.unknown, debugMessage: error.toString()),
    );
  }
}

AuthFailureType _toFailureType(AuthDataErrorCode code) => switch (code) {
  AuthDataErrorCode.invalidCredentials => AuthFailureType.invalidCredentials,
  AuthDataErrorCode.network => AuthFailureType.network,
  AuthDataErrorCode.tooManyRequests => AuthFailureType.tooManyRequests,
  AuthDataErrorCode.emailAlreadyInUse => AuthFailureType.emailAlreadyInUse,
  AuthDataErrorCode.weakPassword => AuthFailureType.weakPassword,
  AuthDataErrorCode.cancelled => AuthFailureType.cancelled,
  AuthDataErrorCode.configuration => AuthFailureType.configuration,
  AuthDataErrorCode.invalidEmail => AuthFailureType.invalidEmail,
  AuthDataErrorCode.recentLoginRequired => AuthFailureType.recentLoginRequired,
  AuthDataErrorCode.unknown => AuthFailureType.unknown,
};
