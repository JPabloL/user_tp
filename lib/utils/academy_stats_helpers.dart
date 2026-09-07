import 'package:intl/intl.dart';

import '../models/academy_profile_models.dart';

/// Formato y helpers para el tab Estadísticas.
class AcademyStatsHelpers {
  AcademyStatsHelpers._();

  static final NumberFormat _thousands = NumberFormat.decimalPattern('es');

  static String formatCount(int value) => _thousands.format(value);

  static String formatDiff(int value) {
    if (value > 0) return '+$value';
    if (value < 0) return value.toString();
    return '0';
  }

  static String formatWinPctPercent(double winPctPercent) {
    if (winPctPercent <= 0) return '';
    final normalized =
        winPctPercent > 1 ? winPctPercent : winPctPercent * 100;
    final formatted = normalized == normalized.roundToDouble()
        ? normalized.toStringAsFixed(0)
        : normalized.toStringAsFixed(1);
    return '$formatted%';
  }

  static String formatWinPctLabel(double winPctPercent) {
    final pct = formatWinPctPercent(winPctPercent);
    if (pct.isEmpty) return '';
    return '$pct DE VICTORIAS';
  }

  static bool hasEnoughMatches(AcademyRecord record) {
    return record.played > 0 || record.registeredMatches > 0;
  }

  static bool hasRecordActivity(AcademyRecord record) {
    return record.played > 0 ||
        record.wins > 0 ||
        record.losses > 0 ||
        record.registeredMatches > 0;
  }

  static int effectivePlayed(AcademyRecord record) {
    if (record.played > 0) return record.played;
    return record.registeredMatches;
  }

  static String standingsPlaceLabel({
    required int count,
    required int place,
  }) {
    if (count <= 0) return '';
    final suffix = place == 1 ? '°' : '°';
    return '$count veces $place$suffix';
  }
}
