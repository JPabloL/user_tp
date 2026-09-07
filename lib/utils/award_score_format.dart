/// Formateo visual de puntuaciones para cards de reconocimientos.
/// No altera el valor calculado; solo su representación en UI.
String formatAwardDisplayScore(double value) {
  if (value.isNaN || value.isInfinite) return '0';

  final rounded = (value * 100).round() / 100;
  if (rounded == rounded.truncateToDouble()) {
    return rounded.truncate().toString();
  }

  final oneDecimal = (rounded * 10).round() / 10;
  final twoDecimalDiff = rounded - oneDecimal;
  if (twoDecimalDiff.abs() < 0.001) {
    return _trimTrailingZeros(oneDecimal.toStringAsFixed(1));
  }

  return _trimTrailingZeros(rounded.toStringAsFixed(2));
}

String _trimTrailingZeros(String formatted) {
  if (!formatted.contains('.')) return formatted;
  return formatted.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

/// Bonos positivos con prefijo +; cero sin prefijo.
String formatAwardBonus(double value) {
  if (value.isNaN || value.isInfinite || value <= 0) return '0';
  return '+${formatAwardDisplayScore(value)}';
}
