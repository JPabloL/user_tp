import 'package:flutter_test/flutter_test.dart';
import 'package:user_tp/models/academy_profile_models.dart';
import 'package:user_tp/utils/academy_stats_helpers.dart';

void main() {
  group('AcademyStatsHelpers', () {
    test('formats diff and win percentage', () {
      expect(AcademyStatsHelpers.formatDiff(175), '+175');
      expect(AcademyStatsHelpers.formatDiff(-32), '-32');
      expect(AcademyStatsHelpers.formatDiff(0), '0');
      expect(AcademyStatsHelpers.formatWinPctPercent(72.7), '72.7%');
      expect(AcademyStatsHelpers.formatWinPctLabel(72.7), '72.7% DE VICTORIAS');
    });

    test('detects insufficient matches', () {
      expect(AcademyStatsHelpers.hasEnoughMatches(AcademyRecord.empty), isFalse);
      expect(
        AcademyStatsHelpers.hasEnoughMatches(
          const AcademyRecord(
            played: 10,
            wins: 6,
            losses: 4,
            ties: 0,
            pointsFor: 0,
            pointsAgainst: 0,
            pointDiff: 0,
            winPct: 0,
            winPctPercent: 60,
            shutoutsFor: 0,
            shutoutsAgainst: 0,
            internalMatches: 0,
            registeredMatches: 10,
          ),
        ),
        isTrue,
      );
    });
  });
}
