import 'package:flutter/material.dart';

import '../utils/award_score_format.dart';
import '../utils/match_awards.dart';
import '../utils/match_helpers.dart';

/// Identificador estable de categoría de reconocimiento.
enum MatchAwardCategory {
  mvp,
  featuredPlayer,
  offensiveLeader,
  defensiveLeader,
}

/// Fila de desglose para el bottom sheet (solo presentación).
class AwardBreakdownRow {
  const AwardBreakdownRow({
    required this.label,
    required this.value,
    this.detail,
    this.isTotal = false,
    this.isBonus = false,
  });

  final String label;
  final double value;
  final String? detail;
  final bool isTotal;
  final bool isBonus;
}

/// Datos resueltos para MatchAwardDetailSheet.
class MatchAwardDetailPayload {
  const MatchAwardDetailPayload({
    required this.category,
    required this.title,
    required this.sectionLabel,
    required this.player,
    required this.teamName,
    required this.teamLogoUrl,
    required this.teamColor,
    required this.score,
    required this.scoreLabel,
    required this.icon,
    this.source,
    this.breakdown = const [],
    this.tiedPlayers = const [],
    this.explanation,
    this.allTiedEntries = const [],
  });

  final MatchAwardCategory category;
  final String title;
  final String sectionLabel;
  final Map<String, dynamic> player;
  final String teamName;
  final String teamLogoUrl;
  final Color teamColor;
  final double score;
  final String scoreLabel;
  final IconData icon;
  final String? source;
  final List<AwardBreakdownRow> breakdown;
  final List<Map<String, dynamic>> tiedPlayers;
  final String? explanation;
  final List<TiedPlayerEntry> allTiedEntries;
}

class TiedPlayerEntry {
  const TiedPlayerEntry({
    required this.player,
    required this.teamName,
    required this.teamLogoUrl,
    required this.teamColor,
    required this.score,
  });

  final Map<String, dynamic> player;
  final String teamName;
  final String teamLogoUrl;
  final Color teamColor;
  final double score;
}

/// Construye payloads de detalle únicamente desde [matchAwards] existente.
class MatchAwardDetailBuilder {
  MatchAwardDetailBuilder({
    required this.matchAwards,
    required this.homeTeam,
    required this.visitorTeam,
    required this.homeColor,
    required this.visitColor,
  });

  final MatchAwardsResult matchAwards;
  final Map<String, dynamic> homeTeam;
  final Map<String, dynamic> visitorTeam;
  final Color homeColor;
  final Color visitColor;

  MatchAwardDetailPayload? forCategory(MatchAwardCategory category) {
    switch (category) {
      case MatchAwardCategory.mvp:
        return _mvpPayload();
      case MatchAwardCategory.featuredPlayer:
        return _featuredPayload();
      case MatchAwardCategory.offensiveLeader:
        return _offensivePayload();
      case MatchAwardCategory.defensiveLeader:
        return _defensivePayload();
    }
  }

  MatchAwardDetailPayload? _mvpPayload() {
    final mvp = matchAwards.mvp;
    if (mvp == null) return null;
    final player = mvp.player;
    final team = _teamContext(player);
    return MatchAwardDetailPayload(
      category: MatchAwardCategory.mvp,
      title: 'MVP DEL PARTIDO',
      sectionLabel: 'RECONOCIMIENTO',
      player: player,
      teamName: team.name,
      teamLogoUrl: team.logoUrl,
      teamColor: team.color,
      score: 0,
      scoreLabel: '',
      icon: Icons.star_rounded,
      source: mvp.source,
      explanation:
          'ELEGIDO OFICIALMENTE COMO MVP DEL PARTIDO. RECONOCIMIENTO OFICIAL.',
    );
  }

  MatchAwardDetailPayload? _featuredPayload() {
    final award = matchAwards.featuredPlayer;
    if (award == null || award.player == null) return null;
    final player = award.player!;
    final team = _teamContext(player);
    final tied = _allTiedEntries(
      primary: player,
      tiedPlayers: award.tiedPlayers,
      score: award.integralImpactScore,
    );
    return MatchAwardDetailPayload(
      category: MatchAwardCategory.featuredPlayer,
      title: 'JUGADOR DESTACADO',
      sectionLabel: 'RECONOCIMIENTO',
      player: player,
      teamName: team.name,
      teamLogoUrl: team.logoUrl,
      teamColor: team.color,
      score: award.integralImpactScore,
      scoreLabel: 'PUNTOS DE IMPACTO',
      icon: Icons.bolt_rounded,
      breakdown: [
        AwardBreakdownRow(
          label: 'Producción',
          value: award.productionScore,
        ),
        AwardBreakdownRow(
          label: 'Versatilidad',
          value: award.versatilityBonus.toDouble(),
          isBonus: true,
        ),
        AwardBreakdownRow(
          label: 'Doble vía',
          value: award.twoWayBonus,
          isBonus: true,
        ),
        AwardBreakdownRow(
          label: 'Contexto',
          value: award.contextualBonus,
          isBonus: true,
        ),
        AwardBreakdownRow(
          label: 'Impacto integral',
          value: award.integralImpactScore,
          isTotal: true,
        ),
      ],
      tiedPlayers: award.tiedPlayers,
      allTiedEntries: tied,
      explanation:
          'Reconocimiento calculado por producción, versatilidad, participación ofensiva y defensiva, y acciones que empataron o dieron ventaja.',
    );
  }

  MatchAwardDetailPayload? _offensivePayload() {
    final award = matchAwards.offensiveLeader;
    if (award == null) return null;
    final player = award.player;
    final team = _teamContext(player);
    final rows = _offensiveBreakdown(player, award.score);
    final tied = _allTiedEntries(
      primary: player,
      tiedPlayers: award.tiedPlayers,
      score: award.score,
    );
    return MatchAwardDetailPayload(
      category: MatchAwardCategory.offensiveLeader,
      title: 'LÍDER OFENSIVO',
      sectionLabel: 'RECONOCIMIENTO',
      player: player,
      teamName: team.name,
      teamLogoUrl: team.logoUrl,
      teamColor: team.color,
      score: award.score,
      scoreLabel: 'IMPACTO OFENSIVO',
      icon: Icons.arrow_forward_rounded,
      breakdown: rows,
      tiedPlayers: award.tiedPlayers,
      allTiedEntries: tied,
    );
  }

  MatchAwardDetailPayload? _defensivePayload() {
    final award = matchAwards.defensiveLeader;
    if (award == null) return null;
    final player = award.player;
    final team = _teamContext(player);
    final rows = _defensiveBreakdown(player, award.score);
    final tied = _allTiedEntries(
      primary: player,
      tiedPlayers: award.tiedPlayers,
      score: award.score,
    );
    return MatchAwardDetailPayload(
      category: MatchAwardCategory.defensiveLeader,
      title: 'LÍDER DEFENSIVO',
      sectionLabel: 'RECONOCIMIENTO',
      player: player,
      teamName: team.name,
      teamLogoUrl: team.logoUrl,
      teamColor: team.color,
      score: award.score,
      scoreLabel: 'IMPACTO DEFENSIVO',
      icon: Icons.shield_outlined,
      breakdown: rows,
      tiedPlayers: award.tiedPlayers,
      allTiedEntries: tied,
    );
  }

  List<AwardBreakdownRow> _offensiveBreakdown(
    Map<String, dynamic> player,
    double total,
  ) {
    final passes = _readCount(player, ['passes', 'pass']);
    final catches = _readCount(player, ['receptions', 'catch', 'catches']);
    final runs = _readCount(player, ['runs', 'run']);
    final rows = <AwardBreakdownRow>[];

    if (passes != null) {
      rows.add(
        AwardBreakdownRow(
          label: 'Pases lanzados',
          value: passes * 0.6,
          detail: '$passes acciones · ${formatAwardDisplayScore(passes * 0.6)} puntos',
        ),
      );
    }
    if (catches != null) {
      rows.add(
        AwardBreakdownRow(
          label: 'Recepciones',
          value: catches * 1.2,
          detail: '$catches acciones · ${formatAwardDisplayScore(catches * 1.2)} puntos',
        ),
      );
    }
    if (runs != null) {
      rows.add(
        AwardBreakdownRow(
          label: 'Carreras',
          value: runs * 1.2,
          detail: '$runs acciones · ${formatAwardDisplayScore(runs * 1.2)} puntos',
        ),
      );
    }

    if (rows.isEmpty) {
      // Sin conteos en el jugador: solo total disponible en matchAwards.
    }

    rows.add(
      AwardBreakdownRow(
        label: 'Impacto ofensivo',
        value: total,
        isTotal: true,
      ),
    );
    return rows;
  }

  List<AwardBreakdownRow> _defensiveBreakdown(
    Map<String, dynamic> player,
    double total,
  ) {
    final sacks = _readCount(player, ['normalSacks', 'sack', 'sacks']);
    final safeties = _readCount(player, ['safeties', 'safety']);
    final inters = _readCount(player, ['normalInterceptions', 'inter', 'ints']);
    final inter2 = _readCount(player, ['interceptionReturns2Pts', 'inter2']);
    final pickSix = _readCount(player, ['pickSixes', 'pickSix']);
    final rows = <AwardBreakdownRow>[];

    if (sacks != null) {
      rows.add(
        AwardBreakdownRow(
          label: 'Sacks normales',
          value: sacks * 2,
          detail: '$sacks acciones · ${formatAwardDisplayScore(sacks * 2)} puntos',
        ),
      );
    }
    if (safeties != null) {
      rows.add(
        AwardBreakdownRow(
          label: 'Safeties',
          value: safeties * 5,
          detail: '$safeties acciones · ${formatAwardDisplayScore(safeties * 5)} puntos',
        ),
      );
    }
    if (inters != null) {
      rows.add(
        AwardBreakdownRow(
          label: 'Intercepciones',
          value: inters * 4,
          detail: '$inters acciones · ${formatAwardDisplayScore(inters * 4)} puntos',
        ),
      );
    }
    if (inter2 != null) {
      rows.add(
        AwardBreakdownRow(
          label: 'Retornos de 2 puntos',
          value: inter2 * 5,
          detail: '$inter2 acciones · ${formatAwardDisplayScore(inter2 * 5)} puntos',
        ),
      );
    }
    if (pickSix != null) {
      rows.add(
        AwardBreakdownRow(
          label: 'Pick six',
          value: pickSix * 7,
          detail: '$pickSix acciones · ${formatAwardDisplayScore(pickSix * 7)} puntos',
        ),
      );
    }

    if (rows.isEmpty) {
      // Sin conteos en el jugador: solo total disponible en matchAwards.
    }

    rows.add(
      AwardBreakdownRow(
        label: 'Impacto defensivo',
        value: total,
        isTotal: true,
      ),
    );
    return rows;
  }

  int? _readCount(Map<String, dynamic> player, List<String> keys) {
    for (final key in keys) {
      final parsed = int.tryParse((player[key] ?? '').toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  List<TiedPlayerEntry> _allTiedEntries({
    required Map<String, dynamic> primary,
    required List<Map<String, dynamic>> tiedPlayers,
    required double score,
  }) {
    final seen = <String>{};
    final entries = <TiedPlayerEntry>[];

    void add(Map<String, dynamic> raw) {
      final id = _entityId(raw);
      if (id.isNotEmpty && seen.contains(id)) return;
      if (id.isNotEmpty) seen.add(id);
      final team = _teamContext(raw);
      entries.add(
        TiedPlayerEntry(
          player: Map<String, dynamic>.from(raw),
          teamName: team.name,
          teamLogoUrl: team.logoUrl,
          teamColor: team.color,
          score: score,
        ),
      );
    }

    add(primary);
    for (final tied in tiedPlayers) {
      add(tied);
    }
    return entries;
  }

  _TeamCtx _teamContext(Map<String, dynamic> player) {
    final isHome = player['isHome'] == true;
    final team = isHome
        ? MatchHelpers.asMap(homeTeam)
        : MatchHelpers.asMap(visitorTeam);
    return _TeamCtx(
      name: MatchHelpers.teamDisplayName(
        team,
        fallback: (player['teamName'] ?? '').toString(),
      ),
      logoUrl: MatchHelpers.teamLogoUrl(team),
      color: isHome ? homeColor : visitColor,
    );
  }

  String _entityId(Map<String, dynamic> entity) {
    return (entity['_id'] ?? entity['id'] ?? '').toString().trim();
  }
}

class _TeamCtx {
  const _TeamCtx({
    required this.name,
    required this.logoUrl,
    required this.color,
  });

  final String name;
  final String logoUrl;
  final Color color;
}

bool categoryExists(MatchAwardsResult awards, MatchAwardCategory category) {
  switch (category) {
    case MatchAwardCategory.mvp:
      return awards.hasMvp;
    case MatchAwardCategory.featuredPlayer:
      return awards.hasFeaturedPlayer;
    case MatchAwardCategory.offensiveLeader:
      return awards.hasOffensiveLeader;
    case MatchAwardCategory.defensiveLeader:
      return awards.hasDefensiveLeader;
  }
}
