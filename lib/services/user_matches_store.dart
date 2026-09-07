import 'package:flutter/foundation.dart';

import '../utils/match_helpers.dart';

/// Caché en memoria de partidos del dashboard usuario (próximos + en vivo).
class UserMatchesStore extends ChangeNotifier {
  UserMatchesStore._();
  static final UserMatchesStore instance = UserMatchesStore._();

  List<Map<String, dynamic>> _upcomingMatches = [];
  List<Map<String, dynamic>> _lastMatches = [];

  List<Map<String, dynamic>> get upcomingMatches =>
      List.unmodifiable(_upcomingMatches);

  List<Map<String, dynamic>> get lastMatches => List.unmodifiable(_lastMatches);

  /// Todos los partidos del dashboard (próximos/en vivo + finalizados), sin duplicados.
  List<Map<String, dynamic>> get allMatches {
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};

    void add(Map<String, dynamic> match) {
      final id = MatchHelpers.matchId(match);
      if (id.isEmpty || seen.contains(id)) return;
      seen.add(id);
      out.add(Map<String, dynamic>.from(match));
    }

    for (final m in _upcomingMatches) {
      add(m);
    }
    for (final m in _lastMatches) {
      add(m);
    }

    return List.unmodifiable(out);
  }

  void saveFromDashboard(Map<String, dynamic>? dashboard) {
    final preservedLive = <String, Map<String, dynamic>>{};
    for (final m in [..._upcomingMatches, ..._lastMatches]) {
      if (MatchHelpers.isLive(m)) {
        final id = MatchHelpers.matchId(m);
        if (id.isNotEmpty) preservedLive[id] = Map<String, dynamic>.from(m);
      }
    }

    if (dashboard == null) {
      _upcomingMatches = [];
      _lastMatches = [];
      notifyListeners();
      return;
    }

    final allMatches = MatchHelpers.normalizeMatchesFromDashboard(
      dashboard['matches'],
    );

    _upcomingMatches = allMatches
        .where((m) => MatchHelpers.isLive(m) || MatchHelpers.isScheduled(m))
        .toList();
    _lastMatches = allMatches
        .where((m) => MatchHelpers.isFinished(m))
        .toList();

    for (final live in preservedLive.values) {
      final id = MatchHelpers.matchId(live);
      if (!_containsId(_upcomingMatches, id) && !_containsId(_lastMatches, id)) {
        _lastMatches.insert(0, live);
      }
    }

    notifyListeners();
  }

  List<Map<String, dynamic>> getCarouselMatches() {
    final pool = List<Map<String, dynamic>>.from(_upcomingMatches);

    for (final match in _lastMatches) {
      if (!MatchHelpers.isLive(match)) continue;
      final id = MatchHelpers.matchId(match);
      if (id.isEmpty || _containsId(pool, id)) continue;
      pool.add(Map<String, dynamic>.from(match));
    }

    return MatchHelpers.selectCarouselMatches(pool);
  }

  /// Retorna true si hubo cambios aplicables.
  bool updateMatch(dynamic payload) {
    if (payload == null) return false;

    final map = payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
    Map<String, dynamic> matchData;
    if (map['match'] is Map) {
      matchData = Map<String, dynamic>.from(map['match'] as Map);
    } else if (map['_id'] != null || map['id'] != null) {
      matchData = map;
    } else {
      return false;
    }

    if (map['action'] is Map) {
      matchData['lastAction'] = Map<String, dynamic>.from(map['action'] as Map);
    }

    MatchHelpers.applyLegacyScores(matchData);

    final matchId = MatchHelpers.matchId(matchData);
    if (matchId.isEmpty) return false;

    var updated = false;
    updated = _mergeInList(_upcomingMatches, matchId, matchData) || updated;
    updated = _mergeInList(_lastMatches, matchId, matchData) || updated;

    if (!updated) {
      if (MatchHelpers.isLive(matchData) || MatchHelpers.isScheduled(matchData)) {
        _upcomingMatches.add(Map<String, dynamic>.from(matchData));
        updated = true;
      } else if (MatchHelpers.isFinished(matchData)) {
        _lastMatches.insert(0, Map<String, dynamic>.from(matchData));
        updated = true;
      }
    } else {
      _reclassifyMatch(matchId);
    }

    if (updated) {
      _upcomingMatches.sort(MatchHelpers.compareMatches);
      notifyListeners();
    }
    return updated;
  }

  void _reclassifyMatch(String matchId) {
    Map<String, dynamic>? merged;
    int upIdx = _upcomingMatches.indexWhere((m) => MatchHelpers.matchId(m) == matchId);
    int lastIdx = _lastMatches.indexWhere((m) => MatchHelpers.matchId(m) == matchId);

    if (upIdx >= 0) {
      merged = Map<String, dynamic>.from(_upcomingMatches[upIdx]);
    } else if (lastIdx >= 0) {
      merged = Map<String, dynamic>.from(_lastMatches[lastIdx]);
    }
    if (merged == null) return;

    _upcomingMatches.removeWhere((m) => MatchHelpers.matchId(m) == matchId);
    _lastMatches.removeWhere((m) => MatchHelpers.matchId(m) == matchId);

    if (MatchHelpers.isLive(merged) || MatchHelpers.isScheduled(merged)) {
      _upcomingMatches.add(merged);
      _upcomingMatches.sort(MatchHelpers.compareMatches);
    } else if (MatchHelpers.isFinished(merged)) {
      _lastMatches.insert(0, merged);
    }
  }

  bool _mergeInList(
    List<Map<String, dynamic>> list,
    String matchId,
    Map<String, dynamic> patch,
  ) {
    final index = list.indexWhere((m) => MatchHelpers.matchId(m) == matchId);
    if (index < 0) return false;

    final current = Map<String, dynamic>.from(list[index]);
    final merged = Map<String, dynamic>.from(current);

    for (final entry in patch.entries) {
      if (entry.key == 'home' || entry.key == 'visitor') {
        merged[entry.key] = MatchHelpers.deepMergeTeam(
          MatchHelpers.asMap(current[entry.key]),
          MatchHelpers.asMap(entry.value),
        );
      } else {
        merged[entry.key] = entry.value;
      }
    }

    if (patch['action'] is Map && merged['lastAction'] == null) {
      merged['lastAction'] = patch['action'];
    }

    MatchHelpers.applyLegacyScores(merged);
    list[index] = merged;
    return true;
  }

  bool _containsId(List<Map<String, dynamic>> list, String id) {
    return list.any((m) => MatchHelpers.matchId(m) == id);
  }
}
