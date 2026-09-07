import 'package:flutter_test/flutter_test.dart';
import 'package:user_tp/models/academy_profile_models.dart';

void main() {
  group('AcademyProfileContext.fromJson', () {
    test('parses successful payload with nullable fields', () {
      final context = AcademyProfileContext.fromJson({
        'status': 'ok',
        'academy': {
          'id': 'acad-1',
          'name': 'Academia Demo',
          'logo': 'logo.png',
          'description': 'Descripción pública',
          'coverPhoto': null,
          'rs': [
            {'type': 'instagram', 'url': 'https://instagram.com/demo'},
            {'type': 'web', 'url': 'demo.com'},
          ],
        },
        'summary': {
          'registeredSince': '2024-01-15',
          'firstParticipationDate': null,
          'championships': 7,
          'tournaments': 15,
          'runnerUps': 3,
          'finals': 5,
        },
        'record': {
          'overall': {
            'played': 154,
            'wins': 112,
            'losses': 42,
            'winPctPercent': 72.7,
            'pointsFor': 4128,
            'pointsAgainst': 2045,
            'pointDiff': 2083,
            'internalMatches': 5,
          },
          'regular': {'played': 120, 'wins': 90, 'losses': 30, 'winPctPercent': 75},
          'playoffs': {'played': 17, 'wins': 12, 'losses': 5, 'ties': 0, 'pointsFor': 420, 'pointsAgainst': 310},
          'regularSeasonFromStandings': {
            'teamEntries': 18,
            'firstPlaces': 6,
            'secondPlaces': 4,
            'thirdPlaces': 3,
          },
        },
        'honors': {
          'finals': [],
          'championships': 2,
          'history': [
            {
              'result': 'Campeón',
              'type': 'championship',
              'year': '2026',
              'tournament': {'name': 'Fortnite - Galactic'},
              'category': {'shortName': 'U10'},
            },
          ],
        },
        'playoffs': {
          'appearances': 11,
          'teamParticipations': 120,
          'didNotReachPlayoffs': 31,
          'qualificationRate': 0.7417,
          'qualificationRatePercent': 74.17,
          'semifinalAppearances': 10,
          'semifinalWins': 7,
          'finalAppearances': 8,
          'finalWins': 5,
          'played': 17,
          'wins': 12,
          'losses': 5,
          'ties': 0,
          'championships': 5,
          'runnerUps': 3,
          'internalMatches': 0,
        },
        'categories': [
          {'id': 'cat-1', 'name': 'Junior'},
        ],
        'categoryStats': [
          {
            'category': {'name': 'Junior', 'key': 'junior'},
            'record': {'played': 82, 'wins': 63, 'losses': 19, 'winPctPercent': 76.8},
            'teamCount': 2,
            'championships': 5,
            'runnerUps': 2,
          },
        ],
        'yearStats': [
          {
            'year': '2026',
            'record': {'played': 54, 'wins': 41, 'losses': 13},
            'tournaments': 3,
            'championships': 3,
          },
        ],
        'leagues': [
          {
            'id': 'lg-1',
            'name': 'Liga Norte',
            'season': '2024',
            'tournamentCount': 4,
          },
        ],
        'tournaments': {
          'current': [
            {
              'tournament': {
                'id': 't-1',
                'name': 'Torneo Actual',
                'img': 'cover.jpg',
                'logo': 'logo.jpg',
                'start': '2026-05-01',
                'end': null,
                'league': 'Liga Norte',
                'status': 'current',
                'active': true,
              },
              'teamCount': 4,
              'categoryCount': 4,
              'championships': 0,
              'runnerUps': 0,
              'record': {'played': 4, 'wins': 2},
              'teams': [
                {
                  'name': 'Equipo A',
                  'category': {'shortName': 'Junior'},
                },
              ],
              'categories': [
                {'shortName': 'Junior', 'teamCount': 1},
              ],
              'standings': [
                {'teamName': 'Equipo A', 'position': 3, 'pj': 4, 'pg': 2},
              ],
              'finals': [],
            },
          ],
          'upcoming': [
            {
              'tournament': {
                'id': 't-up',
                'name': 'Torneo Próximo',
                'logo': 'up-logo.jpg',
                'start': '2026-12-01',
                'status': 'upcoming',
              },
              'teamCount': 2,
              'categoryCount': 1,
              'record': {'played': 0, 'wins': 0},
              'teams': [],
              'categories': [],
              'standings': [],
              'finals': [],
            },
          ],
          'history': [
            {
              'tournament': {
                'id': 't-old',
                'name': 'Torneo Histórico',
                'start': '2023-08-01',
                'league': 'Liga MX',
                'status': 'completed',
                'logo': 'old-logo.png',
              },
              'year': '2023',
              'result': 'Finalista',
              'teamCount': 3,
              'categoryCount': 2,
              'championships': 0,
              'runnerUps': 1,
              'record': {'played': 8, 'wins': 6, 'losses': 2},
              'teams': [
                {
                  'name': 'Equipo U10',
                  'category': {'shortName': 'U10'},
                  'playersCount': 12,
                },
              ],
              'categories': [
                {'shortName': 'U10', 'teamCount': 2},
              ],
              'standings': [
                {
                  'teamName': 'Equipo U10',
                  'categoryName': 'U10',
                  'position': 2,
                  'played': 8,
                  'wins': 6,
                  'losses': 2,
                  'pointsFor': 120,
                  'pointsAgainst': 80,
                  'pointDiff': 40,
                },
              ],
              'finals': [
                {
                  'academyResult': 'runner_up',
                  'category': {'shortName': 'U10'},
                  'champion': {'teamName': 'DUCKS'},
                  'runnerUp': {'teamName': 'THUNDERS'},
                  'score': '14 — 6',
                },
              ],
            },
          ],
        },
        'matches': {
          'totalDocuments': 20,
          'finishedOfficial': 18,
          'upcoming': [
            {
              'id': 'm-1',
              'date': '2026-06-01',
              'journey': 'J3',
              'home': {
                'teamId': 'team-1',
                'academyId': 'acad-1',
                'name': 'Home',
                'points': null,
              },
              'visitor': {
                'teamId': 'team-2',
                'academyId': 'acad-2',
                'name': 'Visitor',
                'points': '14',
              },
            },
          ],
          'recent': [],
        },
        'meta': {
          'generatedAt': '2026-05-20T12:00:00.000Z',
          'source': 'getAcademyProfileContext',
          'dataQuality': {
            'complete': false,
            'missingFields': ['coverPhoto'],
            'warnings': ['partial history'],
          },
        },
      });

      expect(context.academy.id, 'acad-1');
      expect(context.academy.name, 'Academia Demo');
      expect(context.academy.coverPhoto, isNull);
      expect(context.academy.socialLinks.length, 2);
      expect(context.summary.registeredSinceYearLabel(), '2024');
      expect(context.record.overall.played, 154);
      expect(context.record.overall.wins, 112);
      expect(context.record.playoffs.played, 17);
      expect(context.record.playoffs.wins, 12);
      expect(context.record.playoffs.pointsFor, 420);
      expect(context.playoffs.appearances, 11);
      expect(context.playoffs.teamParticipations, 120);
      expect(context.playoffs.didNotReachPlayoffs, 31);
      expect(context.playoffs.qualificationRatePercent, 74.17);
      expect(context.playoffs.semifinalWins, 7);
      expect(context.playoffs.finalAppearances, 8);
      expect(context.playoffs.championships, 5);
      expect(context.playoffs.runnerUps, 3);
      expect(context.record.regularSeasonFromStandings.firstPlaces, 6);
      expect(context.categoryStats.first.championships, 5);
      expect(context.yearStats.first.championships, 3);
      expect(context.categories.length, 1);
      expect(context.categoryStats.first.record.played, 82);
      expect(context.yearStats.first.tournaments, 3);
      expect(context.summary.championships, 7);
      expect(context.summary.tournaments, 15);
      expect(context.honors.history.first.tournament.name, 'Fortnite - Galactic');
      expect(context.honors.history.first.category.shortName, 'U10');
      expect(context.leagues.first.tournamentCount, 4);
      expect(context.tournaments.current.first.tournament.img, 'cover.jpg');
      expect(context.tournaments.current.first.teamCount, 4);
      expect(context.tournaments.current.first.tournament.league, 'Liga Norte');
      expect(context.tournaments.current.first.standings.first.position, 3);
      expect(context.tournaments.upcoming.first.tournament.name, 'Torneo Próximo');
      expect(context.tournaments.upcoming.first.tournament.status, 'upcoming');
      expect(context.tournaments.history.first.result, 'Finalista');
      expect(context.tournaments.history.first.tournament.league, 'Liga MX');
      expect(context.tournaments.history.first.championships, 0);
      expect(context.tournaments.history.first.runnerUps, 1);
      expect(context.tournaments.history.first.teams.first.name, 'Equipo U10');
      expect(context.tournaments.history.first.finals.first.resultLabel(), 'SUBCAMPEÓN');
      expect(context.matches.totalDocuments, 20);
      expect(context.matches.upcoming.first.visitor.points, 14);
      expect(context.meta.dataQuality.missingFields, ['coverPhoto']);
    });

    test('parses flat legacy current items without tournament wrapper', () {
      final context = AcademyProfileContext.fromJson({
        'academy': {'id': 'acad-1'},
        'summary': {},
        'record': {},
        'honors': {},
        'tournaments': {
          'current': [
            {
              'id': 't-flat',
              'name': 'Torneo Plano',
              'logo': 'flat-logo.jpg',
              'start': '2024-03-15',
              'league': {'name': 'Liga Sur'},
              'teamCount': 2,
              'record': {'played': 1, 'wins': 1},
            },
          ],
        },
      });

      expect(context.tournaments.current.first.tournament.id, 't-flat');
      expect(context.tournaments.current.first.tournament.name, 'Torneo Plano');
      expect(context.tournaments.current.first.tournament.league, 'Liga Sur');
    });

    test('parses getAcademyPublicProfile endpoint with snapshot and live tournaments', () {
      final context = AcademyProfileContext.fromJson({
        'status': 'ok',
        'academy': {
          'id': 'academy123',
          'name': 'THUNDERS FOOTBALL TEAM',
          'logo': 'logo.png',
          'description': 'Desc',
          'rs': [],
        },
        'snapshotAvailable': true,
        'snapshot': {
          'generatedAt': '2026-08-07T12:00:00.000Z',
          'summary': {
            'championships': 7,
            'tournaments': 15,
            'runnerUps': 3,
            'finals': 5,
          },
          'record': {
            'overall': {'played': 100, 'wins': 70, 'losses': 30},
          },
          'playoffs': {'appearances': 11, 'championships': 5},
          'honors': {'history': []},
          'categoryStats': [],
          'yearStats': [],
          'leagues': [],
          'tournaments': {'history': []},
        },
        'tournaments': {
          'current': [
            {
              'id': 'tournamentA',
              'name': 'Torneo Otoño 2026',
              'start': '2026-08-01',
              'end': '2026-11-20',
              'status': 'current',
              'academyParticipation': {
                'teamCount': 5,
                'teamIds': ['teamU8', 'teamU10'],
                'teams': [
                  {
                    'id': 'teamU8',
                    'name': 'THUNDERS',
                    'category': {'name': 'U8'},
                  },
                ],
              },
            },
          ],
          'upcoming': [],
        },
        'liveSummary': {
          'currentTournaments': 1,
          'upcomingTournaments': 0,
          'currentTeams': 5,
          'upcomingTeams': 0,
        },
      });

      expect(context.academy.id, 'academy123');
      expect(context.snapshotAvailable, isTrue);
      expect(context.liveSummary.currentTeams, 5);
      expect(context.summary.championships, 7);
      expect(context.playoffs.appearances, 11);
      expect(context.tournaments.current.length, 1);
      expect(context.tournaments.current.first.tournament.id, 'tournamentA');
      expect(context.tournaments.current.first.teamCount, 5);
      expect(
        context.tournaments.current.first.teams.first.categoryShortName,
        'U8',
      );
      expect(context.tournaments.history, isEmpty);
      expect(context.meta.source, 'getAcademyPublicProfile');
    });

    test('missing collections become empty lists and record defaults', () {
      final context = AcademyProfileContext.fromJson({
        'academy': {'name': 'Sin datos'},
        'summary': {},
        'record': {},
        'honors': {},
        'categories': null,
        'categoryStats': null,
        'yearStats': null,
        'leagues': null,
        'tournaments': null,
        'matches': null,
        'meta': {},
      });

      expect(context.categories, isEmpty);
      expect(context.categoryStats, isEmpty);
      expect(context.yearStats, isEmpty);
      expect(context.leagues, isEmpty);
      expect(context.tournaments.current, isEmpty);
      expect(context.tournaments.upcoming, isEmpty);
      expect(context.tournaments.history, isEmpty);
      expect(context.playoffs, AcademyPlayoffsParticipation.empty);
      expect(context.matches.upcoming, isEmpty);
      expect(context.matches.recent, isEmpty);
      expect(context.record.overall, AcademyRecord.empty);
      expect(context.academy.socialLinks, isEmpty);
    });
  });
}
