import '../models/academy_profile_models.dart';

enum AcademyMatchOutcome {
  won,
  lost,
  tie,
  internal,
  pending,
}

/// Helpers para partidos en el perfil de academia.
class AcademyMatchHelpers {
  AcademyMatchHelpers._();

  static String formatMatchDate(DateTime? date) {
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static bool isInternalMatch(AcademyMatch match, String academyId) {
    final id = academyId.trim();
    if (id.isEmpty) return false;
    final homeId = match.home.academyId.trim();
    final visitorId = match.visitor.academyId.trim();
    return homeId.isNotEmpty &&
        visitorId.isNotEmpty &&
        homeId == id &&
        visitorId == id;
  }

  static AcademyMatchOutcome outcomeForAcademy(
    AcademyMatch match,
    String academyId,
  ) {
    if (isInternalMatch(match, academyId)) {
      return AcademyMatchOutcome.internal;
    }

    final homePts = match.home.points;
    final visitorPts = match.visitor.points;
    if (homePts == null || visitorPts == null) {
      return AcademyMatchOutcome.pending;
    }

    final id = academyId.trim();
    final homeId = match.home.academyId.trim();
    final visitorId = match.visitor.academyId.trim();
    final isHome = id.isNotEmpty && homeId == id;
    final isVisitor = id.isNotEmpty && visitorId == id;

    if (!isHome && !isVisitor) {
      return AcademyMatchOutcome.pending;
    }

    if (homePts == visitorPts) return AcademyMatchOutcome.tie;
    if (isHome) {
      return homePts > visitorPts
          ? AcademyMatchOutcome.won
          : AcademyMatchOutcome.lost;
    }
    return visitorPts > homePts
        ? AcademyMatchOutcome.won
        : AcademyMatchOutcome.lost;
  }

  static String outcomeLabel(AcademyMatchOutcome outcome) {
    switch (outcome) {
      case AcademyMatchOutcome.won:
        return 'GANADO';
      case AcademyMatchOutcome.lost:
        return 'PERDIDO';
      case AcademyMatchOutcome.tie:
        return 'EMPATE';
      case AcademyMatchOutcome.internal:
        return 'PARTIDO INTERNO';
      case AcademyMatchOutcome.pending:
        return '';
    }
  }

  static String? scoreLine(AcademyMatch match) {
    final homePts = match.home.points;
    final visitorPts = match.visitor.points;
    if (homePts == null || visitorPts == null) return null;
    return '$homePts — $visitorPts';
  }

  static List<String> upcomingMetaLines(AcademyMatch match) {
    final lines = <String>[];
    final date = formatMatchDate(match.date);
    if (date.isNotEmpty) lines.add(date);
    final field = (match.field ?? '').trim();
    if (field.isNotEmpty) lines.add(field);
    final venue = match.venueLabel();
    if (venue.isNotEmpty) lines.add(venue);
    return lines;
  }
}
