class RegistrationFormValidator {
  const RegistrationFormValidator._();

  static String? displayName(String? value) {
    final normalized = value?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    if (normalized.length < 2) return 'Informe seu nome.';
    if (normalized.length > 80) return 'Use no máximo 80 caracteres.';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Crie uma senha.';
    if (value.length < 8) return 'Use pelo menos 8 caracteres.';
    return null;
  }

  static String? passwordConfirmation(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirme sua senha.';
    if (value != password) return 'As senhas não coincidem.';
    return null;
  }
}
