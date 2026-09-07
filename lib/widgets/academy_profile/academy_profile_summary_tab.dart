import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/academy_profile_models.dart';
import '../../utils/academy_profile_view_data.dart';
import '../../services/tournament_detail_route.dart';
import '../../utils/academy_profile_helpers.dart';
import '../../utils/match_helpers.dart';
import 'academy_profile_hero.dart';
import 'academy_profile_matches_sections.dart';
import 'academy_profile_sections.dart';

class AcademyProfileSummaryTab extends StatefulWidget {
  const AcademyProfileSummaryTab({
    super.key,
    required this.viewData,
    this.sourceTournamentId,
    required this.tabController,
    required this.tabIndex,
  });

  final AcademyProfileViewData viewData;
  final String? sourceTournamentId;
  final TabController tabController;
  final int tabIndex;

  @override
  State<AcademyProfileSummaryTab> createState() =>
      _AcademyProfileSummaryTabState();
}

class _AcademyProfileSummaryTabState extends State<AcademyProfileSummaryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final data = widget.viewData.context;
    final record = data.record.overall;
    final activeSince = widget.viewData.oldestParticipationDate;
    final activeSinceLabel = activeSince != null
        ? AcademyProfileHelpers.formatActiveSinceLabel(activeSince)
        : null;
    final upcomingAndCurrent = widget.viewData.upcomingAndCurrentTournaments;

    return AnimatedBuilder(
      animation: widget.tabController,
      builder: (context, _) {
        final isActive = widget.tabController.index == widget.tabIndex;
        return Builder(
          builder: (context) {
            final scrollView = CustomScrollView(
              key: const PageStorageKey<String>('academy_tab_resumen'),
              primary: isActive,
              slivers: [
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                SliverToBoxAdapter(
          child: AcademyProfileDescriptionStrip(
            description: data.academy.description,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: AcademyProfileFadeIn(
              child: _SummaryHighlightsStrip(
                championships: data.summary.championships,
                runnerUps: data.summary.runnerUps,
                activeSinceLabel: activeSinceLabel,
                tournaments: data.summary.tournaments,
                matches: record.registeredMatches,
                wins: record.wins,
              ),
            ),
          ),
        ),
        if (!widget.viewData.hasParticipation)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: AcademyProfileFadeIn(
                delayMs: 30,
                child: Text(
                  'Esta academia aún no tiene participaciones registradas en TOCHITOPRO.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
        if (upcomingAndCurrent.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
            sliver: SliverToBoxAdapter(
              child: AcademyProfileFadeIn(
                delayMs: 60,
                child: _ParticipatingTournamentsCarousel(
                  items: upcomingAndCurrent,
                  sourceTournamentId: widget.sourceTournamentId,
                  onItemTap: (item) => _openTournament(context, item),
                ),
              ),
            ),
          ),
        if (data.matches.upcoming.isNotEmpty || data.matches.recent.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            sliver: SliverToBoxAdapter(
              child: AcademyProfileMatchesSections(
                academyId: data.academy.id,
                upcoming: data.matches.upcoming,
                recent: data.matches.recent,
                fadeDelayMs: 120,
              ),
            ),
          ),
        if (data.leagues.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            sliver: SliverToBoxAdapter(
              child: AcademyProfileFadeIn(
                delayMs: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AcademyProfileSectionTitle(
                      title: 'Ligas y organizaciones',
                    ),
                    const SizedBox(height: 14),
                    for (final league in data.leagues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _LeagueCompactRow(league: league),
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            );
            if (!isActive) {
              return PrimaryScrollController.none(child: scrollView);
            }
            return scrollView;
          },
        );
      },
    );
  }

  void _openTournament(
    BuildContext context,
    AcademyTournamentHistory item,
  ) {
    final id = item.tournament.id.trim();
    if (id.isEmpty) return;
    Navigator.of(context).pushNamed(TournamentDetailRoute.routeFor(id));
  }
}

class _SummaryHighlightsStrip extends StatelessWidget {
  const _SummaryHighlightsStrip({
    required this.championships,
    required this.runnerUps,
    this.activeSinceLabel,
    required this.tournaments,
    required this.matches,
    required this.wins,
  });

  final int championships;
  final int runnerUps;
  final String? activeSinceLabel;
  final int tournaments;
  final int matches;
  final int wins;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.navySurface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PrimaryStatCell(
                        value: championships,
                        label: 'CAMPEONATOS',
                        semanticsLabel: '$championships campeonatos',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 44,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    Expanded(
                      child: _PrimaryStatCell(
                        value: runnerUps,
                        label: 'SUBCAMPEONATOS',
                        semanticsLabel: '$runnerUps subcampeonatos',
                      ),
                    ),
                  ],
                ),
                if (activeSinceLabel != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    activeSinceLabel!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppTheme.brandTeal.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryStatCell(
                        value: tournaments,
                        label: 'Torneos',
                      ),
                    ),
                    Expanded(
                      child: _SecondaryStatCell(
                        value: matches,
                        label: 'Partidos',
                      ),
                    ),
                    Expanded(
                      child: _SecondaryStatCell(
                        value: wins,
                        label: 'Victorias',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryStatCell extends StatelessWidget {
  const _PrimaryStatCell({
    required this.value,
    required this.label,
    required this.semanticsLabel,
  });

  final int value;
  final String label;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: GoogleFonts.oswald(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryStatCell extends StatelessWidget {
  const _SecondaryStatCell({
    required this.value,
    required this.label,
  });

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      child: Column(
        children: [
          Text(
            value.toString(),
            style: GoogleFonts.oswald(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipatingTournamentsCarousel extends StatefulWidget {
  const _ParticipatingTournamentsCarousel({
    required this.items,
    this.sourceTournamentId,
    required this.onItemTap,
  });

  final List<AcademyTournamentHistory> items;
  final String? sourceTournamentId;
  final void Function(AcademyTournamentHistory item) onItemTap;

  @override
  State<_ParticipatingTournamentsCarousel> createState() =>
      _ParticipatingTournamentsCarouselState();
}

class _ParticipatingTournamentsCarouselState
    extends State<_ParticipatingTournamentsCarousel> {
  static const double _carouselHeight = 136.0;

  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ParticipatingTournamentsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentPage >= widget.items.length) {
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: AcademyProfileSectionTitle(title: 'Participando en:'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: _carouselHeight,
          child: PageView.builder(
            controller: _pageController,
            padEnds: false,
            itemCount: widget.items.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 20 : 8,
                  right: index == widget.items.length - 1 ? 20 : 8,
                ),
                child: _ParticipatingTournamentCard(
                  item: item,
                  isSourceTournament: AcademyProfileHelpers
                      .participationMatchesSource(
                    item,
                    widget.sourceTournamentId,
                  ),
                  onTap: () => widget.onItemTap(item),
                ),
              );
            },
          ),
        ),
        if (widget.items.length > 1) ...[
          const SizedBox(height: 10),
          _CarouselPageIndicator(
            count: widget.items.length,
            currentIndex: _currentPage,
          ),
        ],
      ],
    );
  }
}

class _CarouselPageIndicator extends StatelessWidget {
  const _CarouselPageIndicator({
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppTheme.brandTeal : Colors.white24,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

class _ParticipatingTournamentCard extends StatelessWidget {
  const _ParticipatingTournamentCard({
    required this.item,
    this.isSourceTournament = false,
    this.onTap,
  });

  final AcademyTournamentHistory item;
  final bool isSourceTournament;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tournament = item.tournament;
    final logoUrl = MatchHelpers.resolveMediaUrl(tournament.logo);
    final lifecycle = AcademyProfileHelpers.participationLifecycle(item);
    final startLabel =
        AcademyProfileHelpers.formatTournamentStartLabel(tournament.start);
    final teamCountLabel =
        AcademyProfileHelpers.participationTeamCountLabel(item);

    return Material(
      color: AppTheme.navySurface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSourceTournament
                  ? AppTheme.brandTeal.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                ),
                child: SizedBox(
                  width: 96,
                  height: 134,
                  child: ColoredBox(
                    color: AppTheme.navyElevated,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: logoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: logoUrl,
                              fit: BoxFit.contain,
                              errorWidget: (_, _, _) =>
                                  const _TournamentLogoFallback(),
                              placeholder: (_, _) =>
                                  const _TournamentLogoFallback(),
                            )
                          : const _TournamentLogoFallback(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (lifecycle == AcademyTournamentLifecycle.active)
                            const _TournamentStatusChip(
                              label: 'ACTIVO',
                              color: AppTheme.brandTeal,
                            )
                          else if (lifecycle ==
                              AcademyTournamentLifecycle.upcoming)
                            const _TournamentStatusChip(
                              label: 'PRÓXIMAMENTE',
                              color: Colors.white70,
                            ),
                          if (isSourceTournament) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.brandTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color:
                                      AppTheme.brandTeal.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                'ESTE TORNEO',
                                style: GoogleFonts.inter(
                                  color: AppTheme.brandTeal,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tournament.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.oswald(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      if (startLabel.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          startLabel,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (teamCountLabel.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.groups_outlined,
                              size: 14,
                              color: AppTheme.brandTeal.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              teamCountLabel,
                              style: GoogleFonts.inter(
                                color: AppTheme.brandTeal.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TournamentStatusChip extends StatelessWidget {
  const _TournamentStatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TournamentLogoFallback extends StatelessWidget {
  const _TournamentLogoFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.emoji_events_outlined,
        color: Colors.white.withValues(alpha: 0.22),
        size: 32,
      ),
    );
  }
}

class _LeagueCompactRow extends StatelessWidget {
  const _LeagueCompactRow({required this.league});

  final AcademyLeague league;

  @override
  Widget build(BuildContext context) {
    final logoUrl = MatchHelpers.resolveMediaUrl(league.logo);
    final countLabel = league.tournamentCount > 0
        ? '${league.tournamentCount} torneos'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.navySurface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          if (logoUrl.isNotEmpty)
            SizedBox(
              width: 36,
              height: 36,
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                placeholder: (_, __) => const SizedBox.shrink(),
              ),
            ),
          if (logoUrl.isNotEmpty) const SizedBox(width: 12),
          Expanded(
            child: Text(
              league.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (countLabel.isNotEmpty)
            Text(
              countLabel,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
