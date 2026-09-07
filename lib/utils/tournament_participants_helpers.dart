import 'package:flutter/material.dart';

import '../config/category_palette.dart';
import '../config/theme.dart';
import 'tournament_catalog_helpers.dart';

/// Agrupación derivada de equipos participantes en un torneo (sin persistencia).
class TournamentAcademyGroup {
  const TournamentAcademyGroup({
    required this.academyId,
    required this.academyName,
    required this.academyLogo,
    required this.teamCount,
    required this.teams,
  });

  final String academyId;
  final String academyName;
  final String academyLogo;
  final int teamCount;
  final List<Map<String, dynamic>> teams;
}

/// Academia con equipos visibles según el filtro de categoría activo.
class TournamentAcademyVisibleGroup {
  const TournamentAcademyVisibleGroup({
    required this.group,
    required this.visibleTeams,
    required this.visibleTeamCount,
  });

  final TournamentAcademyGroup group;
  final List<Map<String, dynamic>> visibleTeams;
  final int visibleTeamCount;

  String get academyId => group.academyId;
  String get academyName => group.academyName;
  String get academyLogo => group.academyLogo;
  int get teamCount => group.teamCount;
}

/// Categoría con equipos inscritos, para el filtro de participantes.
class TournamentCategoryFilterOption {
  const TournamentCategoryFilterOption({
    required this.key,
    required this.name,
    required this.shortName,
    required this.teamCount,
    required this.academyCount,
  });

  final String key;
  final String name;
  final String shortName;
  final int teamCount;
  final int academyCount;
}

class TournamentParticipantsHelpers {
  TournamentParticipantsHelpers._();

  /// Extrae equipos únicos de bloques por categoría y anota la categoría del bloque.
  static List<Map<String, dynamic>> flattenTeamsFromCategoryBlocks(
    List<Map<String, dynamic>> categoryBlocks,
  ) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];

    void addAll(List<dynamic> teams, dynamic blockCategory) {
      for (final item in teams) {
        if (item is! Map) continue;
        final team = enrichTeamWithBlockCategory(
          Map<String, dynamic>.from(item),
          blockCategory,
        );
        final id = (team['_id'] ?? team['id'] ?? '').toString();
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        out.add(team);
      }
    }

    for (final block in categoryBlocks) {
      final blockCategory = block['category'];
      addAll(block['teams'] as List<dynamic>? ?? [], blockCategory);
      for (final group in block['groups'] as List<dynamic>? ?? []) {
        if (group is Map) {
          addAll(group['teams'] as List<dynamic>? ?? [], blockCategory);
        }
      }
    }

    return out;
  }

  static Map<String, dynamic> enrichTeamWithBlockCategory(
    Map<String, dynamic> team,
    dynamic blockCategory,
  ) {
    final key = resolveCategoryKey(blockCategory);
    if (key.isEmpty) return team;

    final name = blockCategory is Map
        ? (blockCategory['name'] ?? key).toString().trim()
        : key;
    final shortName = resolveCategoryShortName(
      blockCategory,
      fallbackName: name,
    );

    return {
      ...team,
      'participantCategoryKey': key,
      'participantCategoryName': name,
      'participantCategoryShortName': shortName,
    };
  }

  static String resolveCategoryKey(dynamic category) {
    if (category is Map) {
      final name = (category['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
      final id = (category['id'] ?? category['_id'] ?? '').toString().trim();
      if (id.isNotEmpty) return id;
    }
    if (category != null) {
      final value = category.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String resolveCategoryShortName(
    dynamic category, {
    String? fallbackName,
  }) {
    if (category is Map) {
      final short = (category['shortName'] ?? '').toString().trim();
      if (short.isNotEmpty) return short;
      final name = (category['name'] ?? fallbackName ?? '').toString().trim();
      if (name.isNotEmpty) return CategoryPalette.shortName(name);
    }
    final fallback = (fallbackName ?? '').trim();
    if (fallback.isNotEmpty) return CategoryPalette.shortName(fallback);
    if (category != null) {
      final value = category.toString().trim();
      if (value.isNotEmpty) return CategoryPalette.shortName(value);
    }
    return 'TBD';
  }

  static String resolveTeamCategoryKey(Map<String, dynamic> team) {
    final enriched = (team['participantCategoryKey'] ?? '').toString().trim();
    if (enriched.isNotEmpty) return enriched;

    final category = team['category'];
    if (category is Map) {
      final key = resolveCategoryKey(category);
      if (key.isNotEmpty) return key;
    }
    if (category != null && category.toString().trim().isNotEmpty) {
      return category.toString().trim();
    }
    return (team['categoryName'] ?? '').toString().trim();
  }

  static String resolveTeamCategoryShortName(Map<String, dynamic> team) {
    final enriched = (team['participantCategoryShortName'] ?? '').toString().trim();
    if (enriched.isNotEmpty) return enriched;

    final category = team['category'];
    if (category is Map) {
      return resolveCategoryShortName(category);
    }
    final key = resolveTeamCategoryKey(team);
    if (key.isNotEmpty) return CategoryPalette.shortName(key);
    return 'TBD';
  }

  static List<TournamentAcademyGroup> groupTeamsByAcademy(
    List<Map<String, dynamic>> teams,
  ) {
    final byId = <String, List<Map<String, dynamic>>>{};
    final meta = <String, ({String name, String logo})>{};

    for (final team in teams) {
      final academyId = resolveAcademyId(team);
      if (academyId == null || academyId.isEmpty) continue;

      byId.putIfAbsent(academyId, () => []).add(team);

      final name = resolveAcademyName(team);
      final logo = resolveAcademyLogo(team);
      final current = meta[academyId];
      if (current == null) {
        meta[academyId] = (name: name, logo: logo);
      } else {
        meta[academyId] = (
          name: current.name.isNotEmpty ? current.name : name,
          logo: current.logo.isNotEmpty ? current.logo : logo,
        );
      }
    }

    final groups = <TournamentAcademyGroup>[];
    for (final entry in byId.entries) {
      final id = entry.key;
      final teamList = List<Map<String, dynamic>>.from(entry.value);
      final info = meta[id]!;
      groups.add(
        TournamentAcademyGroup(
          academyId: id,
          academyName: info.name,
          academyLogo: info.logo,
          teamCount: teamList.length,
          teams: teamList,
        ),
      );
    }

    groups.sort(
      (a, b) => a.academyName.toLowerCase().compareTo(b.academyName.toLowerCase()),
    );
    return groups;
  }

  static String resolveTeamId(Map<String, dynamic> team) {
    return (team['_id'] ?? team['id'] ?? '').toString().trim();
  }

  static String resolveTeamName(Map<String, dynamic> team) {
    return (team['name'] ?? team['shortName'] ?? 'Equipo').toString().trim();
  }

  static String resolveTeamLogo(Map<String, dynamic> team) {
    return (team['logo'] ?? team['thumb'] ?? '').toString().trim();
  }

  static List<Map<String, dynamic>> sortedTeams(List<Map<String, dynamic>> teams) {
    final copy = List<Map<String, dynamic>>.from(teams);
    copy.sort(
      (a, b) => resolveTeamName(a).toLowerCase().compareTo(
            resolveTeamName(b).toLowerCase(),
          ),
    );
    return copy;
  }

  static int countTeamsWithoutAcademyId(List<Map<String, dynamic>> teams) {
    var count = 0;
    for (final team in teams) {
      final academyId = resolveAcademyId(team);
      if (academyId == null || academyId.isEmpty) count++;
    }
    return count;
  }

  static String participantsSemanticsLabel({
    required String academyName,
    required int teamCount,
    String? categoryShortName,
  }) {
    final teams = teamCountLabel(teamCount);
    if (categoryShortName == null || categoryShortName.isEmpty) {
      return '$academyName, $teams participantes';
    }
    return '$academyName, $teams participantes en $categoryShortName';
  }

  static List<TournamentCategoryFilterOption> buildAvailableCategories(
    List<Map<String, dynamic>> teams,
    List<dynamic> tournamentCategoriesOrder,
  ) {
    final stats = <String, ({String name, String shortName, Set<String> academyIds, int teamCount})>{};

    for (final team in teams) {
      final key = resolveTeamCategoryKey(team);
      if (key.isEmpty) continue;

      final academyId = resolveAcademyId(team);
      final name = (team['participantCategoryName'] ?? key).toString().trim();
      final shortName = resolveTeamCategoryShortName(team);

      final current = stats[key];
      if (current == null) {
        stats[key] = (
          name: name.isNotEmpty ? name : key,
          shortName: shortName,
          academyIds: academyId != null && academyId.isNotEmpty
              ? {academyId}
              : <String>{},
          teamCount: 1,
        );
      } else {
        final academies = Set<String>.from(current.academyIds);
        if (academyId != null && academyId.isNotEmpty) {
          academies.add(academyId);
        }
        stats[key] = (
          name: current.name.isNotEmpty ? current.name : name,
          shortName: current.shortName.isNotEmpty ? current.shortName : shortName,
          academyIds: academies,
          teamCount: current.teamCount + 1,
        );
      }
    }

    final options = stats.entries
        .map(
          (entry) => TournamentCategoryFilterOption(
            key: entry.key,
            name: entry.value.name,
            shortName: entry.value.shortName,
            teamCount: entry.value.teamCount,
            academyCount: entry.value.academyIds.length,
          ),
        )
        .toList();

    _sortCategoryOptions(options, tournamentCategoriesOrder);
    return options;
  }

  static void _sortCategoryOptions(
    List<TournamentCategoryFilterOption> options,
    List<dynamic> tournamentCategoriesOrder,
  ) {
    final orderKeys = <String>[];
    for (final item in tournamentCategoriesOrder) {
      final key = resolveCategoryKey(item);
      if (key.isNotEmpty && !orderKeys.contains(key)) {
        orderKeys.add(key);
      }
    }

    options.sort((a, b) {
      final ai = orderKeys.indexOf(a.key);
      final bi = orderKeys.indexOf(b.key);
      if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
      if (ai >= 0) return -1;
      if (bi >= 0) return 1;
      return a.shortName.toLowerCase().compareTo(b.shortName.toLowerCase());
    });
  }

  static List<TournamentAcademyVisibleGroup> buildVisibleAcademies(
    List<TournamentAcademyGroup> allGroupedAcademies,
    String? selectedCategoryKey,
  ) {
    if (selectedCategoryKey == null) {
      return allGroupedAcademies
          .map(
            (group) => TournamentAcademyVisibleGroup(
              group: group,
              visibleTeams: group.teams,
              visibleTeamCount: group.teamCount,
            ),
          )
          .toList();
    }

    final visible = <TournamentAcademyVisibleGroup>[];
    for (final group in allGroupedAcademies) {
      final filtered = group.teams
          .where((team) => resolveTeamCategoryKey(team) == selectedCategoryKey)
          .toList();
      if (filtered.isEmpty) continue;
      visible.add(
        TournamentAcademyVisibleGroup(
          group: group,
          visibleTeams: filtered,
          visibleTeamCount: filtered.length,
        ),
      );
    }
    return visible;
  }

  static String academyCountLabel(int count) {
    if (count == 1) return '1 academia';
    return '$count academias';
  }

  static String participantsSummaryLabel({
    required int academyCount,
    required int teamCount,
    String? categoryShortName,
  }) {
    final academies = academyCountLabel(academyCount);
    final teams = teamCountLabel(teamCount);
    if (categoryShortName == null || categoryShortName.isEmpty) {
      return '$academies · $teams';
    }
    return '$academies · $teams en $categoryShortName';
  }

  static String categoryOptionSummary(TournamentCategoryFilterOption option) {
    return '${academyCountLabel(option.academyCount)} · ${teamCountLabel(option.teamCount)}';
  }

  static String? resolveAcademyId(Map<String, dynamic> team) {
    final academy = team['academy'];
    if (academy is Map) {
      final id = (academy['id'] ?? academy['_id'] ?? '').toString().trim();
      if (id.isNotEmpty) return id;
    }
    final flat = (team['academyId'] ?? '').toString().trim();
    if (flat.isNotEmpty) return flat;
    return null;
  }

  static String resolveAcademyName(Map<String, dynamic> team) {
    final academy = team['academy'];
    if (academy is Map) {
      final name = (academy['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return (team['academyName'] ?? '').toString().trim();
  }

  static String resolveAcademyLogo(Map<String, dynamic> team) {
    final academy = team['academy'];
    if (academy is Map) {
      return (academy['logo_url'] ?? academy['logo'] ?? academy['thumb'] ?? '')
          .toString()
          .trim();
    }
    return '';
  }

  static String teamCountLabel(int count) {
    if (count == 1) return '1 equipo';
    return '$count equipos';
  }

  static String teamCountBadgeLabel(int count) {
    if (count == 1) return '1 EQUIPO';
    return '$count EQUIPOS';
  }

  static Color resolveThemeAccent(dynamic theme) {
    if (theme is Map) {
      final map = Map<String, dynamic>.from(theme);
      final accent = TournamentCatalogHelpers.parseHexColor(
        (map['accent'] ?? '').toString(),
      );
      if (accent != null) return accent;
      final primary = TournamentCatalogHelpers.parseHexColor(
        (map['primary'] ?? '').toString(),
      );
      if (primary != null) return primary;
    }
    return AppTheme.brandTeal;
  }

  static String academyInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';

    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      final first = words[0];
      final second = words[1];
      if (first.isNotEmpty && second.isNotEmpty) {
        return '${first[0]}${second[0]}'.toUpperCase();
      }
    }

    final word = words.first;
    if (word.length <= 3) return word.toUpperCase();
    return word.substring(0, 2).toUpperCase();
  }

  static int gridCrossAxisCount(double width) {
    return width >= 600 ? 3 : 2;
  }
}
