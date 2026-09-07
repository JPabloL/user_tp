import 'package:flutter_test/flutter_test.dart';
import 'package:user_tp/models/academy_profile_models.dart';
import 'package:user_tp/utils/academy_match_helpers.dart';

void main() {
  group('AcademyMatchHelpers', () {
    test('detects internal match and academy outcome', () {
      final match = AcademyMatch.fromJson({
        'id': 'm-1',
        'categoryName': 'U10',
        'date': '2026-06-01',
        'home': {
          'teamName': 'Thunders',
          'academyId': 'acad-1',
          'points': 14,
        },
        'visitor': {
          'teamName': 'Ducks',
          'academyId': 'acad-1',
          'points': 10,
        },
      });

      expect(AcademyMatchHelpers.isInternalMatch(match, 'acad-1'), isTrue);
      expect(
        AcademyMatchHelpers.outcomeForAcademy(match, 'acad-1'),
        AcademyMatchOutcome.internal,
      );
      expect(
        AcademyMatchHelpers.outcomeLabel(
          AcademyMatchHelpers.outcomeForAcademy(match, 'acad-1'),
        ),
        'PARTIDO INTERNO',
      );
    });

    test('computes win loss tie from academy perspective', () {
      final win = AcademyMatch.fromJson({
        'id': 'm-2',
        'home': {'teamName': 'A', 'academyId': 'acad-1', 'points': 20},
        'visitor': {'teamName': 'B', 'academyId': 'acad-2', 'points': 12},
      });
      final loss = AcademyMatch.fromJson({
        'id': 'm-3',
        'home': {'teamName': 'A', 'academyId': 'acad-2', 'points': 20},
        'visitor': {'teamName': 'B', 'academyId': 'acad-1', 'points': 12},
      });

      expect(
        AcademyMatchHelpers.outcomeForAcademy(win, 'acad-1'),
        AcademyMatchOutcome.won,
      );
      expect(
        AcademyMatchHelpers.outcomeForAcademy(loss, 'acad-1'),
        AcademyMatchOutcome.lost,
      );
      expect(AcademyMatchHelpers.scoreLine(win), '20 — 12');
    });
  });
}
