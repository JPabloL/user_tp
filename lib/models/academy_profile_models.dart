import '../utils/json_parse_helpers.dart';

/// Contexto completo del perfil público de academia.
class AcademyProfileContext {
  const AcademyProfileContext({
    required this.academy,
    required this.summary,
    required this.record,
    required this.playoffs,
    required this.honors,
    required this.categories,
    required this.categoryStats,
    required this.yearStats,
    required this.leagues,
    required this.tournaments,
    required this.matches,
    required this.meta,
    this.snapshotAvailable = false,
    this.liveSummary = AcademyLiveSummary.empty,
  });

  final AcademyProfile academy;
  final AcademySummary summary;
  final AcademyRecordBundle record;
  final AcademyPlayoffsParticipation playoffs;
  final AcademyHonors honors;
  final List<AcademyCategory> categories;
  final List<AcademyCategoryStats> categoryStats;
  final List<AcademyYearStats> yearStats;
  final List<AcademyLeague> leagues;
  final AcademyTournaments tournaments;
  final AcademyMatches matches;
  final AcademyProfileMeta meta;
  final bool snapshotAvailable;
  final AcademyLiveSummary liveSummary;

  factory AcademyProfileContext.fromJson(Map<String, dynamic> json) {
    if (_isAcademyProfileResponse(json)) {
      return AcademyProfileResponse.fromJson(json).toContext();
    }

    return AcademyProfileContext(
      academy: AcademyProfile.fromJson(JsonParse.map(json['academy'])),
      summary: AcademySummary.fromJson(JsonParse.map(json['summary'])),
      record: AcademyRecordBundle.fromJson(JsonParse.map(json['record'])),
      playoffs: json['playoffs'] is Map
          ? AcademyPlayoffsParticipation.fromJson(
              Map<String, dynamic>.from(json['playoffs'] as Map),
            )
          : AcademyPlayoffsParticipation.empty,
      honors: AcademyHonors.fromJson(JsonParse.map(json['honors'])),
      categories: JsonParse.list(
        json['categories'],
        AcademyCategory.fromJson,
      ),
      categoryStats: JsonParse.list(
        json['categoryStats'],
        AcademyCategoryStats.fromJson,
      ),
      yearStats: JsonParse.list(
        json['yearStats'],
        AcademyYearStats.fromJson,
      ),
      leagues: JsonParse.list(
        json['leagues'],
        AcademyLeague.fromJson,
      ),
      tournaments: AcademyTournaments.fromJson(
        JsonParse.map(json['tournaments']),
      ),
      matches: AcademyMatches.fromJson(JsonParse.map(json['matches'])),
      meta: AcademyProfileMeta.fromJson(JsonParse.map(json['meta'])),
    );
  }

  static bool _isAcademyProfileResponse(Map<String, dynamic> json) {
    return json.containsKey('snapshot') ||
        json.containsKey('snapshotAvailable') ||
        json.containsKey('liveSummary');
  }
}

class AcademyProfile {
  const AcademyProfile({
    required this.id,
    required this.name,
    required this.logo,
    required this.description,
    this.coverPhoto,
    required this.socialLinks,
  });

  final String id;
  final String name;
  final String logo;
  final String description;
  final String? coverPhoto;
  final List<AcademySocialLink> socialLinks;

  factory AcademyProfile.fromJson(Map<String, dynamic> json) {
    return AcademyProfile(
      id: JsonParse.string(json['id'] ?? json['_id']),
      name: JsonParse.string(json['name'], fallback: 'Academia'),
      logo: JsonParse.string(json['logo'] ?? json['logo_url']),
      description: JsonParse.string(json['description']),
      coverPhoto: JsonParse.stringOrNull(
        json['coverPhoto'] ?? json['cover_photo'] ?? json['cover'],
      ),
      socialLinks: _parseSocialLinks(json['rs']),
    );
  }

  static List<AcademySocialLink> _parseSocialLinks(dynamic raw) {
    if (raw is! List) return <AcademySocialLink>[];
    final links = <AcademySocialLink>[];
    for (final item in raw) {
      if (item is Map) {
        final link = AcademySocialLink.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (link.isValid) links.add(link);
      } else {
        final url = JsonParse.stringOrNull(item);
        if (url != null) {
          final link = AcademySocialLink(type: 'link', url: url);
          if (link.isValid) links.add(link);
        }
      }
    }
    return links;
  }
}

class AcademySocialLink {
  const AcademySocialLink({
    required this.type,
    required this.url,
    this.label,
  });

  final String type;
  final String url;
  final String? label;

  bool get isValid {
    final value = url.trim();
    if (value.isEmpty) return false;
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('//') ||
        value.contains('.');
  }

  factory AcademySocialLink.fromJson(Map<String, dynamic> json) {
    final rawUrl = JsonParse.string(
      json['url'] ??
          json['link'] ??
          json['href'] ??
          json['value'] ??
          json['rs'],
    );
    return AcademySocialLink(
      type: JsonParse.string(
        json['type'] ?? json['platform'] ?? json['network'] ?? json['name'],
        fallback: 'link',
      ),
      url: rawUrl,
      label: JsonParse.stringOrNull(json['label'] ?? json['title']),
    );
  }
}

class AcademySummary {
  const AcademySummary({
    this.registeredSince,
    this.firstParticipationDate,
    this.standings,
    required this.championships,
    required this.tournaments,
    required this.runnerUps,
    required this.finals,
  });

  final DateTime? registeredSince;
  final DateTime? firstParticipationDate;
  final AcademyStandingsAggregate? standings;
  final int championships;
  final int tournaments;
  final int runnerUps;
  final int finals;

  factory AcademySummary.fromJson(Map<String, dynamic> json) {
    return AcademySummary(
      registeredSince: JsonParse.dateTime(
        json['registeredSince'] ?? json['registered_since'],
      ),
      firstParticipationDate: JsonParse.dateTime(
        json['firstParticipationDate'] ?? json['first_participation_date'],
      ),
      standings: json['standings'] is Map
          ? AcademyStandingsAggregate.fromJson(
              Map<String, dynamic>.from(json['standings'] as Map),
            )
          : null,
      championships: JsonParse.intValue(
        json['championships'] ?? json['titles'],
      ),
      tournaments: JsonParse.intValue(json['tournaments']),
      runnerUps: JsonParse.intValue(
        json['runnerUps'] ?? json['runner_ups'] ?? json['subcampeonatos'],
      ),
      finals: JsonParse.intValue(json['finals'] ?? json['finales']),
    );
  }

  String? registeredSinceYearLabel() {
    if (registeredSince == null) return null;
    return registeredSince!.year.toString();
  }

  static const AcademySummary empty = AcademySummary(
    championships: 0,
    tournaments: 0,
    runnerUps: 0,
    finals: 0,
  );
}

class AcademyStandingsAggregate {
  const AcademyStandingsAggregate({
    required this.totalTournaments,
    required this.totalMatches,
    required this.totalWins,
    required this.totalLosses,
    required this.totalTies,
  });

  final int totalTournaments;
  final int totalMatches;
  final int totalWins;
  final int totalLosses;
  final int totalTies;

  factory AcademyStandingsAggregate.fromJson(Map<String, dynamic> json) {
    return AcademyStandingsAggregate(
      totalTournaments: JsonParse.intValue(
        json['totalTournaments'] ?? json['tournaments'],
      ),
      totalMatches: JsonParse.intValue(
        json['totalMatches'] ?? json['matches'],
      ),
      totalWins: JsonParse.intValue(json['totalWins'] ?? json['wins']),
      totalLosses: JsonParse.intValue(json['totalLosses'] ?? json['losses']),
      totalTies: JsonParse.intValue(json['totalTies'] ?? json['ties']),
    );
  }
}

/// Record deportivo reutilizable en múltiples secciones.
class AcademyRecord {
  const AcademyRecord({
    required this.played,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.pointDiff,
    required this.winPct,
    required this.winPctPercent,
    required this.shutoutsFor,
    required this.shutoutsAgainst,
    required this.internalMatches,
    required this.registeredMatches,
  });

  final int played;
  final int wins;
  final int losses;
  final int ties;
  final int pointsFor;
  final int pointsAgainst;
  final int pointDiff;
  final double winPct;
  final double winPctPercent;
  final int shutoutsFor;
  final int shutoutsAgainst;
  final int internalMatches;
  final int registeredMatches;

  factory AcademyRecord.fromJson(Map<String, dynamic> json) {
    return AcademyRecord(
      played: JsonParse.intValue(json['played']),
      wins: JsonParse.intValue(json['wins']),
      losses: JsonParse.intValue(json['losses']),
      ties: JsonParse.intValue(json['ties']),
      pointsFor: JsonParse.intValue(json['pointsFor'] ?? json['points_for']),
      pointsAgainst:
          JsonParse.intValue(json['pointsAgainst'] ?? json['points_against']),
      pointDiff: JsonParse.intValue(json['pointDiff'] ?? json['point_diff']),
      winPct: JsonParse.doubleValue(json['winPct'] ?? json['win_pct']),
      winPctPercent: JsonParse.doubleValue(
        json['winPctPercent'] ?? json['win_pct_percent'],
      ),
      shutoutsFor:
          JsonParse.intValue(json['shutoutsFor'] ?? json['shutouts_for']),
      shutoutsAgainst:
          JsonParse.intValue(json['shutoutsAgainst'] ?? json['shutouts_against']),
      internalMatches:
          JsonParse.intValue(json['internalMatches'] ?? json['internal_matches']),
      registeredMatches: JsonParse.intValue(
        json['registeredMatches'] ?? json['registered_matches'],
      ),
    );
  }

  static const AcademyRecord empty = AcademyRecord(
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
  );
}

/// Participación histórica en playoffs (raíz del contexto de perfil).
class AcademyPlayoffsParticipation {
  const AcademyPlayoffsParticipation({
    required this.appearances,
    required this.teamParticipations,
    required this.didNotReachPlayoffs,
    required this.qualificationRate,
    required this.qualificationRatePercent,
    required this.semifinalAppearances,
    required this.semifinalWins,
    required this.finalAppearances,
    required this.finalWins,
    required this.played,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.championships,
    required this.runnerUps,
    required this.internalMatches,
  });

  final int appearances;
  final int teamParticipations;
  final int didNotReachPlayoffs;
  final double qualificationRate;
  final double qualificationRatePercent;
  final int semifinalAppearances;
  final int semifinalWins;
  final int finalAppearances;
  final int finalWins;
  final int played;
  final int wins;
  final int losses;
  final int ties;
  final int championships;
  final int runnerUps;
  final int internalMatches;

  bool hasActivity() {
    return appearances > 0 ||
        teamParticipations > 0 ||
        didNotReachPlayoffs > 0 ||
        qualificationRatePercent > 0 ||
        semifinalAppearances > 0 ||
        finalAppearances > 0 ||
        played > 0 ||
        wins > 0 ||
        losses > 0 ||
        championships > 0 ||
        runnerUps > 0 ||
        internalMatches > 0;
  }

  factory AcademyPlayoffsParticipation.fromJson(Map<String, dynamic> json) {
    return AcademyPlayoffsParticipation(
      appearances: JsonParse.intValue(json['appearances']),
      teamParticipations: JsonParse.intValue(
        json['teamParticipations'] ?? json['team_participations'],
      ),
      didNotReachPlayoffs: JsonParse.intValue(
        json['didNotReachPlayoffs'] ?? json['did_not_reach_playoffs'],
      ),
      qualificationRate: JsonParse.doubleValue(
        json['qualificationRate'] ?? json['qualification_rate'],
      ),
      qualificationRatePercent: JsonParse.doubleValue(
        json['qualificationRatePercent'] ?? json['qualification_rate_percent'],
      ),
      semifinalAppearances: JsonParse.intValue(
        json['semifinalAppearances'] ?? json['semifinal_appearances'],
      ),
      semifinalWins: JsonParse.intValue(
        json['semifinalWins'] ?? json['semifinal_wins'],
      ),
      finalAppearances: JsonParse.intValue(
        json['finalAppearances'] ?? json['final_appearances'],
      ),
      finalWins: JsonParse.intValue(json['finalWins'] ?? json['final_wins']),
      played: JsonParse.intValue(json['played']),
      wins: JsonParse.intValue(json['wins']),
      losses: JsonParse.intValue(json['losses']),
      ties: JsonParse.intValue(json['ties']),
      championships: JsonParse.intValue(json['championships']),
      runnerUps: JsonParse.intValue(json['runnerUps'] ?? json['runner_ups']),
      internalMatches: JsonParse.intValue(
        json['internalMatches'] ?? json['internal_matches'],
      ),
    );
  }

  static const AcademyPlayoffsParticipation empty = AcademyPlayoffsParticipation(
    appearances: 0,
    teamParticipations: 0,
    didNotReachPlayoffs: 0,
    qualificationRate: 0,
    qualificationRatePercent: 0,
    semifinalAppearances: 0,
    semifinalWins: 0,
    finalAppearances: 0,
    finalWins: 0,
    played: 0,
    wins: 0,
    losses: 0,
    ties: 0,
    championships: 0,
    runnerUps: 0,
    internalMatches: 0,
  );
}

class AcademyRecordBundle {
  const AcademyRecordBundle({
    required this.overall,
    required this.regular,
    required this.playoffs,
    required this.regularSeasonFromStandings,
  });

  final AcademyRecord overall;
  final AcademyRecord regular;
  final AcademyRecord playoffs;
  final AcademyRegularSeasonFromStandings regularSeasonFromStandings;

  factory AcademyRecordBundle.fromJson(Map<String, dynamic> json) {
    return AcademyRecordBundle(
      overall: json['overall'] is Map
          ? AcademyRecord.fromJson(
              Map<String, dynamic>.from(json['overall'] as Map),
            )
          : AcademyRecord.empty,
      regular: json['regular'] is Map
          ? AcademyRecord.fromJson(
              Map<String, dynamic>.from(json['regular'] as Map),
            )
          : AcademyRecord.empty,
      playoffs: json['playoffs'] is Map
          ? AcademyRecord.fromJson(
              Map<String, dynamic>.from(json['playoffs'] as Map),
            )
          : AcademyRecord.empty,
      regularSeasonFromStandings: json['regularSeasonFromStandings'] is Map
          ? AcademyRegularSeasonFromStandings.fromJson(
              Map<String, dynamic>.from(
                json['regularSeasonFromStandings'] as Map,
              ),
            )
          : AcademyRegularSeasonFromStandings.empty,
    );
  }

  static const AcademyRecordBundle empty = AcademyRecordBundle(
    overall: AcademyRecord.empty,
    regular: AcademyRecord.empty,
    playoffs: AcademyRecord.empty,
    regularSeasonFromStandings: AcademyRegularSeasonFromStandings.empty,
  );
}

/// Posiciones de tabla en fase regular (no campeonatos de torneo).
class AcademyRegularSeasonFromStandings {
  const AcademyRegularSeasonFromStandings({
    required this.teamEntries,
    required this.firstPlaces,
    required this.secondPlaces,
    required this.thirdPlaces,
  });

  final int teamEntries;
  final int firstPlaces;
  final int secondPlaces;
  final int thirdPlaces;

  static const AcademyRegularSeasonFromStandings empty =
      AcademyRegularSeasonFromStandings(
    teamEntries: 0,
    firstPlaces: 0,
    secondPlaces: 0,
    thirdPlaces: 0,
  );

  bool get hasData =>
      teamEntries > 0 ||
      firstPlaces > 0 ||
      secondPlaces > 0 ||
      thirdPlaces > 0;

  factory AcademyRegularSeasonFromStandings.fromJson(Map<String, dynamic> json) {
    return AcademyRegularSeasonFromStandings(
      teamEntries: JsonParse.intValue(
        json['teamEntries'] ?? json['team_entries'] ?? json['entries'],
      ),
      firstPlaces: JsonParse.intValue(
        json['firstPlaces'] ?? json['first_places'] ?? json['first'],
      ),
      secondPlaces: JsonParse.intValue(
        json['secondPlaces'] ?? json['second_places'] ?? json['second'],
      ),
      thirdPlaces: JsonParse.intValue(
        json['thirdPlaces'] ?? json['third_places'] ?? json['third'],
      ),
    );
  }
}

class AcademyHonors {
  const AcademyHonors({
    required this.finals,
    required this.championships,
    required this.history,
  });

  final List<AcademyFinal> finals;
  final int championships;
  final List<AcademyHonorHistory> history;

  factory AcademyHonors.fromJson(Map<String, dynamic> json) {
    return AcademyHonors(
      finals: JsonParse.list(json['finals'], AcademyFinal.fromJson),
      championships: JsonParse.intValue(
        json['championships'] ?? json['titles'],
      ),
      history: JsonParse.list(json['history'], AcademyHonorHistory.fromJson),
    );
  }

  static const AcademyHonors empty = AcademyHonors(
    finals: <AcademyFinal>[],
    championships: 0,
    history: <AcademyHonorHistory>[],
  );
}

/// Elemento reciente del palmarés (honors.history).
class AcademyHonorHistory {
  const AcademyHonorHistory({
    required this.id,
    required this.result,
    required this.year,
    required this.type,
    required this.tournament,
    required this.category,
  });

  final String id;
  final String result;
  final String year;
  final String type;
  final AcademyHonorTournamentRef tournament;
  final AcademyHonorCategoryRef category;

  bool get isChampionship {
    final normalized = type.trim().toLowerCase();
    if (normalized.contains('champion') ||
        normalized.contains('campeon') ||
        normalized == 'title') {
      return true;
    }
    final resultNorm = result.trim().toLowerCase();
    return resultNorm.contains('campeon') || resultNorm.contains('campeón');
  }

  bool get isRunnerUp {
    final normalized = type.trim().toLowerCase();
    if (normalized.contains('runner') || normalized.contains('subcampeon')) {
      return true;
    }
    final resultNorm = result.trim().toLowerCase();
    return resultNorm.contains('subcampeon') || resultNorm.contains('subcampeón');
  }

  factory AcademyHonorHistory.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> tournamentJson = json['tournament'] is Map
        ? Map<String, dynamic>.from(json['tournament'] as Map)
        : <String, dynamic>{
            'name': json['tournamentName'] ?? json['name'],
            'id': json['tournamentId'] ?? json['id'],
          };

    if (json['tournament'] is Map) {
      final rootTournamentId =
          (json['tournamentId'] ?? json['tournament_id'] ?? '').toString().trim();
      if (rootTournamentId.isNotEmpty &&
          (tournamentJson['id'] ?? '').toString().trim().isEmpty) {
        tournamentJson['id'] = rootTournamentId;
      }
      final rootTournamentName =
          (json['tournamentName'] ?? '').toString().trim();
      if (rootTournamentName.isNotEmpty &&
          (tournamentJson['name'] ?? '').toString().trim().isEmpty) {
        tournamentJson['name'] = rootTournamentName;
      }
    }

    final categoryJson = json['category'] is Map
        ? Map<String, dynamic>.from(json['category'] as Map)
        : <String, dynamic>{
            'name': json['categoryName'] ?? json['category'],
            'shortName': json['categoryShortName'] ?? json['shortName'],
          };

    return AcademyHonorHistory(
      id: JsonParse.string(json['id'] ?? json['_id']),
      result: JsonParse.string(json['result'] ?? json['position']),
      year: JsonParse.string(json['year'] ?? json['season']),
      type: JsonParse.string(json['type'] ?? json['honorType']),
      tournament: AcademyHonorTournamentRef.fromJson(tournamentJson),
      category: AcademyHonorCategoryRef.fromJson(categoryJson),
    );
  }
}

class AcademyHonorTournamentRef {
  const AcademyHonorTournamentRef({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory AcademyHonorTournamentRef.fromJson(Map<String, dynamic> json) {
    return AcademyHonorTournamentRef(
      id: JsonParse.string(json['id'] ?? json['_id'] ?? json['tournamentId']),
      name: JsonParse.string(json['name'], fallback: 'Torneo'),
    );
  }
}

class AcademyHonorCategoryRef {
  const AcademyHonorCategoryRef({
    required this.id,
    required this.name,
    required this.shortName,
  });

  final String id;
  final String name;
  final String shortName;

  factory AcademyHonorCategoryRef.fromJson(Map<String, dynamic> json) {
    final name = JsonParse.string(json['name']);
    final short = JsonParse.string(
      json['shortName'] ?? json['short_name'] ?? json['abbr'] ?? name,
    );
    return AcademyHonorCategoryRef(
      id: JsonParse.string(json['id'] ?? json['_id']),
      name: name,
      shortName: short,
    );
  }

  String displayLabel() {
    if (shortName.trim().isNotEmpty) return shortName.trim();
    return name.trim();
  }
}

class AcademyFinal {
  const AcademyFinal({
    required this.id,
    required this.tournamentName,
    required this.year,
    required this.category,
    required this.result,
    required this.teams,
  });

  final String id;
  final String tournamentName;
  final String year;
  final String category;
  final String result;
  final List<AcademyFinalTeam> teams;

  factory AcademyFinal.fromJson(Map<String, dynamic> json) {
    return AcademyFinal(
      id: JsonParse.string(json['id'] ?? json['_id']),
      tournamentName: JsonParse.string(
        json['tournamentName'] ?? json['tournament'] ?? json['name'],
      ),
      year: JsonParse.string(json['year'] ?? json['season']),
      category: JsonParse.string(json['category']),
      result: JsonParse.string(json['result'] ?? json['position']),
      teams: JsonParse.list(json['teams'], AcademyFinalTeam.fromJson),
    );
  }
}

class AcademyFinalTeam {
  const AcademyFinalTeam({
    required this.id,
    required this.name,
    required this.logo,
    required this.academyId,
    required this.points,
  });

  final String id;
  final String name;
  final String logo;
  final String academyId;
  final int? points;

  factory AcademyFinalTeam.fromJson(Map<String, dynamic> json) {
    return AcademyFinalTeam(
      id: JsonParse.string(json['id'] ?? json['_id'] ?? json['teamId']),
      name: JsonParse.string(json['name']),
      logo: JsonParse.string(json['logo'] ?? json['logo_url']),
      academyId: JsonParse.string(json['academyId'] ?? json['academy_id']),
      points: JsonParse.intOrNull(json['points']),
    );
  }
}

class AcademyCategory {
  const AcademyCategory({
    required this.id,
    required this.name,
    required this.key,
  });

  final String id;
  final String name;
  final String key;

  factory AcademyCategory.fromJson(Map<String, dynamic> json) {
    return AcademyCategory(
      id: JsonParse.string(json['id'] ?? json['_id']),
      name: JsonParse.string(json['name'], fallback: 'Categoría'),
      key: JsonParse.string(json['key'] ?? json['categoryKey'] ?? json['name']),
    );
  }
}

class AcademyCategoryStats {
  const AcademyCategoryStats({
    required this.category,
    required this.record,
    required this.teamCount,
    required this.championships,
    required this.runnerUps,
    required this.finals,
  });

  final AcademyCategory category;
  final AcademyRecord record;
  final int teamCount;
  final int championships;
  final int runnerUps;
  final int finals;

  factory AcademyCategoryStats.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'] is Map
        ? Map<String, dynamic>.from(json['category'] as Map)
        : <String, dynamic>{
            'name': json['categoryName'] ?? json['name'],
            'id': json['categoryId'] ?? json['id'],
          };

    return AcademyCategoryStats(
      category: AcademyCategory.fromJson(categoryJson),
      record: json['record'] is Map
          ? AcademyRecord.fromJson(Map<String, dynamic>.from(json['record'] as Map))
          : AcademyRecord.empty,
      teamCount: JsonParse.intValue(json['teamCount'] ?? json['teams']),
      championships: JsonParse.intValue(json['championships']),
      runnerUps: JsonParse.intValue(json['runnerUps'] ?? json['runner_ups']),
      finals: JsonParse.intValue(json['finals'] ?? json['finales']),
    );
  }
}

class AcademyYearStats {
  const AcademyYearStats({
    required this.year,
    required this.record,
    required this.tournaments,
    required this.championships,
  });

  final String year;
  final AcademyRecord record;
  final int tournaments;
  final int championships;

  factory AcademyYearStats.fromJson(Map<String, dynamic> json) {
    return AcademyYearStats(
      year: JsonParse.string(json['year'] ?? json['season']),
      record: json['record'] is Map
          ? AcademyRecord.fromJson(Map<String, dynamic>.from(json['record'] as Map))
          : AcademyRecord.empty,
      tournaments: JsonParse.intValue(json['tournaments']),
      championships: JsonParse.intValue(json['championships']),
    );
  }
}

class AcademyLeague {
  const AcademyLeague({
    required this.id,
    required this.name,
    required this.logo,
    required this.season,
    required this.tournamentCount,
  });

  final String id;
  final String name;
  final String logo;
  final String season;
  final int tournamentCount;

  factory AcademyLeague.fromJson(Map<String, dynamic> json) {
    return AcademyLeague(
      id: JsonParse.string(json['id'] ?? json['_id']),
      name: JsonParse.string(json['name'], fallback: 'Liga'),
      logo: JsonParse.string(json['logo'] ?? json['logo_url']),
      season: JsonParse.string(json['season'] ?? json['year']),
      tournamentCount: JsonParse.intValue(
        json['tournamentCount'] ?? json['tournaments'],
      ),
    );
  }
}

class AcademyTournaments {
  const AcademyTournaments({
    required this.current,
    required this.upcoming,
    required this.history,
  });

  final List<AcademyTournamentHistory> current;
  final List<AcademyTournamentHistory> upcoming;
  final List<AcademyTournamentHistory> history;

  factory AcademyTournaments.fromJson(Map<String, dynamic> json) {
    return AcademyTournaments(
      current: JsonParse.list(
        json['current'],
        AcademyTournamentHistory.fromJson,
      ),
      upcoming: JsonParse.list(
        json['upcoming'],
        AcademyTournamentHistory.fromJson,
      ),
      history: JsonParse.list(
        json['history'],
        AcademyTournamentHistory.fromJson,
      ),
    );
  }
}

class AcademyTournament {
  const AcademyTournament({
    required this.id,
    required this.name,
    required this.logo,
    required this.img,
    this.start,
    this.end,
    this.league,
    required this.category,
    required this.record,
    required this.standings,
    required this.team,
    required this.teamCount,
    required this.categoryCount,
  });

  final String id;
  final String name;
  final String logo;
  final String img;
  final DateTime? start;
  final DateTime? end;
  final String? league;
  final AcademyTournamentCategory? category;
  final AcademyRecord record;
  final List<AcademyStanding> standings;
  final AcademyTournamentTeam? team;
  final int teamCount;
  final int categoryCount;

  factory AcademyTournament.fromJson(Map<String, dynamic> json) {
    return AcademyTournament(
      id: JsonParse.string(json['id'] ?? json['_id'] ?? json['tournamentId']),
      name: JsonParse.string(json['name'], fallback: 'Torneo'),
      logo: JsonParse.string(json['logo'] ?? json['logo_url']),
      img: JsonParse.string(json['img'] ?? json['image'] ?? json['cover']),
      start: JsonParse.dateTime(json['start'] ?? json['startDate']),
      end: JsonParse.dateTime(json['end'] ?? json['endDate']),
      league: JsonParse.stringOrNull(json['league'] ?? json['leagueName']),
      category: json['category'] is Map
          ? AcademyTournamentCategory.fromJson(
              Map<String, dynamic>.from(json['category'] as Map),
            )
          : null,
      record: json['record'] is Map
          ? AcademyRecord.fromJson(Map<String, dynamic>.from(json['record'] as Map))
          : AcademyRecord.empty,
      standings: JsonParse.list(json['standings'], AcademyStanding.fromJson),
      team: json['team'] is Map
          ? AcademyTournamentTeam.fromJson(
              Map<String, dynamic>.from(json['team'] as Map),
            )
          : null,
      teamCount: JsonParse.intValue(json['teamCount'] ?? json['teams']),
      categoryCount: JsonParse.intValue(
        json['categoryCount'] ?? json['categories'],
      ),
    );
  }
}

class AcademyTournamentHistory {
  const AcademyTournamentHistory({
    required this.tournament,
    required this.teams,
    required this.categories,
    required this.standings,
    required this.finals,
    required this.record,
    required this.teamCount,
    required this.categoryCount,
    required this.championships,
    required this.runnerUps,
    this.legacyYear = '',
    this.legacyResult = '',
    this.legacyCategory,
  });

  final AcademyHistoryTournament tournament;
  final List<AcademyHistoryTeam> teams;
  final List<AcademyHistoryCategoryItem> categories;
  final List<AcademyTrajectoryStanding> standings;
  final List<AcademyTournamentHistoryFinal> finals;
  final AcademyRecord record;
  final int teamCount;
  final int categoryCount;
  final int championships;
  final int runnerUps;
  final String legacyYear;
  final String legacyResult;
  final AcademyTournamentCategory? legacyCategory;

  String get id => tournament.id;
  String get name => tournament.name;
  String get year =>
      tournament.start != null
          ? tournament.start!.year.toString()
          : legacyYear;
  String get result => legacyResult;
  AcademyTournamentCategory? get category => legacyCategory;

  factory AcademyTournamentHistory.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> tournamentJson = json['tournament'] is Map
        ? Map<String, dynamic>.from(json['tournament'] as Map)
        : Map<String, dynamic>.from(json);

    if (json['tournament'] is Map) {
      final rootTournamentId =
          (json['tournamentId'] ?? json['tournament_id'] ?? '').toString().trim();
      if (rootTournamentId.isNotEmpty &&
          (tournamentJson['id'] ?? '').toString().trim().isEmpty) {
        tournamentJson['id'] = rootTournamentId;
      }
      final rootTournamentName =
          (json['tournamentName'] ?? json['name'] ?? '').toString().trim();
      if (rootTournamentName.isNotEmpty &&
          (tournamentJson['name'] ?? '').toString().trim().isEmpty) {
        tournamentJson['name'] = rootTournamentName;
      }
    }

    return AcademyTournamentHistory(
      tournament: AcademyHistoryTournament.fromJson(tournamentJson),
      teams: JsonParse.list(
        json['teams'] ??
            json['participatingTeams'] ??
            json['enrolledTeams'] ??
            json['teamList'],
        AcademyHistoryTeam.fromJson,
      ),
      categories: JsonParse.list(
        json['categories'],
        AcademyHistoryCategoryItem.fromJson,
      ),
      standings: JsonParse.list(
        json['standings'],
        AcademyTrajectoryStanding.fromJson,
      ),
      finals: JsonParse.list(
        json['finals'],
        AcademyTournamentHistoryFinal.fromJson,
      ),
      record: json['record'] is Map
          ? AcademyRecord.fromJson(Map<String, dynamic>.from(json['record'] as Map))
          : AcademyRecord.empty,
      teamCount: _countOrListLength(json['teamCount'], json['teams']),
      categoryCount: _countOrListLength(json['categoryCount'], json['categories']),
      championships: JsonParse.intValue(
        json['championships'] ?? json['titles'] ?? json['firstPlaces'],
      ),
      runnerUps: JsonParse.intValue(
        json['runnerUps'] ?? json['runner_ups'] ?? json['secondPlaces'],
      ),
      legacyYear: JsonParse.string(json['year'] ?? json['season']),
      legacyResult: JsonParse.string(json['result'] ?? json['position']),
      legacyCategory: json['category'] is Map
          ? AcademyTournamentCategory.fromJson(
              Map<String, dynamic>.from(json['category'] as Map),
            )
          : null,
    );
  }

  static int _countOrListLength(dynamic countValue, dynamic listValue) {
    if (countValue != null) {
      return JsonParse.intValue(countValue);
    }
    if (listValue is List) return listValue.length;
    return JsonParse.intValue(listValue);
  }
}

class AcademyHistoryTournament {
  const AcademyHistoryTournament({
    required this.id,
    required this.name,
    required this.logo,
    required this.img,
    this.start,
    this.end,
    this.league,
    required this.status,
    this.active = false,
  });

  final String id;
  final String name;
  final String logo;
  final String img;
  final DateTime? start;
  final DateTime? end;
  final String? league;
  final String status;
  final bool active;

  factory AcademyHistoryTournament.fromJson(Map<String, dynamic> json) {
    return AcademyHistoryTournament(
      id: JsonParse.string(
        json['id'] ??
            json['_id'] ??
            json['tournamentId'] ??
            json['clave'],
      ),
      name: JsonParse.string(json['name'], fallback: 'Torneo'),
      logo: JsonParse.string(json['logo'] ?? json['logo_url']),
      img: JsonParse.string(json['img'] ?? json['image'] ?? json['cover']),
      start: JsonParse.dateTime(json['start'] ?? json['startDate']),
      end: JsonParse.dateTime(json['end'] ?? json['endDate']),
      league: _leagueNameFrom(json['league'] ?? json['leagueName']),
      status: JsonParse.string(json['status'], fallback: 'unknown'),
      active: JsonParse.boolValue(json['active']),
    );
  }

  static String? _leagueNameFrom(dynamic value) {
    if (value is Map) {
      return JsonParse.stringOrNull(value['name']);
    }
    return JsonParse.stringOrNull(value);
  }
}

class AcademyHistoryTeam {
  const AcademyHistoryTeam({
    required this.id,
    required this.name,
    required this.categoryShortName,
    required this.playersCount,
  });

  final String id;
  final String name;
  final String categoryShortName;
  final int playersCount;

  factory AcademyHistoryTeam.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    String shortName = '';
    if (category is Map) {
      shortName = JsonParse.string(
        category['shortName'] ??
            category['short_name'] ??
            category['name'],
      );
    } else {
      shortName = JsonParse.string(
        json['categoryShortName'] ?? json['categoryName'] ?? category,
      );
    }

    return AcademyHistoryTeam(
      id: JsonParse.string(json['id'] ?? json['_id'] ?? json['teamId']),
      name: JsonParse.string(json['name'] ?? json['teamName'] ?? json['alias']),
      categoryShortName: shortName,
      playersCount: JsonParse.intValue(json['playersCount'] ?? json['players']),
    );
  }
}

class AcademyHistoryCategoryItem {
  const AcademyHistoryCategoryItem({
    required this.shortName,
    required this.teamCount,
  });

  final String shortName;
  final int teamCount;

  factory AcademyHistoryCategoryItem.fromJson(Map<String, dynamic> json) {
    return AcademyHistoryCategoryItem(
      shortName: JsonParse.string(
        json['shortName'] ??
            json['short_name'] ??
            json['name'] ??
            json['categoryName'],
      ),
      teamCount: JsonParse.intValue(json['teamCount'] ?? json['teams']),
    );
  }
}

class AcademyTrajectoryStanding {
  const AcademyTrajectoryStanding({
    required this.teamName,
    required this.categoryName,
    required this.group,
    this.position,
    required this.played,
    required this.wins,
    required this.losses,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.pointDiff,
  });

  final String teamName;
  final String categoryName;
  final String group;
  final int? position;
  final int played;
  final int wins;
  final int losses;
  final int pointsFor;
  final int pointsAgainst;
  final int pointDiff;

  factory AcademyTrajectoryStanding.fromJson(Map<String, dynamic> json) {
    return AcademyTrajectoryStanding(
      teamName: JsonParse.string(json['teamName'] ?? json['name']),
      categoryName: JsonParse.string(
        json['categoryName'] ?? json['category'] ?? json['categoryShortName'],
      ),
      group: JsonParse.string(json['group'] ?? json['grupo'], fallback: 'default'),
      position: JsonParse.intOrNull(json['position'] ?? json['pos']),
      played: JsonParse.intValue(json['played'] ?? json['PJ'] ?? json['pj']),
      wins: JsonParse.intValue(json['wins'] ?? json['PG'] ?? json['pg']),
      losses: JsonParse.intValue(json['losses'] ?? json['PP'] ?? json['pp']),
      pointsFor: JsonParse.intValue(
        json['pointsFor'] ?? json['PF'] ?? json['pf'] ?? json['points_for'],
      ),
      pointsAgainst: JsonParse.intValue(
        json['pointsAgainst'] ?? json['PC'] ?? json['pc'] ?? json['points_against'],
      ),
      pointDiff: JsonParse.intValue(
        json['pointDiff'] ?? json['diff'] ?? json['point_diff'],
      ),
    );
  }
}

class AcademyTournamentHistoryFinal {
  const AcademyTournamentHistoryFinal({
    required this.academyResult,
    required this.category,
    required this.championTeamName,
    required this.runnerUpTeamName,
    required this.score,
  });

  final String academyResult;
  final AcademyHonorCategoryRef category;
  final String championTeamName;
  final String runnerUpTeamName;
  final String score;

  factory AcademyTournamentHistoryFinal.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'] is Map
        ? Map<String, dynamic>.from(json['category'] as Map)
        : <String, dynamic>{
            'shortName': json['categoryShortName'] ?? json['categoryName'],
          };
    final champion = json['champion'];
    final runnerUp = json['runnerUp'] ?? json['runner_up'];

    String championName = '';
    if (champion is Map) {
      championName = JsonParse.string(champion['teamName'] ?? champion['name']);
    } else {
      championName = JsonParse.string(champion);
    }

    String runnerName = '';
    if (runnerUp is Map) {
      runnerName = JsonParse.string(runnerUp['teamName'] ?? runnerUp['name']);
    } else {
      runnerName = JsonParse.string(runnerUp);
    }

    return AcademyTournamentHistoryFinal(
      academyResult: JsonParse.string(
        json['academyResult'] ?? json['result'] ?? json['academy_result'],
      ),
      category: AcademyHonorCategoryRef.fromJson(categoryJson),
      championTeamName: championName,
      runnerUpTeamName: runnerName,
      score: JsonParse.string(json['score'] ?? json['mark']),
    );
  }

  String resultLabel() {
    final normalized = academyResult.trim().toLowerCase();
    if (normalized == 'champion' || normalized.contains('campeon')) {
      return 'CAMPEÓN';
    }
    if (normalized == 'runner_up' ||
        normalized.contains('runner') ||
        normalized.contains('subcampeon')) {
      return 'SUBCAMPEÓN';
    }
    if (normalized.contains('champion_and_runner')) {
      return 'CAMPEÓN Y SUBCAMPEÓN';
    }
    return academyResult.trim().toUpperCase();
  }
}

class AcademyTournamentTeam {
  const AcademyTournamentTeam({
    required this.id,
    required this.name,
    required this.logo,
    this.category,
  });

  final String id;
  final String name;
  final String logo;
  final String? category;

  factory AcademyTournamentTeam.fromJson(Map<String, dynamic> json) {
    return AcademyTournamentTeam(
      id: JsonParse.string(json['id'] ?? json['_id'] ?? json['teamId']),
      name: JsonParse.string(json['name']),
      logo: JsonParse.string(json['logo'] ?? json['logo_url']),
      category: JsonParse.stringOrNull(
        json['category'] ?? json['categoryName'],
      ),
    );
  }
}

class AcademyTournamentCategory {
  const AcademyTournamentCategory({
    required this.id,
    required this.name,
    required this.key,
    required this.shortName,
  });

  final String id;
  final String name;
  final String key;
  final String shortName;

  factory AcademyTournamentCategory.fromJson(Map<String, dynamic> json) {
    final name = JsonParse.string(json['name']);
    return AcademyTournamentCategory(
      id: JsonParse.string(json['id'] ?? json['_id']),
      name: name,
      key: JsonParse.string(json['key'] ?? json['categoryKey'] ?? name),
      shortName: JsonParse.string(
        json['shortName'] ?? json['short_name'] ?? json['abbr'] ?? name,
      ),
    );
  }
}

class AcademyStanding {
  const AcademyStanding({
    required this.teamId,
    required this.teamName,
    required this.logo,
    this.position,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.points,
  });

  final String teamId;
  final String teamName;
  final String logo;
  final int? position;
  final int wins;
  final int losses;
  final int ties;
  final int points;

  factory AcademyStanding.fromJson(Map<String, dynamic> json) {
    return AcademyStanding(
      teamId: JsonParse.string(json['teamId'] ?? json['id'] ?? json['_id']),
      teamName: JsonParse.string(json['teamName'] ?? json['name']),
      logo: JsonParse.string(json['logo'] ?? json['logo_url']),
      position: JsonParse.intOrNull(json['position'] ?? json['pos']),
      wins: JsonParse.intValue(json['wins']),
      losses: JsonParse.intValue(json['losses']),
      ties: JsonParse.intValue(json['ties']),
      points: JsonParse.intValue(json['points']),
    );
  }
}

class AcademyMatches {
  const AcademyMatches({
    required this.totalDocuments,
    required this.finishedOfficial,
    required this.upcoming,
    required this.recent,
  });

  final int totalDocuments;
  final int finishedOfficial;
  final List<AcademyMatch> upcoming;
  final List<AcademyMatch> recent;

  factory AcademyMatches.fromJson(Map<String, dynamic> json) {
    return AcademyMatches(
      totalDocuments: JsonParse.intValue(
        json['totalDocuments'] ?? json['total'],
      ),
      finishedOfficial: JsonParse.intValue(
        json['finishedOfficial'] ?? json['finished'],
      ),
      upcoming: JsonParse.list(json['upcoming'], AcademyMatch.fromJson),
      recent: JsonParse.list(json['recent'], AcademyMatch.fromJson),
    );
  }

  static const AcademyMatches empty = AcademyMatches(
    totalDocuments: 0,
    finishedOfficial: 0,
    upcoming: <AcademyMatch>[],
    recent: <AcademyMatch>[],
  );
}

class AcademyMatch {
  const AcademyMatch({
    required this.id,
    this.date,
    this.journey,
    this.ronda,
    this.field,
    this.typeGame,
    this.tournamentId,
    this.sede,
    this.categoryName,
    required this.home,
    required this.visitor,
    this.venue,
  });

  final String id;
  final DateTime? date;
  final String? journey;
  final String? ronda;
  final String? field;
  final String? typeGame;
  final String? tournamentId;
  final String? sede;
  final String? categoryName;
  final AcademyMatchTeam home;
  final AcademyMatchTeam visitor;
  final AcademyVenue? venue;

  factory AcademyMatch.fromJson(Map<String, dynamic> json) {
    String? categoryName = JsonParse.stringOrNull(
      json['categoryName'] ?? json['category'],
    );
    if (categoryName == null && json['category'] is Map) {
      final cat = Map<String, dynamic>.from(json['category'] as Map);
      categoryName = JsonParse.stringOrNull(
        cat['shortName'] ?? cat['name'],
      );
    }

    return AcademyMatch(
      id: JsonParse.string(json['id'] ?? json['_id'] ?? json['matchId']),
      date: JsonParse.dateTime(json['date'] ?? json['fecha']),
      journey: JsonParse.stringOrNull(json['journey'] ?? json['jornada']),
      ronda: JsonParse.stringOrNull(json['ronda'] ?? json['round']),
      field: JsonParse.stringOrNull(json['field'] ?? json['cancha']),
      typeGame: JsonParse.stringOrNull(json['typeGame'] ?? json['type']),
      tournamentId: JsonParse.stringOrNull(
        json['tournamentId'] ?? json['tournament_id'],
      ),
      sede: JsonParse.stringOrNull(json['sede'] ?? json['venueName']),
      categoryName: categoryName,
      home: json['home'] is Map
          ? AcademyMatchTeam.fromJson(Map<String, dynamic>.from(json['home'] as Map))
          : AcademyMatchTeam.empty,
      visitor: json['visitor'] is Map
          ? AcademyMatchTeam.fromJson(
              Map<String, dynamic>.from(json['visitor'] as Map),
            )
          : AcademyMatchTeam.empty,
      venue: json['venue'] is Map
          ? AcademyVenue.fromJson(Map<String, dynamic>.from(json['venue'] as Map))
          : json['sede'] is Map
              ? AcademyVenue.fromJson(Map<String, dynamic>.from(json['sede'] as Map))
              : null,
    );
  }

  String venueLabel() {
    if (venue != null && venue!.name.trim().isNotEmpty) {
      return venue!.name.trim();
    }
    final sedeText = (sede ?? '').trim();
    if (sedeText.isNotEmpty) return sedeText;
    return '';
  }
}

class AcademyMatchTeam {
  const AcademyMatchTeam({
    required this.teamId,
    required this.academyId,
    required this.name,
    required this.logo,
    this.points,
  });

  final String teamId;
  final String academyId;
  final String name;
  final String logo;
  final int? points;

  static const AcademyMatchTeam empty = AcademyMatchTeam(
    teamId: '',
    academyId: '',
    name: '',
    logo: '',
  );

  factory AcademyMatchTeam.fromJson(Map<String, dynamic> json) {
    return AcademyMatchTeam(
      teamId: JsonParse.string(json['teamId'] ?? json['id'] ?? json['_id']),
      academyId: JsonParse.string(json['academyId'] ?? json['academy_id']),
      name: JsonParse.string(json['name'] ?? json['teamName']),
      logo: JsonParse.string(json['logo'] ?? json['logo_url'] ?? json['thumb']),
      points: JsonParse.intOrNull(json['points'] ?? json['score']),
    );
  }

  String get teamName => name;
}

class AcademyVenue {
  const AcademyVenue({
    required this.id,
    required this.name,
    required this.city,
    required this.field,
  });

  final String id;
  final String name;
  final String city;
  final String field;

  factory AcademyVenue.fromJson(Map<String, dynamic> json) {
    return AcademyVenue(
      id: JsonParse.string(json['id'] ?? json['_id']),
      name: JsonParse.string(json['name']),
      city: JsonParse.string(json['city'] ?? json['ciudad']),
      field: JsonParse.string(json['field'] ?? json['cancha']),
    );
  }
}

class AcademyProfileMeta {
  const AcademyProfileMeta({
    required this.generatedAt,
    required this.dataQuality,
    required this.source,
  });

  final DateTime? generatedAt;
  final AcademyDataQuality dataQuality;
  final String source;

  factory AcademyProfileMeta.fromJson(Map<String, dynamic> json) {
    return AcademyProfileMeta(
      generatedAt: JsonParse.dateTime(
        json['generatedAt'] ?? json['generated_at'] ?? json['timestamp'],
      ),
      dataQuality: json['dataQuality'] is Map || json['data_quality'] is Map
          ? AcademyDataQuality.fromJson(
              Map<String, dynamic>.from(
                (json['dataQuality'] ?? json['data_quality']) as Map,
              ),
            )
          : AcademyDataQuality.empty,
      source: JsonParse.string(json['source']),
    );
  }
}

class AcademyDataQuality {
  const AcademyDataQuality({
    required this.complete,
    required this.missingFields,
    required this.warnings,
    required this.unresolvedTournamentIds,
    required this.unresolvedFinals,
  });

  final bool complete;
  final List<String> missingFields;
  final List<String> warnings;
  final List<String> unresolvedTournamentIds;
  final int unresolvedFinals;

  static const AcademyDataQuality empty = AcademyDataQuality(
    complete: true,
    missingFields: <String>[],
    warnings: <String>[],
    unresolvedTournamentIds: <String>[],
    unresolvedFinals: 0,
  );

  factory AcademyDataQuality.fromJson(Map<String, dynamic> json) {
    return AcademyDataQuality(
      complete: JsonParse.boolValue(json['complete'], fallback: true),
      missingFields: _stringList(json['missingFields'] ?? json['missing_fields']),
      warnings: _stringList(json['warnings']),
      unresolvedTournamentIds: _stringList(
        json['unresolvedTournamentIds'] ?? json['unresolved_tournament_ids'],
      ),
      unresolvedFinals: JsonParse.intValue(
        json['unresolvedFinals'] ?? json['unresolved_finals'],
        fallback: 0,
      ),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

/// Respuesta del endpoint `getAcademyPublicProfile`.
class AcademyProfileResponse {
  const AcademyProfileResponse({
    required this.status,
    required this.academy,
    required this.snapshotAvailable,
    this.snapshot,
    required this.liveTournaments,
    required this.liveSummary,
  });

  final String status;
  final AcademyProfile academy;
  final bool snapshotAvailable;
  final AcademyProfileSnapshot? snapshot;
  final AcademyLiveTournaments liveTournaments;
  final AcademyLiveSummary liveSummary;

  factory AcademyProfileResponse.fromJson(Map<String, dynamic> json) {
    return AcademyProfileResponse(
      status: JsonParse.string(json['status']),
      academy: AcademyProfile.fromJson(JsonParse.map(json['academy'])),
      snapshotAvailable: JsonParse.boolValue(json['snapshotAvailable']),
      snapshot: json['snapshot'] is Map
          ? AcademyProfileSnapshot.fromJson(
              Map<String, dynamic>.from(json['snapshot'] as Map),
            )
          : null,
      liveTournaments: AcademyLiveTournaments.fromJson(
        JsonParse.map(json['tournaments']),
      ),
      liveSummary: json['liveSummary'] is Map
          ? AcademyLiveSummary.fromJson(
              Map<String, dynamic>.from(json['liveSummary'] as Map),
            )
          : AcademyLiveSummary.empty,
    );
  }

  AcademyProfileContext toContext() {
    final snap = snapshot;
    final history = snap?.history ?? <AcademyTournamentHistory>[];

    return AcademyProfileContext(
      academy: academy,
      summary: snap?.summary ?? AcademySummary.empty,
      record: snap?.record ?? AcademyRecordBundle.empty,
      playoffs: snap?.playoffs ?? AcademyPlayoffsParticipation.empty,
      honors: snap?.honors ?? AcademyHonors.empty,
      categories: snap?.categories ?? <AcademyCategory>[],
      categoryStats: snap?.categoryStats ?? <AcademyCategoryStats>[],
      yearStats: snap?.yearStats ?? <AcademyYearStats>[],
      leagues: snap?.leagues ?? <AcademyLeague>[],
      tournaments: AcademyTournaments(
        current: liveTournaments.current
            .map((item) => item.toParticipationHistory())
            .toList(),
        upcoming: liveTournaments.upcoming
            .map((item) => item.toParticipationHistory())
            .toList(),
        history: history,
      ),
      matches: snap?.matches ?? AcademyMatches.empty,
      meta: AcademyProfileMeta(
        generatedAt: snap?.generatedAt,
        dataQuality: AcademyDataQuality.empty,
        source: 'getAcademyPublicProfile',
      ),
      snapshotAvailable: snapshotAvailable,
      liveSummary: liveSummary,
    );
  }
}

class AcademyProfileSnapshot {
  const AcademyProfileSnapshot({
    this.generatedAt,
    required this.summary,
    required this.record,
    required this.playoffs,
    required this.honors,
    required this.categories,
    required this.categoryStats,
    required this.yearStats,
    required this.leagues,
    required this.history,
    required this.matches,
  });

  final DateTime? generatedAt;
  final AcademySummary summary;
  final AcademyRecordBundle record;
  final AcademyPlayoffsParticipation playoffs;
  final AcademyHonors honors;
  final List<AcademyCategory> categories;
  final List<AcademyCategoryStats> categoryStats;
  final List<AcademyYearStats> yearStats;
  final List<AcademyLeague> leagues;
  final List<AcademyTournamentHistory> history;
  final AcademyMatches matches;

  factory AcademyProfileSnapshot.fromJson(Map<String, dynamic> json) {
    final tournamentsMap = JsonParse.map(json['tournaments']);

    return AcademyProfileSnapshot(
      generatedAt: JsonParse.dateTime(
        json['generatedAt'] ?? json['generated_at'],
      ),
      summary: AcademySummary.fromJson(JsonParse.map(json['summary'])),
      record: AcademyRecordBundle.fromJson(JsonParse.map(json['record'])),
      playoffs: json['playoffs'] is Map
          ? AcademyPlayoffsParticipation.fromJson(
              Map<String, dynamic>.from(json['playoffs'] as Map),
            )
          : AcademyPlayoffsParticipation.empty,
      honors: AcademyHonors.fromJson(JsonParse.map(json['honors'])),
      categories: JsonParse.list(
        json['categories'],
        AcademyCategory.fromJson,
      ),
      categoryStats: JsonParse.list(
        json['categoryStats'],
        AcademyCategoryStats.fromJson,
      ),
      yearStats: JsonParse.list(
        json['yearStats'],
        AcademyYearStats.fromJson,
      ),
      leagues: JsonParse.list(
        json['leagues'],
        AcademyLeague.fromJson,
      ),
      history: JsonParse.list(
        tournamentsMap['history'],
        AcademyTournamentHistory.fromJson,
      ),
      matches: AcademyMatches.fromJson(JsonParse.map(json['matches'])),
    );
  }
}

class AcademyLiveTournaments {
  const AcademyLiveTournaments({
    required this.current,
    required this.upcoming,
  });

  final List<AcademyLiveTournament> current;
  final List<AcademyLiveTournament> upcoming;

  factory AcademyLiveTournaments.fromJson(Map<String, dynamic> json) {
    return AcademyLiveTournaments(
      current: JsonParse.list(
        json['current'],
        AcademyLiveTournament.fromJson,
      ),
      upcoming: JsonParse.list(
        json['upcoming'],
        AcademyLiveTournament.fromJson,
      ),
    );
  }

  static const AcademyLiveTournaments empty = AcademyLiveTournaments(
    current: <AcademyLiveTournament>[],
    upcoming: <AcademyLiveTournament>[],
  );
}

class AcademyLiveTournament {
  const AcademyLiveTournament({
    required this.id,
    required this.name,
    required this.logo,
    required this.img,
    this.start,
    this.end,
    required this.status,
    required this.academyParticipation,
  });

  final String id;
  final String name;
  final String logo;
  final String img;
  final DateTime? start;
  final DateTime? end;
  final String status;
  final AcademyParticipation academyParticipation;

  factory AcademyLiveTournament.fromJson(Map<String, dynamic> json) {
    return AcademyLiveTournament(
      id: JsonParse.string(json['id'] ?? json['_id'] ?? json['tournamentId']),
      name: JsonParse.string(json['name'], fallback: 'Torneo'),
      logo: JsonParse.string(json['logo'] ?? json['logo_url']),
      img: JsonParse.string(json['img'] ?? json['image'] ?? json['cover']),
      start: JsonParse.dateTime(json['start'] ?? json['startDate']),
      end: JsonParse.dateTime(json['end'] ?? json['endDate']),
      status: JsonParse.string(json['status'], fallback: 'unknown'),
      academyParticipation: json['academyParticipation'] is Map
          ? AcademyParticipation.fromJson(
              Map<String, dynamic>.from(json['academyParticipation'] as Map),
            )
          : AcademyParticipation.empty,
    );
  }

  AcademyTournamentHistory toParticipationHistory() {
    final participation = academyParticipation;
    final teams = participation.teams
        .map((team) => team.toHistoryTeam())
        .toList();
    final categories = _categoriesFromTeams(teams);
    final teamCount = participation.teamCount > 0
        ? participation.teamCount
        : (participation.teamIds.isNotEmpty
            ? participation.teamIds.length
            : teams.length);

    return AcademyTournamentHistory(
      tournament: AcademyHistoryTournament(
        id: id,
        name: name,
        logo: logo,
        img: img,
        start: start,
        end: end,
        status: status,
        active: status.trim().toLowerCase() == 'current',
      ),
      teams: teams,
      categories: categories,
      standings: <AcademyTrajectoryStanding>[],
      finals: <AcademyTournamentHistoryFinal>[],
      record: AcademyRecord.empty,
      teamCount: teamCount,
      categoryCount: categories.isNotEmpty ? categories.length : teamCount,
      championships: 0,
      runnerUps: 0,
    );
  }

  static List<AcademyHistoryCategoryItem> _categoriesFromTeams(
    List<AcademyHistoryTeam> teams,
  ) {
    final counts = <String, int>{};
    for (final team in teams) {
      final category = team.categoryShortName.trim();
      if (category.isEmpty) continue;
      counts[category] = (counts[category] ?? 0) + 1;
    }

    return counts.entries
        .map(
          (entry) => AcademyHistoryCategoryItem(
            shortName: entry.key,
            teamCount: entry.value,
          ),
        )
        .toList();
  }
}

class AcademyParticipation {
  const AcademyParticipation({
    required this.teamCount,
    required this.teamIds,
    required this.teams,
  });

  final int teamCount;
  final List<String> teamIds;
  final List<AcademyParticipationTeam> teams;

  factory AcademyParticipation.fromJson(Map<String, dynamic> json) {
    return AcademyParticipation(
      teamCount: JsonParse.intValue(json['teamCount'] ?? json['teams']),
      teamIds: _stringList(json['teamIds'] ?? json['team_ids']),
      teams: JsonParse.list(
        json['teams'],
        AcademyParticipationTeam.fromJson,
      ),
    );
  }

  static const AcademyParticipation empty = AcademyParticipation(
    teamCount: 0,
    teamIds: <String>[],
    teams: <AcademyParticipationTeam>[],
  );

  static List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

class AcademyParticipationTeam {
  const AcademyParticipationTeam({
    required this.id,
    required this.name,
    required this.categoryShortName,
  });

  final String id;
  final String name;
  final String categoryShortName;

  factory AcademyParticipationTeam.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    String shortName = '';
    if (category is Map) {
      shortName = JsonParse.string(
        category['shortName'] ??
            category['short_name'] ??
            category['name'],
      );
    } else {
      shortName = JsonParse.string(
        json['categoryShortName'] ?? json['categoryName'] ?? category,
      );
    }

    return AcademyParticipationTeam(
      id: JsonParse.string(json['id'] ?? json['_id'] ?? json['teamId']),
      name: JsonParse.string(json['name'] ?? json['teamName'] ?? json['alias']),
      categoryShortName: shortName,
    );
  }

  AcademyHistoryTeam toHistoryTeam() {
    return AcademyHistoryTeam(
      id: id,
      name: name,
      categoryShortName: categoryShortName,
      playersCount: 0,
    );
  }
}

class AcademyLiveSummary {
  const AcademyLiveSummary({
    required this.currentTournaments,
    required this.upcomingTournaments,
    required this.currentTeams,
    required this.upcomingTeams,
  });

  final int currentTournaments;
  final int upcomingTournaments;
  final int currentTeams;
  final int upcomingTeams;

  factory AcademyLiveSummary.fromJson(Map<String, dynamic> json) {
    return AcademyLiveSummary(
      currentTournaments: JsonParse.intValue(
        json['currentTournaments'] ?? json['current_tournaments'],
      ),
      upcomingTournaments: JsonParse.intValue(
        json['upcomingTournaments'] ?? json['upcoming_tournaments'],
      ),
      currentTeams: JsonParse.intValue(
        json['currentTeams'] ?? json['current_teams'],
      ),
      upcomingTeams: JsonParse.intValue(
        json['upcomingTeams'] ?? json['upcoming_teams'],
      ),
    );
  }

  static const AcademyLiveSummary empty = AcademyLiveSummary(
    currentTournaments: 0,
    upcomingTournaments: 0,
    currentTeams: 0,
    upcomingTeams: 0,
  );
}
