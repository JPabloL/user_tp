import '../models/academy_profile_models.dart';
import 'academy_profile_helpers.dart';
import 'academy_trajectory_helpers.dart';

/// Datos derivados memoizados para el perfil (evita recálculos en cada build).
class AcademyProfileViewData {
  AcademyProfileViewData(this.context)
      : hasParticipation = _computeHasParticipation(context),
        upcomingTournamentsNotInCurrent =
            AcademyProfileHelpers.upcomingNotInCurrent(context.tournaments),
        upcomingAndCurrentTournaments =
            AcademyProfileHelpers.upcomingAndCurrentTournaments(
              context.tournaments,
            ),
        oldestParticipationDate =
            AcademyProfileHelpers.oldestTournamentParticipationDate(context),
        honorHighlights =
            AcademyProfileHelpers.recentHonorHighlights(context.honors.history),
        historyByYear = AcademyTrajectoryHelpers.groupHistoryByYear(
          context.tournaments.history,
        ),
        historyYearOrder = AcademyTrajectoryHelpers.sortedYears(
          AcademyTrajectoryHelpers.groupHistoryByYear(
            context.tournaments.history,
          ),
        ),
        honorsByYear = AcademyTrajectoryHelpers.groupHonorsByYear(
          context.honors.history,
        ),
        honorYearOrder = AcademyTrajectoryHelpers.sortedHonorYears(
          AcademyTrajectoryHelpers.groupHonorsByYear(context.honors.history),
        ),
        sortedYearStats = _sortYearStats(context.yearStats);

  final AcademyProfileContext context;
  final bool hasParticipation;
  final List<AcademyTournamentHistory> upcomingTournamentsNotInCurrent;
  final List<AcademyTournamentHistory> upcomingAndCurrentTournaments;
  final DateTime? oldestParticipationDate;
  final List<AcademyHonorHistory> honorHighlights;
  final Map<String, List<AcademyTournamentHistory>> historyByYear;
  final List<String> historyYearOrder;
  final Map<String, List<AcademyHonorHistory>> honorsByYear;
  final List<String> honorYearOrder;
  final List<AcademyYearStats> sortedYearStats;

  String get academyId => context.academy.id;

  static bool _computeHasParticipation(AcademyProfileContext context) {
    final live = context.liveSummary;
    if (live.currentTeams > 0 || live.upcomingTeams > 0) return true;
    if (live.currentTournaments > 0 || live.upcomingTournaments > 0) return true;

    final record = context.record.overall;
    if (record.played > 0 || record.registeredMatches > 0) return true;
    if (context.tournaments.current.isNotEmpty) return true;
    if (context.tournaments.upcoming.isNotEmpty) return true;
    if (context.tournaments.history.isNotEmpty) return true;
    if (context.matches.upcoming.isNotEmpty) return true;
    if (context.matches.recent.isNotEmpty) return true;
    if (context.categoryStats.isNotEmpty) return true;
    if (context.honors.history.isNotEmpty) return true;
    if (context.summary.championships > 0) return true;
    if (context.summary.tournaments > 0) return true;
    return false;
  }

  static List<AcademyYearStats> _sortYearStats(List<AcademyYearStats> stats) {
    final sorted = List<AcademyYearStats>.from(stats);
    sorted.sort((a, b) {
      final aNum = int.tryParse(a.year) ?? 0;
      final bNum = int.tryParse(b.year) ?? 0;
      if (aNum != 0 && bNum != 0) return bNum.compareTo(aNum);
      return b.year.compareTo(a.year);
    });
    return sorted;
  }
}
