import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/academy_profile_models.dart';
import '../../services/match_detail_route.dart';
import '../../utils/academy_match_helpers.dart';
import '../../utils/match_helpers.dart';
import 'academy_profile_sections.dart';

class AcademyProfileMatchesSections extends StatelessWidget {
  const AcademyProfileMatchesSections({
    super.key,
    required this.academyId,
    required this.upcoming,
    required this.recent,
    this.fadeDelayMs = 0,
  });

  final String academyId;
  final List<AcademyMatch> upcoming;
  final List<AcademyMatch> recent;
  final int fadeDelayMs;

  static const int previewLimit = 3;

  @override
  Widget build(BuildContext context) {
    if (upcoming.isEmpty && recent.isEmpty) {
      return const SizedBox.shrink();
    }

    return AcademyProfileFadeIn(
      delayMs: fadeDelayMs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (upcoming.isNotEmpty) ...[
            AcademyProfileSectionTitle(
              title: 'Próximos partidos',
              actionLabel: upcoming.length > previewLimit ? 'Ver todos' : null,
              onAction: upcoming.length > previewLimit
                  ? () => _openAllSheet(
                        context,
                        title: 'Próximos partidos',
                        matches: upcoming,
                        isRecent: false,
                      )
                  : null,
            ),
            const SizedBox(height: 14),
            for (final match in upcoming.take(previewLimit))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _UpcomingMatchRow(
                  match: match,
                  onTap: () => _openMatch(context, match),
                ),
              ),
            if (recent.isNotEmpty) const SizedBox(height: 18),
          ],
          if (recent.isNotEmpty) ...[
            AcademyProfileSectionTitle(
              title: 'Últimos resultados',
              actionLabel: recent.length > previewLimit ? 'Ver todos' : null,
              onAction: recent.length > previewLimit
                  ? () => _openAllSheet(
                        context,
                        title: 'Últimos resultados',
                        matches: recent,
                        isRecent: true,
                      )
                  : null,
            ),
            const SizedBox(height: 14),
            for (final match in recent.take(previewLimit))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecentMatchRow(
                  match: match,
                  academyId: academyId,
                  onTap: () => _openMatch(context, match),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _openMatch(BuildContext context, AcademyMatch match) {
    final id = match.id.trim();
    if (id.isEmpty) return;
    Navigator.of(context).pushNamed(
      MatchDetailRoute.routeFor(id),
      arguments: MatchDetailRouteArgs(matchId: id),
    );
  }

  void _openAllSheet(
    BuildContext context, {
    required String title,
    required List<AcademyMatch> matches,
    required bool isRecent,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.navyPrimary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          style: GoogleFonts.oswald(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: matches.length,
                    itemBuilder: (_, index) {
                      final match = matches[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: isRecent
                            ? _RecentMatchRow(
                                match: match,
                                academyId: academyId,
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  _openMatch(context, match);
                                },
                              )
                            : _UpcomingMatchRow(
                                match: match,
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  _openMatch(context, match);
                                },
                              ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _UpcomingMatchRow extends StatelessWidget {
  const _UpcomingMatchRow({
    required this.match,
    this.onTap,
  });

  final AcademyMatch match;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = AcademyMatchHelpers.upcomingMetaLines(match);
    final category = (match.categoryName ?? '').trim();

    return _MatchCardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (category.isNotEmpty)
            Text(
              category.toUpperCase(),
              style: GoogleFonts.inter(
                color: AppTheme.brandTeal.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              meta.join(' · '),
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _TeamsFaceoffRow(
            homeName: match.home.teamName,
            homeLogo: match.home.logo,
            visitorName: match.visitor.teamName,
            visitorLogo: match.visitor.logo,
          ),
        ],
      ),
    );
  }
}

class _RecentMatchRow extends StatelessWidget {
  const _RecentMatchRow({
    required this.match,
    required this.academyId,
    this.onTap,
  });

  final AcademyMatch match;
  final String academyId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final outcome = AcademyMatchHelpers.outcomeForAcademy(match, academyId);
    final outcomeLabel = AcademyMatchHelpers.outcomeLabel(outcome);
    final score = AcademyMatchHelpers.scoreLine(match);
    final category = (match.categoryName ?? '').trim();
    final date = AcademyMatchHelpers.formatMatchDate(match.date);

    return _MatchCardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    if (category.isNotEmpty) category.toUpperCase(),
                    if (date.isNotEmpty) date,
                  ].join(' · '),
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ),
              if (outcomeLabel.isNotEmpty)
                Text(
                  outcomeLabel,
                  style: GoogleFonts.inter(
                    color: _outcomeColor(outcome),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TeamSide(
                  name: match.home.teamName,
                  logo: match.home.logo,
                  alignEnd: false,
                ),
              ),
              if (score != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    score,
                    style: GoogleFonts.oswald(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Expanded(
                child: _TeamSide(
                  name: match.visitor.teamName,
                  logo: match.visitor.logo,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _outcomeColor(AcademyMatchOutcome outcome) {
    switch (outcome) {
      case AcademyMatchOutcome.won:
        return AppTheme.brandTeal.withValues(alpha: 0.9);
      case AcademyMatchOutcome.lost:
        return Colors.white.withValues(alpha: 0.42);
      case AcademyMatchOutcome.tie:
        return Colors.white.withValues(alpha: 0.55);
      case AcademyMatchOutcome.internal:
        return Colors.white.withValues(alpha: 0.5);
      case AcademyMatchOutcome.pending:
        return Colors.white.withValues(alpha: 0.35);
    }
  }
}

class _MatchCardShell extends StatelessWidget {
  const _MatchCardShell({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.navySurface.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TeamsFaceoffRow extends StatelessWidget {
  const _TeamsFaceoffRow({
    required this.homeName,
    required this.homeLogo,
    required this.visitorName,
    required this.visitorLogo,
  });

  final String homeName;
  final String homeLogo;
  final String visitorName;
  final String visitorLogo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _TeamSide(name: homeName, logo: homeLogo)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'VS',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.28),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: _TeamSide(
            name: visitorName,
            logo: visitorLogo,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _TeamSide extends StatelessWidget {
  const _TeamSide({
    required this.name,
    required this.logo,
    this.alignEnd = false,
  });

  final String name;
  final String logo;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final logoUrl = MatchHelpers.resolveMediaUrl(logo);

    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!alignEnd) ...[
          _TeamLogo(logoUrl: logoUrl),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            name.trim().isNotEmpty ? name : 'Equipo',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
        if (alignEnd) ...[
          const SizedBox(width: 8),
          _TeamLogo(logoUrl: logoUrl),
        ],
      ],
    );
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.logoUrl});

  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: logoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => _TeamLogoFallback(),
              placeholder: (_, __) => _TeamLogoFallback(),
            )
          : _TeamLogoFallback(),
    );
  }
}

class _TeamLogoFallback extends StatelessWidget {
  const _TeamLogoFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.navyElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.sports_football_outlined,
        size: 16,
        color: Colors.white.withValues(alpha: 0.2),
      ),
    );
  }
}
