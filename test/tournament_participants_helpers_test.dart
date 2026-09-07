import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_tp/utils/tournament_participants_helpers.dart';

void main() {
  group('TournamentParticipantsHelpers', () {
    test('agrupa por academyId y cuenta equipos', () {
      final teams = [
        {
          'id': 't1',
          'academy': {'_id': 'a1', 'name': 'THUNDERS FOOTBALL', 'logo': ''},
        },
        {
          'id': 't2',
          'academy': {'_id': 'a1', 'name': 'THUNDERS FOOTBALL'},
        },
        {
          'id': 't3',
          'academy': {'_id': 'a1', 'name': 'THUNDERS FOOTBALL'},
        },
        {
          'id': 't4',
          'academy': {'_id': 'a1', 'name': 'THUNDERS FOOTBALL'},
        },
        {
          'id': 't5',
          'academy': {'_id': 'a1', 'name': 'THUNDERS FOOTBALL'},
        },
      ];

      final groups = TournamentParticipantsHelpers.groupTeamsByAcademy(teams);
      expect(groups.length, 1);
      expect(groups.first.academyId, 'a1');
      expect(groups.first.teamCount, 5);
      expect(TournamentParticipantsHelpers.teamCountLabel(5), '5 equipos');
    });

    test('separates academies with different ids', () {
      final teams = [
        {
          'id': 't1',
          'academy': {'_id': 'a1', 'name': 'Pumas Academy'},
        },
        {
          'id': 't2',
          'academy': {'_id': 'a2', 'name': 'Pumas Club'},
        },
      ];

      final groups = TournamentParticipantsHelpers.groupTeamsByAcademy(teams);
      expect(groups.length, 2);
    });

    test('singular team count label', () {
      expect(TournamentParticipantsHelpers.teamCountLabel(1), '1 equipo');
    });

    test('badge label uppercase', () {
      expect(TournamentParticipantsHelpers.teamCountBadgeLabel(1), '1 EQUIPO');
      expect(TournamentParticipantsHelpers.teamCountBadgeLabel(5), '5 EQUIPOS');
    });

    test('resolveThemeAccent prefers accent over primary', () {
      final color = TournamentParticipantsHelpers.resolveThemeAccent({
        'accent': '#FF0000',
        'primary': '#00FF00',
      });
      expect(color, const Color(0xFFFF0000));
    });

    test('academy initials', () {
      expect(
        TournamentParticipantsHelpers.academyInitials('THUNDERS FOOTBALL'),
        'TF',
      );
      expect(
        TournamentParticipantsHelpers.academyInitials('BOARS ACADEMY'),
        'BA',
      );
      expect(
        TournamentParticipantsHelpers.academyInitials('BLKSPD'),
        'BL',
      );
    });

    test('deduplicates teams across category blocks', () {
      final blocks = [
        {
          'teams': [
            {'id': 't1', 'academy': {'_id': 'a1', 'name': 'Alpha'}},
          ],
          'groups': [
            {
              'teams': [
                {'id': 't1', 'academy': {'_id': 'a1', 'name': 'Alpha'}},
                {'id': 't2', 'academy': {'_id': 'a1', 'name': 'Alpha'}},
              ],
            },
          ],
        },
      ];

      final flat =
          TournamentParticipantsHelpers.flattenTeamsFromCategoryBlocks(blocks);
      expect(flat.length, 2);
    });

    test('enriches teams with category from block', () {
      final blocks = [
        {
          'category': {'name': 'U10 Femenil', 'shortName': 'U10'},
          'teams': [
            {
              'id': 't1',
              'academy': {'_id': 'a1', 'name': 'Alpha'},
            },
          ],
        },
      ];

      final flat =
          TournamentParticipantsHelpers.flattenTeamsFromCategoryBlocks(blocks);
      expect(flat.first['participantCategoryKey'], 'U10 Femenil');
      expect(flat.first['participantCategoryShortName'], 'U10');
    });

    test('buildAvailableCategories excludes empty categories', () {
      final teams = [
        {
          'id': 't1',
          'participantCategoryKey': 'U10',
          'participantCategoryShortName': 'U10',
          'academy': {'_id': 'a1', 'name': 'Alpha'},
        },
        {
          'id': 't2',
          'participantCategoryKey': 'U12',
          'participantCategoryShortName': 'U12',
          'academy': {'_id': 'a2', 'name': 'Beta'},
        },
      ];

      final options = TournamentParticipantsHelpers.buildAvailableCategories(
        teams,
        [
          {'name': 'U12'},
          {'name': 'U10'},
        ],
      );

      expect(options.length, 2);
      expect(options.first.key, 'U12');
      expect(options.last.key, 'U10');
    });

    test('filter visible academies by category', () {
      final teams = [
        {
          'id': 't1',
          'participantCategoryKey': 'U10',
          'academy': {'_id': 'a1', 'name': 'Alpha'},
        },
        {
          'id': 't2',
          'participantCategoryKey': 'U12',
          'academy': {'_id': 'a1', 'name': 'Alpha'},
        },
        {
          'id': 't3',
          'participantCategoryKey': 'U10',
          'academy': {'_id': 'a2', 'name': 'Beta'},
        },
      ];

      final all = TournamentParticipantsHelpers.groupTeamsByAcademy(teams);
      final visible = TournamentParticipantsHelpers.buildVisibleAcademies(
        all,
        'U10',
      );

      expect(visible.length, 2);
      expect(visible.first.visibleTeamCount, 1);
      expect(
        visible.firstWhere((a) => a.academyId == 'a1').visibleTeamCount,
        1,
      );
      expect(all.first.teamCount, 2);
    });

    test('participants summary with filter label', () {
      expect(
        TournamentParticipantsHelpers.participantsSummaryLabel(
          academyCount: 8,
          teamCount: 11,
          categoryShortName: 'U10',
        ),
        '8 academias · 11 equipos en U10',
      );
      expect(
        TournamentParticipantsHelpers.participantsSummaryLabel(
          academyCount: 1,
          teamCount: 1,
        ),
        '1 academia · 1 equipo',
      );
    });
    test('participants semantics label with filter', () {
      expect(
        TournamentParticipantsHelpers.participantsSemanticsLabel(
          academyName: 'Thunders Football',
          teamCount: 2,
          categoryShortName: 'U10',
        ),
        'Thunders Football, 2 equipos participantes en U10',
      );
    });

    test('count teams without academy id', () {
      final teams = [
        {'id': 't1'},
        {
          'id': 't2',
          'academy': {'_id': 'a1', 'name': 'Alpha'},
        },
      ];
      expect(
        TournamentParticipantsHelpers.countTeamsWithoutAcademyId(teams),
        1,
      );
    });
  });
}
