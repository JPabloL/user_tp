import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/tournament_participants_helpers.dart';
import 'tournament_academy_grid_item.dart';
import 'tournament_academy_teams_sheet.dart';
import 'tournament_participants_filter.dart';
import 'tournament_participants_states.dart';

class TournamentParticipantsSection extends StatefulWidget {
  const TournamentParticipantsSection({
    super.key,
    required this.api,
    required this.teams,
    required this.resolveMediaUrl,
    this.tournamentTheme,
    this.tournamentCategories = const [],
    this.isRefreshing = false,
    this.onViewAcademy,
  });

  final ApiService api;
  final List<Map<String, dynamic>> teams;
  final String Function(String) resolveMediaUrl;
  final Map<String, dynamic>? tournamentTheme;
  final List<dynamic> tournamentCategories;
  final bool isRefreshing;
  final void Function(String academyId, String academyName)? onViewAcademy;

  @override
  State<TournamentParticipantsSection> createState() =>
      _TournamentParticipantsSectionState();
}

class _TournamentParticipantsSectionState
    extends State<TournamentParticipantsSection>
    with AutomaticKeepAliveClientMixin {
  TournamentParticipantsCatalog? _catalog;
  String? _selectedCategoryKey;
  List<TournamentAcademyVisibleGroup>? _cachedVisibleAcademies;
  String? _cachedVisibleCategoryKey;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _rebuildCatalog();
  }

  @override
  void didUpdateWidget(TournamentParticipantsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teams != widget.teams ||
        oldWidget.tournamentCategories != widget.tournamentCategories) {
      _rebuildCatalog();
    }
  }

  void _rebuildCatalog() {
    _catalog = TournamentParticipantsCatalog(
      teams: widget.teams,
      tournamentCategories: widget.tournamentCategories,
    );
    _cachedVisibleAcademies = null;
    _cachedVisibleCategoryKey = null;

    if (_selectedCategoryKey != null &&
        !_catalog!.availableCategories.any((c) => c.key == _selectedCategoryKey)) {
      _selectedCategoryKey = null;
    }
  }

  List<TournamentAcademyVisibleGroup> _visibleAcademies() {
    final catalog = _catalog;
    if (catalog == null) return const [];

    if (_cachedVisibleAcademies != null &&
        _cachedVisibleCategoryKey == _selectedCategoryKey) {
      return _cachedVisibleAcademies!;
    }

    final visible = catalog.visibleAcademies(_selectedCategoryKey);
    _cachedVisibleAcademies = visible;
    _cachedVisibleCategoryKey = _selectedCategoryKey;
    return visible;
  }

  String? get _selectedCategoryShortName {
    if (_selectedCategoryKey == null) return null;
    final catalog = _catalog;
    if (catalog == null) return null;
    for (final option in catalog.availableCategories) {
      if (option.key == _selectedCategoryKey) return option.shortName;
    }
    return null;
  }

  void _onCategorySelected(String? key) {
    setState(() {
      _selectedCategoryKey = key;
      _cachedVisibleAcademies = null;
      _cachedVisibleCategoryKey = null;
    });
  }

  void _onAcademyTap(
    TournamentAcademyVisibleGroup academy,
    Color themeAccent,
  ) {
    TournamentAcademyTeamsSheet.show(
      context,
      academy: academy,
      api: widget.api,
      resolveMediaUrl: widget.resolveMediaUrl,
      themeAccent: themeAccent,
      onViewAcademy: widget.onViewAcademy == null
          ? null
          : () => widget.onViewAcademy!(
                academy.academyId,
                academy.academyName,
              ),
    );
  }

  void _openCategorySheet(Color themeAccent) {
    final catalog = _catalog;
    if (catalog == null) return;

    TournamentParticipantsCategorySheet.show(
      context,
      options: catalog.availableCategories,
      selectedCategoryKey: _selectedCategoryKey,
      themeAccent: themeAccent,
      onSelected: _onCategorySelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final catalog = _catalog;
    if (catalog == null || catalog.allGroupedAcademies.isEmpty) {
      return CustomScrollView(
        key: const PageStorageKey<String>('tournament-participants'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: TournamentParticipantsEmptyState(),
          ),
        ],
      );
    }

    final themeAccent =
        TournamentParticipantsHelpers.resolveThemeAccent(widget.tournamentTheme);
    final visibleAcademies = _visibleAcademies();
    final academyCount = visibleAcademies.length;
    final teamCount = visibleAcademies.fold<int>(
      0,
      (sum, academy) => sum + academy.visibleTeamCount,
    );
    final summaryText = TournamentParticipantsHelpers.participantsSummaryLabel(
      academyCount: academyCount,
      teamCount: teamCount,
      categoryShortName: _selectedCategoryShortName,
    );
    final categoryShortName = _selectedCategoryShortName;

    const spacing = 12.0;
    const horizontalPadding = 16.0;
    final availableWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount =
        TournamentParticipantsHelpers.gridCrossAxisCount(availableWidth);

    return CustomScrollView(
      key: const PageStorageKey<String>('tournament-participants'),
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: 320,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isRefreshing)
                  const TournamentParticipantsRefreshBanner(),
                TournamentParticipantsSummaryHeader(summaryText: summaryText),
                const SizedBox(height: 12),
                if (catalog.availableCategories.isNotEmpty)
                  TournamentParticipantsFilterBar(
                    selectedCategoryKey: _selectedCategoryKey,
                    availableCategories: catalog.availableCategories,
                    themeAccent: themeAccent,
                    onOpenSheet: () => _openCategorySheet(themeAccent),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        if (visibleAcademies.isEmpty)
          SliverToBoxAdapter(
            child: TournamentParticipantsFilteredEmptyState(
              onClearFilter: () => _onCategorySelected(null),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              32,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final academy = visibleAcademies[index];
                  return TournamentAcademyGridItem(
                    key: ValueKey(academy.academyId),
                    academyId: academy.academyId,
                    academyName: academy.academyName,
                    academyLogo: academy.academyLogo,
                    teamCount: academy.visibleTeamCount,
                    resolveMediaUrl: widget.resolveMediaUrl,
                    themeAccent: themeAccent,
                    filterCategoryShortName: categoryShortName,
                    onTap: academy.visibleTeamCount > 1
                        ? () => _onAcademyTap(academy, themeAccent)
                        : null,
                  );
                },
                childCount: visibleAcademies.length,
                addRepaintBoundaries: true,
              ),
            ),
          ),
      ],
    );
  }
}
