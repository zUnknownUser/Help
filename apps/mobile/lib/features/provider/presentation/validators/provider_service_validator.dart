class ProviderServiceValidator {
  const ProviderServiceValidator();

  String? title(String? value) {
    final length = value?.trim().runes.length ?? 0;
    if (length < 3) return 'Informe um título com pelo menos 3 caracteres.';
    if (length > 100) return 'Use no máximo 100 caracteres.';
    return null;
  }

  String? description(String? value) {
    final length = value?.trim().runes.length ?? 0;
    if (length < 10) return 'Descreva o serviço com pelo menos 10 caracteres.';
    if (length > 1000) return 'Use no máximo 1000 caracteres.';
    return null;
  }

  String? duration(String? value) {
    final minutes = int.tryParse(value?.trim() ?? '');
    if (minutes == null || minutes < 15 || minutes > 1440) {
      return 'Informe uma duração entre 15 e 1440 minutos.';
    }
    return null;
  }

  String? price(String? value) {
    final normalized = _normalizedAmount(value ?? '');
    final amount = double.tryParse(normalized);
    if (amount == null || amount < 0 || amount > 1000000) {
      return 'Informe um valor válido.';
    }
    return null;
  }

  String? oldPrice(String? value, {required String currentPrice}) {
    final invalid = price(value);
    if (invalid != null) return invalid;
    if (priceInCents(value!) <= priceInCents(currentPrice)) {
      return 'O valor anterior precisa ser maior que o promocional.';
    }
    return null;
  }

  String? imageUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme)) {
      return 'Use uma URL HTTP ou HTTPS válida.';
    }
    return null;
  }

  int priceInCents(String value) {
    final normalized = _normalizedAmount(value);
    return (double.parse(normalized) * 100).round();
  }

  String _normalizedAmount(String value) {
    final trimmed = value.trim();
    return trimmed.contains(',')
        ? trimmed.replaceAll('.', '').replaceAll(',', '.')
        : trimmed;
  }
}
