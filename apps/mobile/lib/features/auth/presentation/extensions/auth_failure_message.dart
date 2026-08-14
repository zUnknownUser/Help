import '../../domain/failures/auth_failure.dart';

extension AuthFailureMessage on AuthFailure {
  String get userMessage => switch (type) {
    AuthFailureType.invalidCredentials =>
      'E-mail ou senha incorretos. Verifique os dados e tente novamente.',
    AuthFailureType.network =>
      'Sem conexão. Verifique sua internet e tente novamente.',
    AuthFailureType.tooManyRequests =>
      'Muitas tentativas. Aguarde alguns minutos e tente novamente.',
    AuthFailureType.cancelled => 'Entrada cancelada.',
    AuthFailureType.configuration =>
      'Este método de entrada ainda não está configurado.',
    AuthFailureType.unknown =>
      'Não foi possível entrar agora. Tente novamente em instantes.',
  };

  String get passwordResetMessage => switch (type) {
    AuthFailureType.network =>
      'Sem conexão. Verifique sua internet e tente novamente.',
    AuthFailureType.tooManyRequests =>
      'Muitas tentativas. Aguarde um minuto e tente novamente.',
    _ =>
      'Não foi possível enviar as instruções agora. Tente novamente em instantes.',
  };
}
