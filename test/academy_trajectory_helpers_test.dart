import 'package:flutter_test/flutter_test.dart';
import 'package:user_tp/models/academy_profile_models.dart';
import 'package:user_tp/utils/academy_trajectory_helpers.dart';

void main() {
  group('AcademyTrajectoryHelpers', () {
    test('groups history by tournament.start year preserving order', () {
      final history = [
        AcademyTournamentHistory.fromJson({
          'tournament': {
            'id': 't-2026-a',
            'name': 'Fortnite - Galactic',
            'start': '2026-03-01',
          },
        }),
        AcademyTournamentHistory.fromJson({
          'tournament': {
            'id': 't-2026-b',
            'name': 'Abierto Queretano',
            'start': '2026-01-15',
          },
        }),
        AcademyTournamentHistory.fromJson({
          'tournament': {
            'id': 't-2025',
            'name': 'Batalla de Héroes',
            'start': '2025-11-01',
          },
        }),
      ];

      final grouped = AcademyTrajectoryHelpers.groupHistoryByYear(history);
      final years = AcademyTrajectoryHelpers.sortedYears(grouped);

      expect(years, ['2026', '2025']);
      expect(grouped['2026']!.map((e) => e.name).toList(), [
        'Fortnite - Galactic',
        'Abierto Queretano',
      ]);
    });

    test('record compact label omits zero stats', () {
      expect(
        AcademyTrajectoryHelpers.recordCompactLabel(AcademyRecord.empty),
        isNull,
      );
      expect(
        AcademyTrajectoryHelpers.recordCompactLabel(
          const AcademyRecord(
            played: 0,
            wins: 0,
            losses: 0,
            ties: 0,
            pointsFor: 0,
            pointsAgainst: 0,
            pointDiff: 0,
            winPct: 0,
            winPctPercent: 0,
            shutoutsFor: 0,
            shutoutsAgainst: 0,
            internalMatches: 0,
            registeredMatches: 0,
          ),
        ),
        isNull,
      );
      expect(
        AcademyTrajectoryHelpers.recordCompactLabel(
          const AcademyRecord(
            played: 10,
            wins: 8,
            losses: 2,
            ties: 0,
            pointsFor: 0,
            pointsAgainst: 0,
            pointDiff: 0,
            winPct: 0,
            winPctPercent: 0,
            shutoutsFor: 0,
            shutoutsAgainst: 0,
            internalMatches: 0,
            registeredMatches: 10,
          ),
        ),
        '8 G · 2 P',
      );
    });

    test('infers championships from honors when history count is zero', () {
      final honor = AcademyHonorHistory.fromJson({
        'result': 'Campeón',
        'type': 'championship',
        'year': '2019',
        'tournament': {'id': 't-old', 'name': 'Torneo Antiguo'},
        'category': {'shortName': 'U10'},
      });
      final item = AcademyTournamentHistory.fromJson({
        'tournament': {
          'id': 't-old',
          'name': 'Torneo Antiguo',
          'start': '2019-06-01',
        },
        'championships': 0,
        'teams': [],
      });

      expect(
        AcademyTrajectoryHelpers.effectiveChampionshipCount(item, [honor]),
        1,
      );
    });

    test('resolves teams from standings when teams array is empty', () {
      final item = AcademyTournamentHistory.fromJson({
        'tournament': {'id': 't-1', 'name': 'Torneo'},
        'teams': [],
        'standings': [
          {
            'teamName': 'Thunders U10',
            'categoryName': 'U10',
            'played': 5,
            'wins': 4,
            'losses': 1,
          },
        ],
      });

      final teams = AcademyTrajectoryHelpers.resolvedTeams(item);
      expect(teams.length, 1);
      expect(teams.first.name, 'Thunders U10');
      expect(teams.first.categoryShortName, 'U10');
    });

    test('matches honors with normalized tournament names', () {
      final honor = AcademyHonorHistory.fromJson({
        'result': 'Campeón',
        'type': 'championship',
        'year': '2026',
        'tournament': {'name': 'Fortnite Galactic'},
        'category': {'shortName': 'U10'},
      });
      final item = AcademyTournamentHistory.fromJson({
        'tournament': {
          'id': 't-1',
          'name': 'Fortnite - Galactic',
          'start': '2026-03-01',
        },
        'championships': 0,
      });

      expect(
        AcademyTrajectoryHelpers.effectiveChampionshipCount(item, [honor]),
        1,
      );
    });

    test('matches honors when tournament id is only on history root', () {
      final honor = AcademyHonorHistory.fromJson({
        'result': 'Campeón',
        'year': '2026',
        'tournamentId': 't-root',
        'tournament': {'name': 'Torneo Actual'},
        'category': {'shortName': 'U12'},
      });
      final item = AcademyTournamentHistory.fromJson({
        'tournamentId': 't-root',
        'tournament': {'name': 'Torneo Actual', 'start': '2026-01-01'},
        'championships': 0,
      });

      expect(
        AcademyTrajectoryHelpers.effectiveChampionshipCount(item, [honor]),
        1,
      );
    });
  });
}
