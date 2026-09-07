import 'package:flutter_test/flutter_test.dart';
import 'package:user_tp/utils/match_awards.dart';

Map<String, dynamic> _baseMatch({
  Map<String, dynamic>? mvp,
  List<Map<String, dynamic>>? homeRoster,
  List<Map<String, dynamic>>? visitorRoster,
}) {
  return {
    '_id': 'match-1',
    if (mvp != null) 'mvp': mvp,
    'home': {
      '_id': 'team-home',
      'name': 'THUNDERS',
      'roster': homeRoster ??
          [
            {'_id': 'p-home-1', 'name': 'Capitán MVP', 'number': '7'},
            {'_id': 'p-home-2', 'name': 'Receptor', 'number': '11'},
            {'_id': 'p-home-3', 'name': 'Rusher', 'number': '22'},
          ],
    },
    'visitor': {
      '_id': 'team-visit',
      'name': 'BLKSPD',
      'roster': visitorRoster ??
          [
            {'_id': 'p-visit-1', 'name': 'QB Rival', 'number': '4'},
            {'_id': 'p-visit-2', 'name': 'Defensa', 'number': '9'},
          ],
    },
  };
}

List<Map<String, dynamic>> _playerPool(Map<String, dynamic> match) {
  final pool = <Map<String, dynamic>>[];
  for (final side in ['home', 'visitor']) {
    final roster = match[side]?['roster'] as List? ?? [];
    for (final raw in roster) {
      if (raw is Map) pool.add(Map<String, dynamic>.from(raw));
    }
  }
  return pool;
}

void main() {
  group('MatchAwardsResult.empty', () {
    test('getters en estado vacío', () {
      const empty = MatchAwardsResult.empty;
      expect(empty.hasMvp, isFalse);
      expect(empty.hasFeaturedPlayer, isFalse);
      expect(empty.hasOffensiveLeader, isFalse);
      expect(empty.hasDefensiveLeader, isFalse);
      expect(empty.hasAnyAward, isFalse);
    });
  });

  group('CASO A — sin acciones ni MVP', () {
    test('todos los reconocimientos son null', () {
      final match = _baseMatch();
      final result = calculateMatchAwards(
        match: match,
        players: _playerPool(match),
        actions: [],
      );

      expect(result.mvp, isNull);
      expect(result.featuredPlayer, isNull);
      expect(result.offensiveLeader, isNull);
      expect(result.defensiveLeader, isNull);
      expect(result.hasAnyAward, isFalse);
    });
  });

  group('CASO B — solo ofensiva', () {
    test('featured y offensive válidos; defensive null', () {
      final match = _baseMatch();
      final actions = [
        {
          '_id': 'a1',
          'date': '2026-01-01T10:00:00',
          'clave': 'pass',
          'points': 0,
          'team': {'_id': 'team-home'},
          'playerPass': {'_id': 'p-home-1'},
          'playerCatch': {'_id': 'p-home-2'},
        },
        {
          '_id': 'a2',
          'date': '2026-01-01T10:01:00',
          'clave': 'run',
          'points': 6,
          'team': {'_id': 'team-home'},
          'player': {'_id': 'p-home-3'},
        },
      ];

      final result = calculateMatchAwards(
        match: match,
        players: _playerPool(match),
        actions: actions,
      );

      expect(result.featuredPlayer, isNotNull);
      expect(result.offensiveLeader, isNotNull);
      expect(result.offensiveLeader!.score, greaterThan(0));
      expect(result.defensiveLeader, isNull);
      expect(result.hasDefensiveLeader, isFalse);
    });
  });

  group('CASO C — solo defensiva', () {
    test('featured y defensive válidos; offensive null', () {
      final match = _baseMatch();
      final actions = [
        {
          '_id': 'a1',
          'date': '2026-01-01T10:00:00',
          'clave': 'sack',
          'points': 0,
          'team': {'_id': 'team-home'},
          'player': {'_id': 'p-home-1'},
        },
        {
          '_id': 'a2',
          'date': '2026-01-01T10:01:00',
          'clave': 'inter',
          'points': 0,
          'team': {'_id': 'team-visit'},
          'player': {'_id': 'p-visit-2'},
        },
      ];

      final result = calculateMatchAwards(
        match: match,
        players: _playerPool(match),
        actions: actions,
      );

      expect(result.featuredPlayer, isNotNull);
      expect(result.defensiveLeader, isNotNull);
      expect(result.defensiveLeader!.score, greaterThan(0));
      expect(result.offensiveLeader, isNull);
      expect(result.hasOffensiveLeader, isFalse);
    });
  });

  group('CASO D — match.mvp manual', () {
    test('mvp válido e independiente de otros reconocimientos', () {
      final match = _baseMatch(
        mvp: {'_id': 'p-home-1', 'name': 'Capitán MVP'},
      );
      final actions = [
        {
          '_id': 'a1',
          'date': '2026-01-01T10:00:00',
          'clave': 'run',
          'points': 6,
          'team': {'_id': 'team-home'},
          'player': {'_id': 'p-home-3'},
        },
      ];

      final result = calculateMatchAwards(
        match: match,
        players: _playerPool(match),
        actions: actions,
      );

      expect(result.mvp?.source, 'manual');
      expect(result.mvp?.player['_id'], 'p-home-1');
      expect(result.featuredPlayer, isNotNull);
      expect(result.featuredPlayer?.player?['_id'], 'p-home-3');
    });
  });

  group('CASO E — eliminar match.mvp', () {
    test('mvp vuelve a null sin afectar otros reconocimientos', () {
      final matchWithMvp = _baseMatch(
        mvp: {'_id': 'p-home-1', 'name': 'Capitán MVP'},
      );
      final actions = [
        {
          '_id': 'a1',
          'date': '2026-01-01T10:00:00',
          'clave': 'run',
          'points': 6,
          'team': {'_id': 'team-home'},
          'player': {'_id': 'p-home-3'},
        },
      ];

      final withMvp = calculateMatchAwards(
        match: matchWithMvp,
        players: _playerPool(matchWithMvp),
        actions: actions,
      );
      expect(withMvp.mvp, isNotNull);

      final matchWithoutMvp = Map<String, dynamic>.from(matchWithMvp);
      matchWithoutMvp.remove('mvp');

      final withoutMvp = calculateMatchAwards(
        match: matchWithoutMvp,
        players: _playerPool(matchWithoutMvp),
        actions: actions,
      );

      expect(withoutMvp.mvp, isNull);
      expect(withoutMvp.featuredPlayer?.player?['_id'],
          withMvp.featuredPlayer?.player?['_id']);
      expect(withoutMvp.offensiveLeader?.score,
          withMvp.offensiveLeader?.score);
    });
  });

  group('CASO F — acción nueva (recálculo completo)', () {
    test('segunda acción incrementa producción ofensiva total', () {
      final match = _baseMatch();
      final initialActions = [
        {
          '_id': 'a1',
          'date': '2026-01-01T10:00:00',
          'clave': 'pass',
          'points': 0,
          'team': {'_id': 'team-home'},
          'playerPass': {'_id': 'p-home-1'},
          'playerCatch': {'_id': 'p-home-2'},
        },
      ];

      final afterFirst = calculateMatchAwards(
        match: match,
        players: _playerPool(match),
        actions: initialActions,
      );

      final updatedActions = [
        ...initialActions,
        {
          '_id': 'a2',
          'date': '2026-01-01T10:05:00',
          'clave': 'run',
          'points': 6,
          'team': {'_id': 'team-home'},
          'player': {'_id': 'p-home-3'},
        },
        {
          '_id': 'a3',
          'date': '2026-01-01T10:06:00',
          'clave': 'run',
          'points': 0,
          'team': {'_id': 'team-home'},
          'player': {'_id': 'p-home-3'},
        },
      ];

      final afterMore = calculateMatchAwards(
        match: match,
        players: _playerPool(match),
        actions: updatedActions,
      );

      expect(
        afterMore.offensiveLeader!.score,
        greaterThan(afterFirst.offensiveLeader?.score ?? 0),
      );
      expect(afterMore.featuredPlayer, isNotNull);
    });
  });

  group('CASO G — corrección de acción anterior', () {
    test('eliminar jugada que dio ventaja reduce bono contextual', () {
      final match = _baseMatch();
      final fullActions = [
        {
          '_id': 'a1',
          'date': '2026-01-01T10:00:00',
          'clave': 'run',
          'points': 6,
          'team': {'_id': 'team-home'},
          'player': {'_id': 'p-home-3'},
          'scoreHome': 6,
          'scoreVisitor': 0,
        },
      ];

      final withLead = calculateMatchAwards(
        match: match,
        players: _playerPool(match),
        actions: fullActions,
      );

      final afterCorrection = calculateMatchAwards(
        match: match,
        players: _playerPool(match),
        actions: [],
      );

      expect(withLead.featuredPlayer!.contextualBonus, greaterThan(0));
      expect(afterCorrection.featuredPlayer, isNull);
    });
  });

  group('CASO H — empate ofensivo', () {
    test('conserva todos los tiedPlayers sin elegir arbitrariamente', () {
      final match = _baseMatch();
      final actions = [
        {
          '_id': 'a1',
          'date': '2026-01-01T10:00:00',
          'clave': 'pass',
          'points': 0,
          'team': {'_id': 'team-home'},
          'playerPass': {'_id': 'p-home-1'},
          'playerCatch': {'_id': 'p-home-2'},
        },
        {
          '_id': 'a2',
          'date': '2026-01-01T10:01:00',
          'clave': 'pass',
          'points': 0,
          'team': {'_id': 'team-home'},
          'playerPass': {'_id': 'p-home-2'},
          'playerCatch': {'_id': 'p-home-1'},
        },
      ];

      final result = calculateMatchAwards(
        match: match,
        players: _playerPool(match),
        actions: actions,
      );

      expect(result.offensiveLeader, isNotNull);
      expect(result.offensiveLeader!.tiedPlayers.length, 2);
      final tiedIds = result.offensiveLeader!.tiedPlayers
          .map((p) => p['_id']?.toString())
          .toSet();
      expect(tiedIds, {'p-home-1', 'p-home-2'});
    });
  });

  group('orden cronológico', () {
    test('acciones invertidas en el arreglo producen mismo bono contextual', () {
      final match = _baseMatch();
      final chronological = [
        {
          '_id': 'a1',
          'sequence': 1,
          'date': '2026-01-01T10:00:00',
          'clave': 'run',
          'points': 6,
          'team': {'_id': 'team-visit'},
          'player': {'_id': 'p-visit-1'},
        },
        {
          '_id': 'a2',
          'sequence': 2,
          'date': '2026-01-01T10:05:00',
          'clave': 'run',
          'points': 6,
          'team': {'_id': 'team-home'},
          'player': {'_id': 'p-home-3'},
          'scoreHome': 6,
          'scoreVisitor': 6,
        },
        {
          '_id': 'a3',
          'sequence': 3,
          'date': '2026-01-01T10:10:00',
          'clave': 'run',
          'points': 6,
          'team': {'_id': 'team-home'},
          'player': {'_id': 'p-home-3'},
          'scoreHome': 12,
          'scoreVisitor': 6,
        },
      ];

      final reversed = List<Map<String, dynamic>>.from(chronological.reversed);

      final fromChrono = calculateMatchAwards(
        match: match,
        players: _playerPool(match),
        actions: chronological,
      );
      final fromReversed = calculateMatchAwards(
        match: match,
        players: _playerPool(match),
        actions: reversed,
      );

      expect(
        fromChrono.featuredPlayer?.contextualBonus,
        fromReversed.featuredPlayer?.contextualBonus,
      );
    });
  });
}
