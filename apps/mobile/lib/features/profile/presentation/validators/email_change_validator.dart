String? validateEmailChange(String? value, {required String currentEmail}) {
  final email = (value ?? '').trim().toLowerCase();
  if (email.isEmpty ||
      email.length > 254 ||
      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Informe um e-mail válido.';
  }
  if (email == currentEmail.trim().toLowerCase()) {
    return 'Informe um e-mail diferente do atual.';
  }
  return null;
}
