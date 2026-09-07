import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/academy_profile_models.dart';
import '../../services/tournament_detail_route.dart';
import '../../utils/academy_trajectory_helpers.dart';
import '../../utils/academy_profile_view_data.dart';
import '../../utils/match_helpers.dart';

class AcademyProfileTrajectoryTab extends StatefulWidget {
  const AcademyProfileTrajectoryTab({
    super.key,
    required this.viewData,
    required this.tabController,
    required this.tabIndex,
  });

  final AcademyProfileViewData viewData;
  final TabController tabController;
  final int tabIndex;

  @override
  State<AcademyProfileTrajectoryTab> createState() =>
      _AcademyProfileTrajectoryTabState();
}

class _AcademyProfileTrajectoryTabState extends State<AcademyProfileTrajectoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final honorHistory = widget.viewData.context.honors.history;
    final grouped = widget.viewData.historyByYear;
    final years = widget.viewData.historyYearOrder;

    return AnimatedBuilder(
      animation: widget.tabController,
      builder: (context, _) {
        final isActive = widget.tabController.index == widget.tabIndex;
        return Builder(
          builder: (context) {
            final scrollView = CustomScrollView(
              key: const PageStorageKey<String>('academy_tab_trayectoria'),
              primary: isActive,
              slivers: [
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                if (years.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Aún no hay torneos históricos registrados en TOCHITOPRO.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final year = years[index];
                  final items = grouped[year] ?? <AcademyTournamentHistory>[];
                  return _TrajectoryYearTimeline(
                    year: year,
                    items: items,
                    honorHistory: honorHistory,
                    isLastYear: index == years.length - 1,
                    isFirstYear: index == 0,
                  );
                },
                childCount: years.length,
              ),
            ),
          ),
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
}

class _TrajectoryYearTimeline extends StatelessWidget {
  const _TrajectoryYearTimeline({
    required this.year,
    required this.items,
    required this.honorHistory,
    required this.isLastYear,
    required this.isFirstYear,
  });

  final String year;
  final List<AcademyTournamentHistory> items;
  final List<AcademyHonorHistory> honorHistory;
  final bool isLastYear;
  final bool isFirstYear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: isFirstYear ? 0 : 20, bottom: isLastYear ? 0 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              year,
              style: GoogleFonts.oswald(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _TrajectoryTimelineItem(
              item: items[i],
              honorHistory: honorHistory,
              isLastInYear: i == items.length - 1,
              isLastOverall: isLastYear && i == items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TrajectoryTimelineItem extends StatelessWidget {
  const _TrajectoryTimelineItem({
    required this.item,
    required this.honorHistory,
    required this.isLastInYear,
    required this.isLastOverall,
  });

  final AcademyTournamentHistory item;
  final List<AcademyHonorHistory> honorHistory;
  final bool isLastInYear;
  final bool isLastOverall;

  @override
  Widget build(BuildContext context) {
    final tournament = item.tournament;
    final logoUrl = MatchHelpers.resolveMediaUrl(tournament.logo);
    final imageUrl = MatchHelpers.resolveMediaUrl(tournament.img);
    final championCategories =
        AcademyTrajectoryHelpers.championCategoryLabels(item, honorHistory);
    final runnerUpCategories =
        AcademyTrajectoryHelpers.runnerUpCategoryLabels(item, honorHistory);
    final tournamentId = tournament.id.trim();
    final league = tournament.league?.trim() ?? '';
    final hasHonorFooter =
        championCategories.isNotEmpty || runnerUpCategories.isNotEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 28),
                  decoration: BoxDecoration(
                    color: AppTheme.brandTeal,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.brandTeal.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLastOverall)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppTheme.brandTeal.withValues(alpha: 0.22),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLastInYear ? 4 : 12,
              ),
              child: Material(
                color: AppTheme.navySurface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: tournamentId.isNotEmpty
                      ? () => Navigator.of(context).pushNamed(
                            TournamentDetailRoute.routeFor(tournamentId),
                          )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 132),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TrajectoryTournamentThumb(
                                logoUrl: logoUrl,
                                imageUrl: imageUrl,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.oswald(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                    ),
                                    if (league.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        league,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: Colors.white.withValues(alpha: 0.42),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasHonorFooter) ...[
                          const SizedBox(height: 14),
                          Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (championCategories.isNotEmpty)
                                  _TrajectoryHonorFooterRow(
                                    icon: Icons.emoji_events_rounded,
                                    iconColor: const Color(0xFFD4AF37),
                                    categories: championCategories,
                                  ),
                                if (championCategories.isNotEmpty &&
                                    runnerUpCategories.isNotEmpty)
                                  const SizedBox(height: 8),
                                if (runnerUpCategories.isNotEmpty)
                                  _TrajectoryHonorFooterRow(
                                    icon: Icons.military_tech_rounded,
                                    iconColor: Colors.white.withValues(alpha: 0.42),
                                    categories: runnerUpCategories,
                                  ),
                              ],
                            ),
                          ),
                        ] else
                          const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrajectoryTournamentThumb extends StatelessWidget {
  const _TrajectoryTournamentThumb({
    required this.logoUrl,
    required this.imageUrl,
  });

  final String logoUrl;
  final String imageUrl;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    if (logoUrl.isNotEmpty) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: AppTheme.navyElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        padding: const EdgeInsets.all(8),
        child: CachedNetworkImage(
          imageUrl: logoUrl,
          fit: BoxFit.contain,
          errorWidget: (_, _, _) => _buildImageAvatar(),
          placeholder: (_, _) => const _TrajectoryMediaFallback(compact: true),
        ),
      );
    }

    return _buildImageAvatar();
  }

  Widget _buildImageAvatar() {
    if (imageUrl.isEmpty) {
      return SizedBox(
        width: _size,
        height: _size,
        child: const _TrajectoryMediaFallback(compact: true),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: _size,
        height: _size,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => const _TrajectoryMediaFallback(compact: true),
          placeholder: (_, _) => const _TrajectoryMediaFallback(compact: true),
        ),
      ),
    );
  }
}

class _TrajectoryHonorFooterRow extends StatelessWidget {
  const _TrajectoryHonorFooterRow({
    required this.icon,
    required this.iconColor,
    required this.categories,
  });

  final IconData icon;
  final Color iconColor;
  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            categories.join(' · '),
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrajectoryMediaFallback extends StatelessWidget {
  const _TrajectoryMediaFallback({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 56 : 72,
      height: compact ? 56 : 72,
      decoration: BoxDecoration(
        color: AppTheme.navyElevated,
        borderRadius: compact ? BorderRadius.circular(28) : BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Icon(
        Icons.emoji_events_outlined,
        color: Colors.white.withValues(alpha: 0.22),
        size: compact ? 24 : 32,
      ),
    );
  }
}
