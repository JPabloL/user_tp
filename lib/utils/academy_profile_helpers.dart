import '../models/academy_profile_models.dart';

enum AcademyTournamentLifecycle { active, upcoming, completed }

/// Helpers de presentación para el perfil de academia.
class AcademyProfileHelpers {
  AcademyProfileHelpers._();

  static const int shortDescriptionMaxLength = 120;

  static bool isShortDescription(String description) {
    final text = description.trim();
    if (text.isEmpty) return false;
    return text.length <= shortDescriptionMaxLength;
  }

  static String formatTournamentDates(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    if (start != null && end != null) {
      return '${_formatDate(start)} – ${_formatDate(end)}';
    }
    if (start != null) return 'Desde ${_formatDate(start)}';
    return 'Hasta ${_formatDate(end!)}';
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String formatWinPctLabel(double winPctPercent) {
    if (winPctPercent <= 0) return '';
    final value = winPctPercent > 1 ? winPctPercent : winPctPercent * 100;
    final formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$formatted% de victorias';
  }

  static bool shouldShowWinPct(AcademyRecord record) {
    return record.registeredMatches >= 5 && record.winPctPercent > 0;
  }

  static List<AcademyTournamentHistory> upcomingNotInCurrent(
    AcademyTournaments tournaments,
  ) {
    final currentIds = tournaments.current
        .map((t) => t.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return tournaments.upcoming
        .where((t) => !currentIds.contains(t.id.trim()))
        .toList();
  }

  /// Torneos actuales y próximos para el bloque «Próximamente» del resumen.
  static List<AcademyTournamentHistory> upcomingAndCurrentTournaments(
    AcademyTournaments tournaments,
  ) {
    final seen = <String>{};
    final merged = <AcademyTournamentHistory>[];

    void add(AcademyTournamentHistory item) {
      final id = item.id.trim();
      if (id.isNotEmpty && seen.contains(id)) return;
      if (id.isNotEmpty) seen.add(id);
      merged.add(item);
    }

    for (final item in tournaments.current) {
      add(item);
    }
    for (final item in tournaments.upcoming) {
      add(item);
    }
    return merged;
  }

  /// Fecha más antigua de participación en torneos (current, upcoming, history).
  static DateTime? oldestTournamentParticipationDate(
    AcademyProfileContext context,
  ) {
    DateTime? oldest;

    void consider(DateTime? date) {
      if (date == null) return;
      if (oldest == null || date.isBefore(oldest!)) {
        oldest = date;
      }
    }

    for (final item in context.tournaments.current) {
      consider(item.tournament.start);
    }
    for (final item in context.tournaments.upcoming) {
      consider(item.tournament.start);
    }
    for (final item in context.tournaments.history) {
      consider(item.tournament.start);
      final yearText = item.legacyYear.trim();
      final year = int.tryParse(yearText);
      if (year != null && year > 1900) {
        consider(DateTime(year, 1, 1));
      }
    }

    consider(context.summary.firstParticipationDate);
    consider(context.summary.registeredSince);

    return oldest;
  }

  static String formatActiveSinceLabel(DateTime date) {
    return 'Activo en TOCHITOPRO desde ${_monthYearLabel(date)}';
  }

  static String formatTournamentStartLabel(DateTime? start) {
    if (start == null) return '';
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return 'Inicio: ${start.day} ${months[start.month - 1]} ${start.year}';
  }

  static String _monthYearLabel(DateTime date) {
    const months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
    ];
    return '${months[date.month - 1]}-${date.year}';
  }

  /// Estado editorial del torneo para chips en resumen.
  static AcademyTournamentLifecycle participationLifecycle(
    AcademyTournamentHistory item,
  ) {
    final tournament = item.tournament;
    final status = tournament.status.trim().toLowerCase();

    if (status == 'upcoming' ||
        status == 'scheduled' ||
        status == 'pending' ||
        status == 'proximo' ||
        status == 'próximo') {
      return AcademyTournamentLifecycle.upcoming;
    }

    if (status == 'completed' ||
        status == 'finished' ||
        status == 'ended' ||
        status == 'past') {
      return AcademyTournamentLifecycle.completed;
    }

    if (status == 'current' || status == 'active' || tournament.active) {
      final byDates = lifecycleFromDates(tournament.start, tournament.end);
      if (byDates == AcademyTournamentLifecycle.completed) {
        return AcademyTournamentLifecycle.completed;
      }
      return AcademyTournamentLifecycle.active;
    }

    return lifecycleFromDates(tournament.start, tournament.end);
  }

  static AcademyTournamentLifecycle lifecycleFromDates(
    DateTime? start,
    DateTime? end,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (start == null) {
      return AcademyTournamentLifecycle.upcoming;
    }

    final startDay = DateTime(start.year, start.month, start.day);
    if (today.isBefore(startDay)) {
      return AcademyTournamentLifecycle.upcoming;
    }

    if (end != null) {
      final endDay = DateTime(end.year, end.month, end.day);
      if (today.isAfter(endDay)) {
        return AcademyTournamentLifecycle.completed;
      }
    }

    return AcademyTournamentLifecycle.active;
  }

  static List<AcademyHonorHistory> recentHonorHighlights(
    List<AcademyHonorHistory> history, {
    int maxItems = 3,
  }) {
    if (history.isEmpty) return <AcademyHonorHistory>[];

    final championships =
        history.where((item) => item.isChampionship).toList();
    final runnerUps = history.where((item) => item.isRunnerUp).toList();
    final others = history
        .where((item) => !item.isChampionship && !item.isRunnerUp)
        .toList();

    final picked = <AcademyHonorHistory>[];
    for (final item in championships) {
      if (picked.length >= maxItems) break;
      picked.add(item);
    }
    if (picked.length < maxItems) {
      for (final item in runnerUps) {
        if (picked.length >= maxItems) break;
        if (!picked.contains(item)) picked.add(item);
      }
    }
    if (picked.length < maxItems) {
      for (final item in others) {
        if (picked.length >= maxItems) break;
        if (!picked.contains(item)) picked.add(item);
      }
    }
    return picked;
  }

  static String honorResultLabel(AcademyHonorHistory item) {
    final result = item.result.trim();
    if (result.isNotEmpty) return result.toUpperCase();
    if (item.isChampionship) return 'CAMPEÓN';
    if (item.isRunnerUp) return 'SUBCAMPEÓN';
    return 'FINAL';
  }

  static String honorIconFor(AcademyHonorHistory item) {
    if (item.isChampionship) return '🏆';
    if (item.isRunnerUp) return '🥈';
    return '🏅';
  }

  static bool participationMatchesSource(
    AcademyTournamentHistory item,
    String? sourceTournamentId,
  ) {
    final source = sourceTournamentId?.trim() ?? '';
    if (source.isEmpty) return false;
    final id = item.id.trim();
    final tournamentId = item.tournament.id.trim();
    return id == source || tournamentId == source;
  }

  static String teamCategoryLine(int teamCount, int categoryCount) {
    final teams = teamCount > 0 ? '$teamCount equipos' : null;
    final categories =
        categoryCount > 0 ? '$categoryCount categorías' : null;
    if (teams != null && categories != null) return '$teams · $categories';
    return teams ?? categories ?? '';
  }

  static int participationTeamCount(AcademyTournamentHistory item) {
    if (item.teamCount > 0) return item.teamCount;
    if (item.teams.isNotEmpty) return item.teams.length;
    return 0;
  }

  static String participationTeamCountLabel(AcademyTournamentHistory item) {
    final count = participationTeamCount(item);
    if (count <= 0) return '';
    return count == 1 ? '1 equipo' : '$count equipos';
  }

  /// Normaliza nombres de torneo para comparación tolerante.
  static String normalizeTournamentName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[–—\-_/]+'), ' ')
        .replaceAll(RegExp(r'[^\w\sáéíóúüñ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool isHonorChampionship(AcademyHonorHistory honor) {
    if (honor.isChampionship) return true;
    final result = honor.result.trim().toLowerCase();
    if (result.contains('campeon') || result.contains('campeón')) return true;
    if (result.contains('1er') || result.contains('primer')) return true;
    final type = honor.type.trim().toLowerCase();
    return type.contains('champion') ||
        type.contains('campeon') ||
        type == 'title' ||
        type == 'first';
  }

  static bool isHonorRunnerUp(AcademyHonorHistory honor) {
    if (honor.isRunnerUp) return true;
    final result = honor.result.trim().toLowerCase();
    return result.contains('subcampeon') || result.contains('subcampeón');
  }
}
