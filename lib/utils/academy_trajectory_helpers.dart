import '../models/academy_profile_models.dart';
import 'academy_profile_helpers.dart';

/// Helpers de presentación para el tab Trayectoria.
class AcademyTrajectoryHelpers {
  AcademyTrajectoryHelpers._();

  static Map<String, List<AcademyTournamentHistory>> groupHistoryByYear(
    List<AcademyTournamentHistory> history,
  ) {
    final grouped = <String, List<AcademyTournamentHistory>>{};
    for (final item in history) {
      final year = _yearLabel(item);
      grouped.putIfAbsent(year, () => <AcademyTournamentHistory>[]).add(item);
    }
    return grouped;
  }

  static List<String> sortedYears(Map<String, List<AcademyTournamentHistory>> grouped) {
    final years = grouped.keys.toList();
    years.sort((a, b) {
      final aNum = int.tryParse(a) ?? 0;
      final bNum = int.tryParse(b) ?? 0;
      if (aNum != 0 && bNum != 0) return bNum.compareTo(aNum);
      return b.compareTo(a);
    });
    return years;
  }

  static Map<String, List<AcademyHonorHistory>> groupHonorsByYear(
    List<AcademyHonorHistory> history,
  ) {
    final grouped = <String, List<AcademyHonorHistory>>{};
    for (final item in history) {
      final year = item.year.trim().isNotEmpty ? item.year.trim() : '—';
      grouped.putIfAbsent(year, () => <AcademyHonorHistory>[]).add(item);
    }
    return grouped;
  }

  static List<String> sortedHonorYears(
    Map<String, List<AcademyHonorHistory>> grouped,
  ) {
    final years = grouped.keys.toList();
    years.sort((a, b) {
      if (a == '—') return 1;
      if (b == '—') return -1;
      final aNum = int.tryParse(a) ?? 0;
      final bNum = int.tryParse(b) ?? 0;
      if (aNum != 0 && bNum != 0) return bNum.compareTo(aNum);
      return b.compareTo(a);
    });
    return years;
  }

  static String? statusLabel(String status) {
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case 'current':
        return 'EN CURSO';
      case 'upcoming':
        return 'PRÓXIMO';
      case 'completed':
        return 'FINALIZADO';
      default:
        return null;
    }
  }

  static String leagueYearLine(AcademyTournamentHistory item) {
    final league = item.tournament.league?.trim() ?? '';
    final year = _yearLabel(item);
    if (league.isNotEmpty && year.isNotEmpty) return '$league · $year';
    if (league.isNotEmpty) return league;
    return year;
  }

  static String teamCategoryLine(AcademyTournamentHistory item) {
    final teams = item.teamCount > 0 ? item.teamCount : resolvedTeams(item).length;
    final categories =
        item.categoryCount > 0 ? item.categoryCount : item.categories.length;
    if (teams > 0 && categories > 0) {
      return '$teams equipos · $categories categorías';
    }
    if (teams > 0) return '$teams equipos';
    if (categories > 0) return '$categories categorías';
    return '';
  }

  static String? recordCompactLabel(AcademyRecord record) {
    if (record.registeredMatches <= 0 && record.played <= 0) return null;
    final wins = record.wins;
    final losses = record.losses;
    if (wins == 0 && losses == 0) return null;
    return '$wins G · $losses P';
  }

  static String participationLine(AcademyTournamentHistory item) {
    final parts = <String>[];
    final resolvedTeamList = resolvedTeams(item);
    final teamCount = item.teamCount > 0 ? item.teamCount : resolvedTeamList.length;
    if (teamCount > 0) parts.add('$teamCount equipos');

    final categoryLabels = <String>{};
    for (final team in resolvedTeams(item)) {
      if (team.categoryShortName.trim().isNotEmpty) {
        categoryLabels.add(team.categoryShortName.trim());
      }
    }
    for (final category in item.categories) {
      if (category.shortName.trim().isNotEmpty) {
        categoryLabels.add(category.shortName.trim());
      }
    }
    if (item.legacyCategory != null &&
        item.legacyCategory!.shortName.trim().isNotEmpty) {
      categoryLabels.add(item.legacyCategory!.shortName.trim());
    }

    if (categoryLabels.isNotEmpty) {
      parts.add(categoryLabels.join(' · '));
    }

    return parts.join(' · ');
  }

  static bool hasExpandableContent(AcademyTournamentHistory item) {
    return resolvedTeams(item).isNotEmpty ||
        item.categories.isNotEmpty ||
        item.standings.isNotEmpty ||
        item.finals.isNotEmpty ||
        item.teamCount > 0 ||
        item.categoryCount > 0 ||
        item.legacyResult.trim().isNotEmpty;
  }

  static String stableItemKey(AcademyTournamentHistory item, int index) {
    final id = item.tournament.id.trim();
    if (id.isNotEmpty) return id;
    final year = _yearLabel(item);
    final name = item.name.trim().toLowerCase();
    return '${year}_${name}_$index';
  }

  static List<AcademyHonorHistory> honorsForTournament(
    AcademyTournamentHistory item,
    List<AcademyHonorHistory> honors,
  ) {
    final matched = honors
        .where((honor) => _tournamentMatchesHonor(item, honor))
        .toList();
    if (matched.isNotEmpty) return matched;

    final itemName = AcademyProfileHelpers.normalizeTournamentName(item.name);
    if (itemName.isEmpty) return matched;

    final byName = honors
        .where(
          (honor) =>
              AcademyProfileHelpers.normalizeTournamentName(
                honor.tournament.name,
              ) ==
              itemName,
        )
        .toList();
    if (byName.isEmpty) return matched;

    final byYear = byName.where((honor) => _yearsCompatible(item, honor)).toList();
    if (byYear.isNotEmpty) return byYear;
    if (byName.length == 1) return byName;

    return matched;
  }

  static List<AcademyHonorHistory> honorsForTeam(
    AcademyTournamentHistory item,
    AcademyHistoryTeam team,
    List<AcademyHonorHistory> honors,
  ) {
    final tournamentHonors = honorsForTournament(item, honors);
    final category = team.categoryShortName.trim().toLowerCase();

    return tournamentHonors.where((honor) {
      final honorCategory = honor.category.displayLabel().trim().toLowerCase();
      if (category.isNotEmpty && honorCategory.isNotEmpty) {
        return honorCategory == category;
      }
      return true;
    }).toList();
  }

  static bool _tournamentMatchesHonor(
    AcademyTournamentHistory item,
    AcademyHonorHistory honor,
  ) {
    final tournamentId = item.tournament.id.trim();
    final honorTournamentId = honor.tournament.id.trim();
    if (tournamentId.isNotEmpty &&
        honorTournamentId.isNotEmpty &&
        tournamentId == honorTournamentId) {
      return true;
    }

    final itemName = AcademyProfileHelpers.normalizeTournamentName(item.name);
    final honorName =
        AcademyProfileHelpers.normalizeTournamentName(honor.tournament.name);
    if (itemName.isEmpty || honorName.isEmpty) return false;

    if (itemName == honorName) return true;

    if (itemName.length >= 4 &&
        honorName.length >= 4 &&
        (itemName.contains(honorName) || honorName.contains(itemName))) {
      return _yearsCompatible(item, honor);
    }

    return false;
  }

  static bool _yearsCompatible(
    AcademyTournamentHistory item,
    AcademyHonorHistory honor,
  ) {
    final honorYear = honor.year.trim();
    if (honorYear.isEmpty) return true;

    final years = <String>{};
    final startYear = item.tournament.start?.year;
    if (startYear != null) years.add(startYear.toString());
    final endYear = item.tournament.end?.year;
    if (endYear != null) years.add(endYear.toString());
    if (item.legacyYear.trim().isNotEmpty) years.add(item.legacyYear.trim());
    final labelYear = _yearLabel(item);
    if (labelYear.isNotEmpty) years.add(labelYear);

    if (years.isEmpty) return true;
    return years.contains(honorYear);
  }

  static int effectiveChampionshipCount(
    AcademyTournamentHistory item,
    List<AcademyHonorHistory> honors,
  ) {
    if (item.championships > 0) return item.championships;

    final fromHonors = honorsForTournament(item, honors)
        .where(AcademyProfileHelpers.isHonorChampionship)
        .length;
    if (fromHonors > 0) return fromHonors;

    return _championshipsFromFinals(item);
  }

  static int effectiveRunnerUpCount(
    AcademyTournamentHistory item,
    List<AcademyHonorHistory> honors,
  ) {
    if (item.runnerUps > 0) return item.runnerUps;

    final fromHonors = honorsForTournament(item, honors)
        .where(AcademyProfileHelpers.isHonorRunnerUp)
        .length;
    if (fromHonors > 0) return fromHonors;

    return item.finals.where((finalItem) {
      return _isRunnerUpResult(finalItem.academyResult);
    }).length;
  }

  static List<String> championCategoryLabels(
    AcademyTournamentHistory item,
    List<AcademyHonorHistory> honors,
  ) {
    return _honorCategoryLabels(
      item,
      honors,
      fromFinal: _isChampionResult,
      fromHonor: AcademyProfileHelpers.isHonorChampionship,
    );
  }

  static List<String> runnerUpCategoryLabels(
    AcademyTournamentHistory item,
    List<AcademyHonorHistory> honors,
  ) {
    return _honorCategoryLabels(
      item,
      honors,
      fromFinal: _isRunnerUpResult,
      fromHonor: AcademyProfileHelpers.isHonorRunnerUp,
    );
  }

  static List<String> _honorCategoryLabels(
    AcademyTournamentHistory item,
    List<AcademyHonorHistory> honors, {
    required bool Function(String result) fromFinal,
    required bool Function(AcademyHonorHistory honor) fromHonor,
  }) {
    final seen = <String>{};
    final labels = <String>[];

    void add(String raw) {
      final label = raw.trim();
      if (label.isEmpty || seen.contains(label)) return;
      seen.add(label);
      labels.add(label);
    }

    for (final finalItem in item.finals) {
      if (fromFinal(finalItem.academyResult)) {
        add(finalItem.category.displayLabel());
      }
    }

    for (final honor in honorsForTournament(item, honors)) {
      if (fromHonor(honor)) {
        add(honor.category.displayLabel());
      }
    }

    return labels;
  }

  static bool _isChampionResult(String result) {
    final normalized = result.trim().toLowerCase();
    return normalized == 'champion' ||
        normalized.contains('campeon') ||
        normalized.contains('campeón');
  }

  static bool _isRunnerUpResult(String result) {
    final normalized = result.trim().toLowerCase();
    return normalized == 'runner_up' ||
        normalized.contains('runner') ||
        normalized.contains('subcampeon') ||
        normalized.contains('subcampeón');
  }

  static int _championshipsFromFinals(AcademyTournamentHistory item) {
    return item.finals.where((finalItem) {
      return _isChampionResult(finalItem.academyResult);
    }).length;
  }

  static String? legacyAchievementLabel(
    AcademyTournamentHistory item,
    List<AcademyHonorHistory> honors,
  ) {
    if (effectiveChampionshipCount(item, honors) > 0 ||
        effectiveRunnerUpCount(item, honors) > 0) {
      return null;
    }

    final legacy = item.legacyResult.trim();
    if (legacy.isNotEmpty) return legacy;

    final matched = honorsForTournament(item, honors);
    if (matched.isEmpty) return null;

    return matched
        .map(AcademyProfileHelpers.honorResultLabel)
        .where((label) => label.trim().isNotEmpty)
        .join(' · ');
  }

  static List<AcademyHistoryTeam> resolvedTeams(AcademyTournamentHistory item) {
    if (item.teams.isNotEmpty) return item.teams;

    final resolved = <AcademyHistoryTeam>[];
    final seen = <String>{};

    for (final standing in item.standings) {
      final name = standing.teamName.trim();
      if (name.isEmpty) continue;
      final key = '${name}_${standing.categoryName.trim()}';
      if (seen.contains(key)) continue;
      seen.add(key);
      resolved.add(
        AcademyHistoryTeam(
          id: key,
          name: name,
          categoryShortName: standing.categoryName.trim(),
          playersCount: 0,
        ),
      );
    }

    for (final finalItem in item.finals) {
      for (final teamName in [
        finalItem.championTeamName.trim(),
        finalItem.runnerUpTeamName.trim(),
      ]) {
        if (teamName.isEmpty) continue;
        final key = '${teamName}_${finalItem.category.displayLabel()}';
        if (seen.contains(key)) continue;
        seen.add(key);
        resolved.add(
          AcademyHistoryTeam(
            id: key,
            name: teamName,
            categoryShortName: finalItem.category.displayLabel(),
            playersCount: 0,
          ),
        );
      }
    }

    return resolved;
  }

  static bool isDefaultGroup(String group) {
    final normalized = group.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'default' ||
        normalized == 'general';
  }

  static String _yearLabel(AcademyTournamentHistory item) {
    if (item.tournament.start != null) {
      return item.tournament.start!.year.toString();
    }
    if (item.legacyYear.trim().isNotEmpty) return item.legacyYear.trim();
    return item.year;
  }
}
