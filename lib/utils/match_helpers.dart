class MatchHelpers {
  static String matchId(Map<String, dynamic> match) {
    return (match['matchId'] ??
            match['match_id'] ??
            match['_id'] ??
            match['id'] ??
            '')
        .toString()
        .trim();
  }

  /// Estado del juego: `scheduled`, `in_progress` o `finished` (`gameStatus`).
  static String gameStatus(Map<String, dynamic> match) {
    final raw = match['gameStatus'] ?? match['status'];
    return (raw ?? '').toString().toLowerCase().trim();
  }

  static bool isLive(Map<String, dynamic> match) {
    final s = gameStatus(match);
    return s == 'in_progress' || s == 'live';
  }

  static bool isFinished(Map<String, dynamic> match) {
    return gameStatus(match) == 'finished';
  }

  static bool isScheduledStatus(Map<String, dynamic> match) {
    return gameStatus(match) == 'scheduled';
  }

  static DateTime localToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime? matchLocalDay(Map<String, dynamic> match) {
    final raw = (match['date'] ?? match['scheduledDate'] ?? '').toString().trim();
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final local = parsed.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Programado con fecha hoy o futura (no pasada).
  static bool isScheduled(Map<String, dynamic> match) {
    if (isLive(match) || isFinished(match)) return false;
    if (!isScheduledStatus(match)) return false;

    final day = matchLocalDay(match);
    if (day == null) return false;

    return !day.isBefore(localToday());
  }

  /// Alias para itinerario / carrusel.
  static bool isFutureScheduledMatch(Map<String, dynamic> match) =>
      isScheduled(match);

  static DateTime? matchDateTime(Map<String, dynamic> match) {
    final raw =
        (match['date'] ?? match['scheduledDate'] ?? '').toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static bool isMatchDateBefore(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final ad = matchDateTime(a);
    final bd = matchDateTime(b);
    if (ad == null) return false;
    if (bd == null) return true;
    return ad.isBefore(bd);
  }

  static String relatedPlayerId(Map<String, dynamic> player) {
    return (player['playerId'] ?? player['id'] ?? '').toString().trim();
  }

  static Iterable<Map<String, dynamic>> relatedPlayersOnMatch(
    Map<String, dynamic> match,
  ) sync* {
    final related = match['relatedPlayers'] as List<dynamic>? ?? [];
    for (final raw in related) {
      if (raw is Map) yield Map<String, dynamic>.from(raw);
    }
    if (related.isEmpty && match['primaryPlayer'] is Map) {
      yield Map<String, dynamic>.from(match['primaryPlayer'] as Map);
    }
  }

  /// Itinerario: partido más inmediato por jugador/seguido (máx. [limit]).
  static List<Map<String, dynamic>> selectCarouselMatches(
    List<Map<String, dynamic>> matches, {
    int limit = 5,
  }) {
    final candidates = matches
        .where((m) => isLive(m) || isFutureScheduledMatch(m))
        .toList();

    final nearestByPlayer = <String, Map<String, dynamic>>{};

    for (final match in candidates) {
      for (final player in relatedPlayersOnMatch(match)) {
        final playerId = relatedPlayerId(player);
        if (playerId.isEmpty) continue;

        final current = nearestByPlayer[playerId];
        if (current == null) {
          nearestByPlayer[playerId] = match;
          continue;
        }

        final matchLive = isLive(match);
        final currentLive = isLive(current);
        if (matchLive && !currentLive) {
          nearestByPlayer[playerId] = match;
          continue;
        }
        if (!matchLive && currentLive) continue;

        if (isMatchDateBefore(match, current)) {
          nearestByPlayer[playerId] = match;
        }
      }
    }

    final unique = <String, Map<String, dynamic>>{};
    for (final match in nearestByPlayer.values) {
      final id = matchId(match);
      if (id.isEmpty) continue;
      unique[id] = Map<String, dynamic>.from(match);
    }

    final result = unique.values.toList();
    result.sort(compareLiveThenDate);
    return result.take(limit).toList(growable: false);
  }

  /// Programado sin fecha válida.
  static bool isUnscheduled(Map<String, dynamic> match) {
    if (isLive(match) || isFinished(match)) return false;
    if (!isScheduledStatus(match)) return false;
    return matchLocalDay(match) == null;
  }

  static String statusDisplayLabel(
    Map<String, dynamic> match, {
    bool plural = false,
  }) {
    if (isLive(match) || isOvertime(match)) return 'EN VIVO';
    if (isFinished(match)) {
      return plural ? 'FINALIZADOS' : 'FINALIZADO';
    }
    if (isScheduledStatus(match)) {
      return plural ? 'PROGRAMADOS' : 'PROGRAMADO';
    }
    return '';
  }

  static bool isOvertime(Map<String, dynamic> match) {
    return gameStatus(match) == 'overtime';
  }

  static String? categoryName(Map<String, dynamic> match) {
    final category = asMap(match['category']);
    final fromCategory = (category['name'] ?? '').toString().trim();
    if (fromCategory.isNotEmpty) return fromCategory;

    final home = asMap(match['home']);
    final visitor = asMap(match['visitor']);
    final fromHome = (asMap(home['category'])['name'] ?? '').toString().trim();
    if (fromHome.isNotEmpty) return fromHome;
    final fromVisitor =
        (asMap(visitor['category'])['name'] ?? '').toString().trim();
    if (fromVisitor.isNotEmpty) return fromVisitor;

    final tournament = asMap(match['tournament']);
    final fromTournament =
        (asMap(tournament['category'])['name'] ?? '').toString().trim();
    if (fromTournament.isNotEmpty) return fromTournament;

    return null;
  }

  static String journeyOf(Map<String, dynamic> match) {
    return (match['journey'] ?? match['jornada'] ?? '').toString().trim();
  }

  static String fieldRaw(Map<String, dynamic> match) {
    final field = match['field'];
    if (field is Map) {
      return (field['name'] ?? '').toString().trim();
    }
    final fromField = field?.toString().trim() ?? '';
    if (fromField.isNotEmpty) return fromField;

    final campo = match['campo'];
    if (campo is Map) {
      return (campo['name'] ?? '').toString().trim();
    }
    return campo?.toString().trim() ?? '';
  }

  static String fieldLabel(
    Map<String, dynamic> match, {
    String emptyLabel = 'CAMPO —',
  }) {
    final raw = fieldRaw(match);
    if (raw.isEmpty) return emptyLabel.toUpperCase();
    if (raw.toUpperCase().startsWith('CAMPO')) return raw.toUpperCase();
    return 'CAMPO $raw'.toUpperCase();
  }

  static String sedeName(
    Map<String, dynamic> match, {
    Map<String, dynamic>? tournament,
    String fallback = 'SEDE TBD',
  }) {
    final sede = match['sede'] ?? tournament?['sede'];
    if (sede is Map) {
      final name = (sede['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name.toUpperCase();
    }
    if (sede != null && sede is! Map) {
      final s = sede.toString().trim();
      if (s.isNotEmpty) return s.toUpperCase();
    }
    return fallback.toUpperCase();
  }

  static dynamic teamPoints(Map<String, dynamic> match, {required bool home}) {
    final team = home ? asMap(match['home']) : asMap(match['visitor']);
    final score = asMap(match['score']);
    final fromTeam = team['points'];
    if (fromTeam != null) return fromTeam;
    return home ? score['home'] : score['visitor'];
  }

  static List<Map<String, dynamic>> mergeRelatedMatchesBlock(
    Map<String, dynamic> matchesBlock,
  ) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];

    void add(dynamic raw) {
      if (raw is! Map) return;
      final map = Map<String, dynamic>.from(raw);
      applyLegacyScores(map);
      final id = matchId(map);
      if (id.isEmpty || seen.contains(id)) return;
      seen.add(id);
      out.add(map);
    }

    add(matchesBlock['next']);
    for (final m in matchesBlock['upcoming'] as List<dynamic>? ?? []) {
      add(m);
    }
    for (final m in matchesBlock['previous'] as List<dynamic>? ?? []) {
      add(m);
    }
    for (final m in matchesBlock['unscheduled'] as List<dynamic>? ?? []) {
      add(m);
    }

    return out;
  }

  /// `user-context-v2`: `dashboard.matches` plano o bloque legacy.
  static List<Map<String, dynamic>> normalizeMatchesFromDashboard(
    dynamic raw,
  ) {
    if (raw is List) {
      return normalizeMatchList(raw);
    }
    if (raw is Map) {
      return mergeRelatedMatchesBlock(Map<String, dynamic>.from(raw));
    }
    return [];
  }

  static List<Map<String, dynamic>> normalizeMatchList(List<dynamic> raw) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      applyLegacyScores(map);
      final id = matchId(map);
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      out.add(map);
    }
    out.sort(compareMatches);
    return out;
  }

  static List<Map<String, dynamic>> playersFromProfiles(
    List<dynamic> profiles,
  ) {
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final raw in profiles) {
      if (raw is! Map) continue;
      final p = Map<String, dynamic>.from(raw);
      final id = (p['playerId'] ?? p['id'] ?? '').toString().trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      out.add({
        'playerId': id,
        'id': id,
        'alias': p['alias'] ?? '',
        'name': p['name'] ?? p['fullName'] ?? '',
        'relation': p['relation'] ?? '',
        'photo': p['photo'] ?? p['thumb'] ?? '',
      });
    }

    return out;
  }

  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static Map<String, dynamic> deepMergeTeam(
    Map<String, dynamic>? existing,
    Map<String, dynamic>? incoming,
  ) {
    final base = Map<String, dynamic>.from(existing ?? {});
    final patch = incoming ?? {};
    for (final entry in patch.entries) {
      if (entry.value is Map && base[entry.key] is Map) {
        base[entry.key] = deepMergeTeam(
          Map<String, dynamic>.from(base[entry.key] as Map),
          Map<String, dynamic>.from(entry.value as Map),
        );
      } else if (entry.value != null) {
        base[entry.key] = entry.value;
      }
    }
    return base;
  }

  static void applyLegacyScores(Map<String, dynamic> match) {
    final home = asMap(match['home']);
    final visitor = asMap(match['visitor']);
    final score = asMap(match['score']);

    if (home['points'] == null && score['home'] != null) {
      home['points'] = score['home'];
    }
    if (visitor['points'] == null && score['visitor'] != null) {
      visitor['points'] = score['visitor'];
    }

    void copyScore(Map<String, dynamic> team, List<String> keys) {
      for (final key in keys) {
        if (match.containsKey(key)) {
          team['points'] = match[key];
          break;
        }
      }
    }

    copyScore(home, ['homePoints', 'scoreHome', 'pointsHome', 'scoreH']);
    copyScore(visitor, ['visitorPoints', 'scoreVisitor', 'pointsVisitor', 'scoreV']);

    match['home'] = home;
    match['visitor'] = visitor;

    final period = match['currentHalf'] ??
        match['half'] ??
        match['periodo'] ??
        match['tiempo'];
    if (period != null) {
      match['currentHalf'] = period;
    }
  }

  static int compareMatches(Map<String, dynamic> a, Map<String, dynamic> b) {
    return compareLiveThenDate(a, b);
  }

  /// En vivo primero; luego por fecha ascendente.
  static int compareLiveThenDate(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aLive = isLive(a);
    final bLive = isLive(b);
    if (aLive != bLive) return aLive ? -1 : 1;

    final ad = matchDateTime(a);
    final bd = matchDateTime(b);
    if (ad != null && bd != null) return ad.compareTo(bd);
    if (ad != null) return -1;
    if (bd != null) return 1;
    return 0;
  }

  static const List<String> _shortMonths = [
    'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
    'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
  ];

  static const List<String> _longMonths = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  static String _shortDatePart(DateTime day) {
    final now = DateTime.now();
    final month = _shortMonths[day.month - 1];
    if (day.year == now.year) {
      return '${day.day} $month';
    }
    return '${day.day} $month ${day.year}';
  }

  static String _longDatePart(DateTime day) {
    final now = DateTime.now();
    final month = _longMonths[day.month - 1];
    if (day.year == now.year) {
      return '${day.day} $month';
    }
    return '${day.day} $month ${day.year}';
  }

  /// Encabezado de grupo en el listado: `HOY · 6 AGO`, etc.
  static String formatListSectionDate(DateTime day) {
    final today = localToday();
    final tomorrow = today.add(const Duration(days: 1));
    final datePart = _shortDatePart(day);

    if (day == today) return 'HOY · $datePart';
    if (day == tomorrow) return 'MAÑANA · $datePart';
    if (day.isBefore(today)) return datePart;

    return datePart;
  }

  /// Fecha sobre la card del carrusel: `HOY 4 Agosto`, etc.
  static String formatCarouselMatchDate(DateTime day) {
    final today = localToday();
    final tomorrow = today.add(const Duration(days: 1));
    final datePart = _longDatePart(day);

    if (day == today) return 'HOY $datePart';
    if (day == tomorrow) return 'MAÑANA $datePart';
    return datePart;
  }

  static String? relatedPlayersLabel(Map<String, dynamic> match) {
    final labels = <String>[];
    final related = match['relatedPlayers'] as List<dynamic>? ?? [];
    for (final raw in related) {
      if (raw is! Map) continue;
      final alias = (raw['alias'] ?? '').toString().trim();
      final name = (raw['name'] ?? '').toString().trim();
      final label = alias.isNotEmpty
          ? alias
          : (name.isNotEmpty ? name.split(RegExp(r'\s+')).first : '');
      if (label.isNotEmpty) labels.add(label);
    }
    if (labels.isEmpty) {
      final primary = match['primaryPlayer'];
      if (primary is Map) {
        final alias = (primary['alias'] ?? '').toString().trim();
        final name = (primary['name'] ?? '').toString().trim();
        final label = alias.isNotEmpty
            ? alias
            : (name.isNotEmpty ? name.split(RegExp(r'\s+')).first : '');
        if (label.isNotEmpty) labels.add(label);
      }
    }
    if (labels.isEmpty) return null;
    if (labels.length == 1) return labels.first.toUpperCase();
    return '${labels.first.toUpperCase()} +${labels.length - 1}';
  }

  /// Datos de avatar por jugador relacionado (sin duplicados).
  static List<Map<String, dynamic>> relatedPlayersAvatarEntries(
    Map<String, dynamic> match,
  ) {
    final entries = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addPlayer(Map<String, dynamic> raw) {
      final id = relatedPlayerId(raw);
      if (id.isEmpty || seen.contains(id)) return;
      seen.add(id);

      final photo = (raw['thumb'] ?? raw['photo'] ?? raw['avatar'] ?? '')
          .toString()
          .trim();

      entries.add({
        'id': id,
        'name': (raw['name'] ?? '').toString(),
        'alias': (raw['alias'] ?? '').toString(),
        'photo': photo,
        'relation': (raw['relation'] ?? '').toString(),
      });
    }

    for (final player in relatedPlayersOnMatch(match)) {
      addPlayer(player);
    }

    return entries;
  }

  static String? playerSideForMatch(Map<String, dynamic> match) {
    Map<String, dynamic>? player;
    final related = match['relatedPlayers'] as List<dynamic>?;
    if (related != null && related.isNotEmpty && related.first is Map) {
      player = Map<String, dynamic>.from(related.first as Map);
    } else if (match['primaryPlayer'] is Map) {
      player = Map<String, dynamic>.from(match['primaryPlayer'] as Map);
    }
    if (player == null) return null;

    final side = (player['side'] ?? '').toString().toLowerCase();
    final homeAway = (player['homeAway'] ?? '').toString().toLowerCase();
    final homeAwayLabel =
        (player['homeAwayLabel'] ?? '').toString().toLowerCase();

    if (player['isHome'] == true ||
        side == 'home' ||
        homeAway == 'local' ||
        homeAwayLabel == 'local') {
      return 'home';
    }
    if (player['isVisitor'] == true ||
        side == 'visitor' ||
        homeAway == 'visita' ||
        homeAwayLabel == 'visita') {
      return 'visitor';
    }
    return null;
  }

  static ({String name, String? id}) academyInfoForMatch(
    Map<String, dynamic> match,
    String? side,
  ) {
    final home = asMap(match['home']);
    final visitor = asMap(match['visitor']);
    final team = side == 'home'
        ? home
        : side == 'visitor'
        ? visitor
        : home;
    final name = (team['name'] ?? '').toString();
    final academy = team['academy'];
    String? id;
    if (academy is Map) {
      id = (academy['id'] ?? academy['_id'])?.toString();
    } else {
      id = team['academyId']?.toString();
    }
    return (name: name, id: id);
  }

  /// Resuelve URL de medios del CDN del proyecto.
  static String resolveMediaUrl(String raw) {
    final url = raw.trim();
    if (url.isEmpty || url == 'null' || url == 'None') return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return 'https://cuerposallimite.net$url';
    return 'https://cuerposallimite.net/nlff/resources/images/$url';
  }

  /// Logo del equipo (thumb, logo, academia).
  static String teamLogoUrl(Map<String, dynamic> team) {
    for (final key in ['thumb', 'logo', 'img', 'image']) {
      final val = (team[key] ?? '').toString().trim();
      if (val.isNotEmpty && val != 'null' && val != 'None' && val.length > 5) {
        return resolveMediaUrl(val);
      }
    }
    final academy = team['academy'];
    if (academy is Map) {
      for (final key in ['thumb', 'logo']) {
        final val = (academy[key] ?? '').toString().trim();
        if (val.isNotEmpty && val != 'null' && val != 'None' && val.length > 5) {
          return resolveMediaUrl(val);
        }
      }
    }
    return '';
  }

  /// Nombre corto o abreviatura del equipo para UI compacta.
  static String teamDisplayName(
    Map<String, dynamic> team, {
    String fallback = '',
  }) {
    final short = (team['shortName'] ?? '').toString().trim();
    if (short.isNotEmpty) return short.toUpperCase();
    final fromPlayer = fallback.trim();
    if (fromPlayer.isNotEmpty && team.isEmpty) return fromPlayer.toUpperCase();
    final raw = (team['name'] ?? fromPlayer).toString().trim();
    if (raw.isEmpty) return fallback.toUpperCase();
    final parts = raw.split(RegExp(r'\s+'));
    if (parts.length > 2) return parts.last.toUpperCase();
    return raw.toUpperCase();
  }

  static String playerDisplayName(Map<String, dynamic> player) {
    final name = (player['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    return (player['alias'] ?? '').toString().trim();
  }

  static String playerInitials(Map<String, dynamic> player) {
    final label = playerDisplayName(player);
    if (label.isEmpty) {
      final alias = (player['alias'] ?? '').toString().trim();
      if (alias.isNotEmpty) return alias[0].toUpperCase();
      return '?';
    }
    final parts =
        label.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  /// Dorsal formateado o null si no es válido para mostrar.
  static String? formatPlayerNumber(dynamic number) {
    final raw = (number ?? '').toString().trim();
    if (raw.isEmpty || raw == 'null' || raw == '-') return null;
    return raw;
  }

  static String playerPhotoUrl(Map<String, dynamic> player) {
    final raw = (player['photo'] ?? player['thumb'] ?? '').toString().trim();
    return resolveMediaUrl(raw);
  }

  /// Foto principal para spotlight editorial: publicPhoto > photo > thumb.
  static String playerSpotlightPhotoUrl(Map<String, dynamic> player) {
    final public = (player['publicPhoto'] ?? '').toString().trim();
    if (public.isNotEmpty) return resolveMediaUrl(public);
    return playerPhotoUrl(player);
  }

  /// Posiciones del jugador desde `positions` (array de strings).
  static List<String> playerPositions(Map<String, dynamic> player) {
    final raw = player['positions'];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final legacy = (player['position'] ?? '').toString().trim();
    if (legacy.isNotEmpty &&
        legacy != 'N/A' &&
        legacy != 'JUGADOR' &&
        legacy != 'null') {
      return [legacy];
    }
    return [];
  }

  /// Texto legible de posiciones (ej. "QB · WR").
  static String playerPositionsLabel(
    Map<String, dynamic> player, {
    String fallback = 'JUGADOR',
    String separator = ' · ',
  }) {
    final positions = playerPositions(player);
    if (positions.isEmpty) return fallback;
    return positions.join(separator);
  }

  static String rosterPlayerId(Map<String, dynamic> player) {
    final id = (player['_id'] ?? player['id'] ?? player['playerId'] ?? '')
        .toString()
        .trim();
    return id;
  }

  /// Índice de jugadores en roster por id.
  static Map<String, Map<String, dynamic>> rosterIndex({
    required List<Map<String, dynamic>> homeRoster,
    required List<Map<String, dynamic>> visitorRoster,
  }) {
    final index = <String, Map<String, dynamic>>{};

    void add(List<Map<String, dynamic>> roster, bool isHome) {
      for (final raw in roster) {
        final id = rosterPlayerId(raw);
        if (id.isEmpty) continue;
        final entry = Map<String, dynamic>.from(raw);
        entry['isHome'] = isHome;
        index[id] = entry;
      }
    }

    add(homeRoster, true);
    add(visitorRoster, false);
    return index;
  }

  /// Gestión/seguidos presentes en el roster del partido.
  static List<Map<String, dynamic>> specialMentionPlayersInMatch({
    required Map<String, dynamic> match,
    required Map<String, Map<String, dynamic>> rosterByPlayerId,
    List<Map<String, dynamic>> userProfiles = const [],
  }) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];

    void tryAdd(Map<String, dynamic> meta, {String? defaultRelation}) {
      final id = relatedPlayerId(meta);
      if (id.isEmpty || seen.contains(id)) return;
      final roster = rosterByPlayerId[id];
      if (roster == null) return;

      seen.add(id);
      final relation = (meta['relation'] ?? defaultRelation ?? '').toString();
      out.add({
        ...Map<String, dynamic>.from(meta),
        'playerId': id,
        'id': id,
        '_id': id,
        'name': (meta['name'] ?? roster['name'] ?? '').toString(),
        'alias': (meta['alias'] ?? roster['alias'] ?? '').toString(),
        'photo': (meta['photo'] ??
                meta['thumb'] ??
                roster['photo'] ??
                roster['thumb'] ??
                '')
            .toString(),
        'publicPhoto': (meta['publicPhoto'] ?? roster['publicPhoto'] ?? '')
            .toString(),
        'number': meta['number'] ?? roster['number'] ?? '',
        'relation': relation,
        'isHome': roster['isHome'] == true,
        'positions': meta['positions'] ?? roster['positions'],
      });
    }

    for (final player in relatedPlayersOnMatch(match)) {
      tryAdd(player);
    }

    for (final profile in userProfiles) {
      final isFollowed = profile['relation']?.toString() == 'followed';
      tryAdd(
        profile,
        defaultRelation: isFollowed ? 'followed' : 'managed',
      );
    }

    return out;
  }

  static bool playerHasGameStats(Map<String, dynamic>? stats) {
    if (stats == null) return false;
    for (final key in ['pts', 'pass', 'catch', 'run', 'sack', 'int']) {
      if ((int.tryParse(stats[key]?.toString() ?? '0') ?? 0) > 0) {
        return true;
      }
    }
    return false;
  }

  static String playerGameStatsSummary(Map<String, dynamic> stats) {
    final parts = <String>[];
    const labels = {
      'pts': 'PTS',
      'pass': 'PASS',
      'catch': 'REC',
      'run': 'RUN',
      'sack': 'SACK',
      'int': 'INT',
    };
    for (final entry in labels.entries) {
      final value = int.tryParse(stats[entry.key]?.toString() ?? '0') ?? 0;
      if (value > 0) parts.add('${entry.value} $value');
    }
    return parts.join(' · ');
  }
}
