import 'dart:math' as math;

import 'match_helpers.dart';

/// Resultado normalizado de reconocimientos del partido.
class MatchAwardsResult {
  const MatchAwardsResult({
    this.mvp,
    this.featuredPlayer,
    this.offensiveLeader,
    this.defensiveLeader,
    this.playerScores = const [],
  });

  static const MatchAwardsResult empty = MatchAwardsResult();

  final MvpAward? mvp;
  final FeaturedPlayerAward? featuredPlayer;
  final LeaderAward? offensiveLeader;
  final LeaderAward? defensiveLeader;
  final List<PlayerMatchAwardScore> playerScores;

  bool get hasMvp => mvp != null;

  bool get hasFeaturedPlayer => featuredPlayer != null;

  bool get hasOffensiveLeader =>
      offensiveLeader != null && offensiveLeader!.score > 0;

  bool get hasDefensiveLeader =>
      defensiveLeader != null && defensiveLeader!.score > 0;

  bool get hasPlayerScores => playerScores.isNotEmpty;

  bool get hasAnyAward =>
      hasMvp ||
      hasFeaturedPlayer ||
      hasOffensiveLeader ||
      hasDefensiveLeader ||
      hasPlayerScores;

  Map<String, dynamic> toJson() => {
        'mvp': mvp?.toJson(),
        'featuredPlayer': featuredPlayer?.toJson(),
        'offensiveLeader': offensiveLeader?.toJson(),
        'defensiveLeader': defensiveLeader?.toJson(),
        'playerScores': playerScores.map((e) => e.toJson()).toList(),
      };
}

/// Puntuación de impacto calculada para un jugador del partido.
class PlayerMatchAwardScore {
  const PlayerMatchAwardScore({
    required this.player,
    required this.integralImpactScore,
    required this.productionScore,
    required this.offensiveScore,
    required this.defensiveScore,
  });

  final Map<String, dynamic> player;
  final double integralImpactScore;
  final double productionScore;
  final double offensiveScore;
  final double defensiveScore;

  Map<String, dynamic> toJson() => {
        'player': player,
        'integralImpactScore': integralImpactScore,
        'productionScore': productionScore,
        'offensiveScore': offensiveScore,
        'defensiveScore': defensiveScore,
      };
}

class MvpAward {
  const MvpAward({
    required this.player,
    required this.source,
  });

  final Map<String, dynamic> player;
  final String source;

  Map<String, dynamic> toJson() => {
        'player': player,
        'source': source,
      };
}

class FeaturedPlayerAward {
  const FeaturedPlayerAward({
    this.player,
    required this.integralImpactScore,
    required this.productionScore,
    required this.offensiveScore,
    required this.defensiveScore,
    required this.versatilityBonus,
    required this.twoWayBonus,
    required this.contextualBonus,
    required this.activeFamilies,
    this.tiedPlayers = const [],
  });

  final Map<String, dynamic>? player;
  final double integralImpactScore;
  final double productionScore;
  final double offensiveScore;
  final double defensiveScore;
  final int versatilityBonus;
  final double twoWayBonus;
  final double contextualBonus;
  final int activeFamilies;
  final List<Map<String, dynamic>> tiedPlayers;

  Map<String, dynamic> toJson() => {
        'player': player,
        'integralImpactScore': integralImpactScore,
        'productionScore': productionScore,
        'offensiveScore': offensiveScore,
        'defensiveScore': defensiveScore,
        'versatilityBonus': versatilityBonus,
        'twoWayBonus': twoWayBonus,
        'contextualBonus': contextualBonus,
        'activeFamilies': activeFamilies,
        if (tiedPlayers.isNotEmpty) 'tiedPlayers': tiedPlayers,
      };
}

class LeaderAward {
  const LeaderAward({
    required this.player,
    required this.score,
    required this.scoreKey,
    this.tiedPlayers = const [],
  });

  final Map<String, dynamic> player;
  final double score;
  final String scoreKey;
  final List<Map<String, dynamic>> tiedPlayers;

  Map<String, dynamic> toJson() => {
        'player': player,
        scoreKey: score,
        'tiedPlayers': tiedPlayers,
      };
}

// ── Tabla de ponderaciones (producción) ─────────────────────────────────────
// Ofensiva: pase 0.6 | recepción 1.2 | carrera 1.2
// Defensiva: sack 2 | safety 5 | inter 4 | inter+2pts 5 | pick-six 7
// Las acciones especiales sustituyen a la normal (no se acumulan).

enum _DefensiveKind {
  normalSack,
  safety,
  normalInter,
  interceptionReturn2Pts,
  pickSix,
}

class _PlayerProduction {
  _PlayerProduction({required this.player});

  final Map<String, dynamic> player;

  int passes = 0;
  int receptions = 0;
  int runs = 0;
  int normalSacks = 0;
  int safeties = 0;
  int normalInterceptions = 0;
  int interceptionReturns2Pts = 0;
  int pickSixes = 0;

  bool familyPass = false;
  bool familyReception = false;
  bool familyRun = false;
  bool familySack = false;
  bool familyInter = false;

  double offensiveScore = 0;
  double defensiveScore = 0;
  double productionScore = 0;
  double contextualBonus = 0;
  int versatilityBonus = 0;
  double twoWayBonus = 0;
  double integralImpactScore = 0;
  int activeFamilies = 0;
}

/// Calcula MVP, jugador destacado y líderes ofensivo/defensivo del partido.
MatchAwardsResult calculateMatchAwards({
  required Map<String, dynamic> match,
  required List<Map<String, dynamic>> players,
  required List<dynamic> actions,
}) {
  final rosterIndex = _buildRosterIndex(match, players);
  final mvp = _resolveMvp(match, rosterIndex);

  final sortedActions = _filterAndSortActions(actions);
  final productions = <String, _PlayerProduction>{};

  void ensurePlayer(Map<String, dynamic>? raw) {
    if (raw == null) return;
    final id = _entityId(raw);
    if (id.isEmpty) return;
    productions.putIfAbsent(
      id,
      () => _PlayerProduction(
        player: rosterIndex[id] ?? _normalizePlayer(raw),
      ),
    );
  }

  for (final action in sortedActions) {
    _accumulateProduction(action, productions, rosterIndex, ensurePlayer);
  }

  _applyContextualBonuses(sortedActions, match, productions, ensurePlayer);

  for (final prod in productions.values) {
    prod.offensiveScore =
        prod.passes * 0.6 + prod.receptions * 1.2 + prod.runs * 1.2;
    prod.defensiveScore = prod.normalSacks * 2 +
        prod.safeties * 5 +
        prod.normalInterceptions * 4 +
        prod.interceptionReturns2Pts * 5 +
        prod.pickSixes * 7;
    prod.productionScore = prod.offensiveScore + prod.defensiveScore;

    prod.activeFamilies = [
      prod.familyPass,
      prod.familyReception,
      prod.familyRun,
      prod.familySack,
      prod.familyInter,
    ].where((v) => v).length;

    prod.versatilityBonus =
        math.min(math.max(prod.activeFamilies - 1, 0) * 2, 8);

    prod.twoWayBonus = prod.offensiveScore > 0 && prod.defensiveScore > 0
        ? math.min(
            math.min(prod.offensiveScore, prod.defensiveScore) * 0.35,
            8,
          )
        : 0;

    prod.integralImpactScore = prod.productionScore +
        prod.versatilityBonus +
        prod.twoWayBonus +
        prod.contextualBonus;
  }

  final featured = _selectFeaturedPlayer(productions);
  final offensive = _selectLeader(
    productions,
    scoreKey: 'offensiveScore',
    scoreSelector: (p) => p.offensiveScore,
  );
  final defensive = _selectLeader(
    productions,
    scoreKey: 'defensiveScore',
    scoreSelector: (p) => p.defensiveScore,
  );

  return MatchAwardsResult(
    mvp: mvp,
    featuredPlayer: featured,
    offensiveLeader: offensive,
    defensiveLeader: defensive,
    playerScores: _buildPlayerScoreList(productions, rosterIndex),
  );
}

List<PlayerMatchAwardScore> _buildPlayerScoreList(
  Map<String, _PlayerProduction> productions,
  Map<String, Map<String, dynamic>> rosterIndex,
) {
  final list = <PlayerMatchAwardScore>[];

  for (final entry in rosterIndex.entries) {
    final prod = productions[entry.key];
    final integral = prod != null ? _expose(prod.integralImpactScore) : 0.0;
    final production = prod != null ? _expose(prod.productionScore) : 0.0;
    if (integral <= 0 && production <= 0) continue;

    list.add(
      PlayerMatchAwardScore(
        player: Map<String, dynamic>.from(entry.value),
        integralImpactScore: integral,
        productionScore: production,
        offensiveScore: prod != null ? _expose(prod.offensiveScore) : 0,
        defensiveScore: prod != null ? _expose(prod.defensiveScore) : 0,
      ),
    );
  }

  list.sort((a, b) => b.integralImpactScore.compareTo(a.integralImpactScore));
  return list;
}

MvpAward? _resolveMvp(
  Map<String, dynamic> match,
  Map<String, Map<String, dynamic>> rosterIndex,
) {
  final raw = match['mvp'];
  if (raw == null) return null;

  if (raw is String) {
    final id = raw.trim();
    if (id.isEmpty) return null;
    final resolved = rosterIndex[id];
    if (resolved == null) return null;
    return MvpAward(player: Map<String, dynamic>.from(resolved), source: 'manual');
  }

  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    final id = _entityId(map);
    if (id.isEmpty) return null;
    final resolved = rosterIndex[id];
    if (resolved == null) return null;
    return MvpAward(
      player: _mergePlayer(resolved, map),
      source: 'manual',
    );
  }

  return null;
}

Map<String, Map<String, dynamic>> _buildRosterIndex(
  Map<String, dynamic> match,
  List<Map<String, dynamic>> players,
) {
  final index = <String, Map<String, dynamic>>{};

  void addFromTeam(Map<String, dynamic> team, {required bool isHome}) {
    final roster = team['roster'] as List<dynamic>? ?? [];
    for (final raw in roster) {
      if (raw is! Map) continue;
      final enriched = _enrichPlayer(
        Map<String, dynamic>.from(raw),
        team,
        isHome: isHome,
      );
      final id = _entityId(enriched);
      if (id.isEmpty) continue;
      index[id] = enriched;
    }
  }

  final home = MatchHelpers.asMap(match['home']);
  final visitor = MatchHelpers.asMap(match['visitor']);
  addFromTeam(home, isHome: true);
  addFromTeam(visitor, isHome: false);

  for (final raw in players) {
    final id = _entityId(raw);
    if (id.isEmpty) continue;
    final existing = index[id];
    if (existing != null) {
      index[id] = _mergePlayer(existing, raw);
    } else {
      index[id] = _normalizePlayer(raw);
    }
  }

  return index;
}

List<Map<String, dynamic>> _filterAndSortActions(List<dynamic> actions) {
  final list = <Map<String, dynamic>>[];
  for (final raw in actions) {
    if (raw is! Map) continue;
    final action = Map<String, dynamic>.from(raw);
    if (_shouldSkipForAwards(action)) continue;
    list.add(action);
  }
  list.sort(_compareActionsChronologically);
  return list;
}

int _compareActionsChronologically(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final dateA = _parseActionDate(a);
  final dateB = _parseActionDate(b);
  if (dateA != null && dateB != null) {
    final cmp = dateA.compareTo(dateB);
    if (cmp != 0) return cmp;
  } else if (dateA != null) {
    return -1;
  } else if (dateB != null) {
    return 1;
  }

  final seqA = _actionSequenceValue(a);
  final seqB = _actionSequenceValue(b);
  if (seqA != seqB) return seqA.compareTo(seqB);

  return _entityId(a).compareTo(_entityId(b));
}

DateTime? _parseActionDate(Map<String, dynamic> action) {
  for (final key in [
    'date',
    'createdAt',
    'timestamp',
    'created_at',
    'updatedAt',
  ]) {
    final raw = (action[key] ?? '').toString().trim();
    if (raw.isEmpty) continue;
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  return null;
}

int _actionSequenceValue(Map<String, dynamic> action) {
  for (final key in [
    'sequence',
    'playNumber',
    'actionNumber',
    'num',
    'order',
    'index',
  ]) {
    final value = action[key];
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

List<Map<String, dynamic>> _uniquePlayerMaps(
  List<Map<String, dynamic>> players,
) {
  final seen = <String>{};
  final out = <Map<String, dynamic>>[];
  for (final player in players) {
    final id = _entityId(player);
    if (id.isNotEmpty) {
      if (seen.contains(id)) continue;
      seen.add(id);
    }
    out.add(Map<String, dynamic>.from(player));
  }
  return out;
}

void _accumulateProduction(
  Map<String, dynamic> action,
  Map<String, _PlayerProduction> productions,
  Map<String, Map<String, dynamic>> rosterIndex,
  void Function(Map<String, dynamic>?) ensurePlayer,
) {
  final clave = _actionClave(action);

  if (_matchesClave(clave, 'pass')) {
    final passer = _playerFromAction(action, 'playerPass');
    final catcher = _playerFromAction(action, 'playerCatch');
    if (passer != null) {
      ensurePlayer(_resolveActionPlayer(passer, rosterIndex));
      final id = _entityId(passer);
      productions[id]?.passes++;
      productions[id]?.familyPass = true;
    }
    if (catcher != null) {
      ensurePlayer(_resolveActionPlayer(catcher, rosterIndex));
      final id = _entityId(catcher);
      productions[id]?.receptions++;
      productions[id]?.familyReception = true;
    }
    return;
  }

  if (_matchesClave(clave, 'catch')) {
    final catcher = _playerFromAction(action, 'playerCatch');
    if (catcher != null) {
      ensurePlayer(_resolveActionPlayer(catcher, rosterIndex));
      final id = _entityId(catcher);
      productions[id]?.receptions++;
      productions[id]?.familyReception = true;
    }
    return;
  }

  if (_matchesClave(clave, 'run')) {
    final runner = _playerFromAction(action, 'player');
    if (runner != null) {
      ensurePlayer(_resolveActionPlayer(runner, rosterIndex));
      final id = _entityId(runner);
      productions[id]?.runs++;
      productions[id]?.familyRun = true;
    }
    return;
  }

  final defensiveKind = _classifyDefensiveAction(action);
  if (defensiveKind != null) {
    final defender = _playerFromAction(action, 'player');
    if (defender != null) {
      ensurePlayer(_resolveActionPlayer(defender, rosterIndex));
      final id = _entityId(defender);
      final prod = productions[id];
      if (prod == null) return;

      switch (defensiveKind) {
        case _DefensiveKind.normalSack:
          prod.normalSacks++;
          prod.familySack = true;
        case _DefensiveKind.safety:
          prod.safeties++;
          prod.familySack = true;
        case _DefensiveKind.normalInter:
          prod.normalInterceptions++;
          prod.familyInter = true;
        case _DefensiveKind.interceptionReturn2Pts:
          prod.interceptionReturns2Pts++;
          prod.familyInter = true;
        case _DefensiveKind.pickSix:
          prod.pickSixes++;
          prod.familyInter = true;
      }
    }
  }
}

void _applyContextualBonuses(
  List<Map<String, dynamic>> sortedActions,
  Map<String, dynamic> match,
  Map<String, _PlayerProduction> productions,
  void Function(Map<String, dynamic>?) ensurePlayer,
) {
  final homeId = _homeTeamId(match);
  int homeScore = 0;
  int visitorScore = 0;

  for (final action in sortedActions) {
    final pts = _actionPoints(action);
    final teamId = _teamIdFromAction(action);

    if (pts > 0 && teamId.isNotEmpty) {
      final isHomeScoring = teamId == homeId ||
          _isHomeTeamAction(action, match, homeId: homeId);

      final teamBefore = isHomeScoring ? homeScore : visitorScore;
      final oppBefore = isHomeScoring ? visitorScore : homeScore;
      final teamAfter = teamBefore + pts;

      final diffBefore = teamBefore - oppBefore;
      final diffAfter = teamAfter - oppBefore;

      int bonus = 0;
      if (diffBefore < 0 && diffAfter == 0) {
        bonus = 2;
      } else if (diffBefore <= 0 && diffAfter > 0) {
        bonus = 3;
      }

      if (bonus > 0) {
        _distributeContextualBonus(
          action,
          bonus,
          productions,
          ensurePlayer,
        );
      }

      if (isHomeScoring) {
        homeScore += pts;
      } else {
        visitorScore += pts;
      }
    }

    final fromHome = action['scoreHome'] ?? action['homePoints'] ?? action['scoreH'];
    final fromVisitor =
        action['scoreVisitor'] ?? action['visitorPoints'] ?? action['scoreV'];
    if (fromHome != null && fromVisitor != null) {
      homeScore = _asInt(fromHome, homeScore);
      visitorScore = _asInt(fromVisitor, visitorScore);
    }
  }
}

void _distributeContextualBonus(
  Map<String, dynamic> action,
  int bonus,
  Map<String, _PlayerProduction> productions,
  void Function(Map<String, dynamic>?) ensurePlayer,
) {
  final clave = _actionClave(action);

  if (_matchesClave(clave, 'pass')) {
    final passer = _playerFromAction(action, 'playerPass');
    final catcher = _playerFromAction(action, 'playerCatch');
    if (passer != null && catcher != null) {
      final half = bonus / 2.0;
      ensurePlayer(passer);
      ensurePlayer(catcher);
      final passId = _entityId(passer);
      final catchId = _entityId(catcher);
      if (passId.isNotEmpty) productions[passId]?.contextualBonus += half;
      if (catchId.isNotEmpty) productions[catchId]?.contextualBonus += half;
      return;
    }
    final single = passer ?? catcher;
    if (single != null) {
      ensurePlayer(single);
      final id = _entityId(single);
      if (id.isNotEmpty) productions[id]?.contextualBonus += bonus.toDouble();
    }
    return;
  }

  if (_matchesClave(clave, 'run')) {
    final runner = _playerFromAction(action, 'player');
    if (runner != null) {
      ensurePlayer(runner);
      final id = _entityId(runner);
      if (id.isNotEmpty) {
        productions[id]?.contextualBonus += bonus.toDouble();
      }
    }
    return;
  }

  final defensiveKind = _classifyDefensiveAction(action);
  if (defensiveKind == _DefensiveKind.safety ||
      defensiveKind == _DefensiveKind.interceptionReturn2Pts ||
      defensiveKind == _DefensiveKind.pickSix) {
    final defender = _playerFromAction(action, 'player');
    if (defender != null) {
      ensurePlayer(defender);
      final id = _entityId(defender);
      if (id.isNotEmpty) {
        productions[id]?.contextualBonus += bonus.toDouble();
      }
    }
  }
}

FeaturedPlayerAward? _selectFeaturedPlayer(
  Map<String, _PlayerProduction> productions,
) {
  final candidates = productions.values
      .where((p) => p.productionScore > 0)
      .toList(growable: false);
  if (candidates.isEmpty) return null;

  List<_PlayerProduction> pool = List<_PlayerProduction>.from(candidates);

  pool = _filterMax(pool, (p) => p.integralImpactScore);
  if (pool.length > 1) {
    pool = _filterMax(pool, (p) => p.contextualBonus);
  }
  if (pool.length > 1) {
    pool = _filterMax(pool, (p) => p.twoWayBonus);
  }
  if (pool.length > 1) {
    pool = _filterMax(pool, (p) => p.activeFamilies.toDouble());
  }
  if (pool.length > 1) {
    pool = _filterMax(pool, (p) => p.productionScore);
  }

  final tiedPlayers = _uniquePlayerMaps(
    pool.map((p) => Map<String, dynamic>.from(p.player)).toList(),
  );
  final leader = pool.first;

  return FeaturedPlayerAward(
    player: Map<String, dynamic>.from(leader.player),
    integralImpactScore: _expose(leader.integralImpactScore),
    productionScore: _expose(leader.productionScore),
    offensiveScore: _expose(leader.offensiveScore),
    defensiveScore: _expose(leader.defensiveScore),
    versatilityBonus: leader.versatilityBonus,
    twoWayBonus: _expose(leader.twoWayBonus),
    contextualBonus: _expose(leader.contextualBonus),
    activeFamilies: leader.activeFamilies,
    tiedPlayers: pool.length > 1 ? tiedPlayers : const [],
  );
}

LeaderAward? _selectLeader(
  Map<String, _PlayerProduction> productions, {
  required String scoreKey,
  required double Function(_PlayerProduction) scoreSelector,
}) {
  final candidates = productions.values
      .where((p) => scoreSelector(p) > 0)
      .toList(growable: false);
  if (candidates.isEmpty) return null;

  final maxScore = candidates
      .map(scoreSelector)
      .reduce((a, b) => a > b ? a : b);

  final tied = candidates
      .where((p) => scoreSelector(p) == maxScore)
      .toList(growable: false);
  if (tied.isEmpty) return null;

  return LeaderAward(
    player: Map<String, dynamic>.from(tied.first.player),
    score: _expose(maxScore),
    scoreKey: scoreKey,
    tiedPlayers: tied.length > 1
        ? _uniquePlayerMaps(
            tied.map((p) => Map<String, dynamic>.from(p.player)).toList(),
          )
        : const [],
  );
}

List<_PlayerProduction> _filterMax(
  List<_PlayerProduction> list,
  double Function(_PlayerProduction) selector,
) {
  final max = list.map(selector).reduce((a, b) => a > b ? a : b);
  return list.where((p) => selector(p) == max).toList(growable: false);
}

_DefensiveKind? _classifyDefensiveAction(Map<String, dynamic> action) {
  final clave = _actionClave(action);
  final pts = _actionPoints(action);
  final name = (action['name'] ?? '').toString().toUpperCase();

  if (_matchesClave(clave, 'sack')) {
    if (pts == 2 || name.contains('SAFETY')) {
      return _DefensiveKind.safety;
    }
    return _DefensiveKind.normalSack;
  }

  if (clave.contains('safety') || name.contains('SAFETY')) {
    return _DefensiveKind.safety;
  }

  if (_matchesClave(clave, 'inter')) {
    if (pts >= 6) return _DefensiveKind.pickSix;
    if (pts == 2) return _DefensiveKind.interceptionReturn2Pts;
    return _DefensiveKind.normalInter;
  }

  return null;
}

bool _shouldSkipForAwards(Map<String, dynamic> action) {
  final name = (action['name'] ?? '').toString().toLowerCase();
  final clave = _actionClave(action);

  if (name.contains('cambio de posesión') ||
      name.contains('cambio de posesion') ||
      clave.contains('possession')) {
    return true;
  }

  if (name.contains('expuls') ||
      name.contains('eject') ||
      clave.contains('expuls') ||
      clave.contains('ejection') ||
      clave.contains('eject')) {
    return true;
  }

  if (name.contains('tiempo fuera') ||
      name.contains('timeout') ||
      clave.contains('timeout') ||
      clave.contains('tiempo_fuera')) {
    return true;
  }

  final nameUpper = name.toUpperCase();
  if (clave.contains('kickoff') ||
      clave.contains('kick_off') ||
      clave == 'system' ||
      clave == 'sistema') {
    if (nameUpper.contains('KICK OFF') ||
        nameUpper.contains('KICKOFF') ||
        nameUpper.contains('INICIO') ||
        nameUpper.contains('FINALIZADO') ||
        nameUpper.contains('FIN DEL')) {
      return true;
    }
  }

  return false;
}

String _actionClave(Map<String, dynamic> action) =>
    (action['clave'] ?? action['type'] ?? '').toString().toLowerCase().trim();

bool _matchesClave(String clave, String key) {
  switch (key) {
    case 'pass':
      return clave == 'pass' || clave.contains('pase');
    case 'catch':
      return clave == 'catch' ||
          clave.contains('recep') ||
          clave.contains('reception');
    case 'run':
      return clave == 'run' || clave.contains('carrera');
    case 'sack':
      return clave == 'sack';
    case 'inter':
      return clave == 'inter' || clave.contains('intercep');
    default:
      return false;
  }
}

Map<String, dynamic>? _playerFromAction(
  Map<String, dynamic> action,
  String key,
) {
  final raw = action[key];
  if (raw is! Map) return null;
  return Map<String, dynamic>.from(raw);
}

Map<String, dynamic> _resolveActionPlayer(
  Map<String, dynamic> raw,
  Map<String, Map<String, dynamic>> rosterIndex,
) {
  final id = _entityId(raw);
  if (id.isNotEmpty && rosterIndex.containsKey(id)) {
    return rosterIndex[id]!;
  }
  return _normalizePlayer(raw);
}

String _entityId(Map<String, dynamic> entity) =>
    (entity['_id'] ?? entity['id'] ?? '').toString().trim();

String _teamIdFromAction(Map<String, dynamic> action) {
  final team = action['team'];
  if (team is Map) {
    return (team['_id'] ?? team['id'] ?? '').toString().trim();
  }
  if (team != null) return team.toString().trim();
  return '';
}

String _homeTeamId(Map<String, dynamic> match) {
  final home = MatchHelpers.asMap(match['home']);
  return (home['_id'] ?? home['id'] ?? '').toString().trim();
}

bool _isHomeTeamAction(
  Map<String, dynamic> action,
  Map<String, dynamic> match, {
  required String homeId,
}) {
  final tId = _teamIdFromAction(action);
  if (tId.isEmpty) return false;

  final visitor = MatchHelpers.asMap(match['visitor']);
  final visitorId = (visitor['_id'] ?? visitor['id'] ?? '').toString().trim();

  if (homeId.isNotEmpty && tId == homeId) return true;
  if (visitorId.isNotEmpty && tId == visitorId) return false;

  final flatHome = (match['homeId'] ??
          match['idHome'] ??
          match['home_id'] ??
          '')
      .toString()
      .trim();
  final flatAway = (match['visitorId'] ??
          match['idVisitor'] ??
          match['visitor_id'] ??
          '')
      .toString()
      .trim();
  if (flatHome.isNotEmpty && tId == flatHome) return true;
  if (flatAway.isNotEmpty && tId == flatAway) return false;

  return false;
}

int _actionPoints(Map<String, dynamic> action) =>
    _asInt(action['points'], 0);

int _asInt(dynamic value, int fallback) {
  if (value == null) return fallback;
  return int.tryParse(value.toString()) ?? fallback;
}

double _expose(double value) {
  if (value.isNaN || value.isInfinite) return 0;
  return (value * 100).round() / 100;
}

Map<String, dynamic> _enrichPlayer(
  Map<String, dynamic> raw,
  Map<String, dynamic> team, {
  required bool isHome,
}) {
  final id = _entityId(raw);
  return {
    ...raw,
    '_id': id,
    'id': id,
    'name': (raw['name'] ?? '').toString(),
    'alias': (raw['alias'] ?? '').toString(),
    'number': raw['number'] ?? '',
    'photo': (raw['photo'] ?? raw['thumb'] ?? '').toString(),
    'thumb': (raw['thumb'] ?? raw['photo'] ?? '').toString(),
    'teamId': (team['_id'] ?? team['id'] ?? '').toString(),
    'teamName': (team['name'] ?? '').toString(),
    'isHome': isHome,
  };
}

Map<String, dynamic> _normalizePlayer(Map<String, dynamic> raw) {
  final id = _entityId(raw);
  return {
    ...raw,
    '_id': id,
    'id': id,
    'name': (raw['name'] ?? '').toString(),
    'alias': (raw['alias'] ?? '').toString(),
    'number': raw['number'] ?? '',
    'photo': (raw['photo'] ?? raw['thumb'] ?? '').toString(),
    'thumb': (raw['thumb'] ?? raw['photo'] ?? '').toString(),
    'teamId': (raw['teamId'] ?? raw['team_id'] ?? '').toString(),
    'teamName': (raw['teamName'] ?? raw['team_name'] ?? '').toString(),
    'isHome': raw['isHome'] == true,
  };
}

Map<String, dynamic> _mergePlayer(
  Map<String, dynamic> base,
  Map<String, dynamic> patch,
) {
  final merged = Map<String, dynamic>.from(base);
  for (final entry in patch.entries) {
    if (entry.value != null && entry.value.toString().trim().isNotEmpty) {
      merged[entry.key] = entry.value;
    }
  }
  return merged;
}
