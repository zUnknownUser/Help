import '../../domain/failures/profile_failure.dart';

extension ProfileFailureMessage on ProfileFailure {
  String get userMessage => switch (type) {
    ProfileFailureType.network =>
      'Sem conexão. Verifique sua internet e tente novamente.',
    ProfileFailureType.invalidData =>
      'Confira os dados do perfil e tente novamente.',
    ProfileFailureType.unauthorized =>
      'Sua sessão expirou. Entre novamente para continuar.',
    _ => 'Não foi possível salvar seu perfil agora. Tente novamente.',
  };
}
