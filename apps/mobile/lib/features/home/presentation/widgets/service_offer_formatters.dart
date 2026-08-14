String compactReviews(int value) {
  if (value < 1000) return '$value';
  return '${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')} mil';
}

String formatDuration(int minutes) {
  if (minutes > 60 && minutes % 60 != 0) {
    return '${(minutes / 60).toStringAsFixed(1).replaceAll('.', ',')} h';
  }
  return '$minutes min';
}

String formatMoney(int cents) {
  final reais = cents ~/ 100;
  final remainder = cents % 100;
  return remainder == 0
      ? 'R\$ $reais'
      : 'R\$ $reais,${remainder.toString().padLeft(2, '0')}';
}
