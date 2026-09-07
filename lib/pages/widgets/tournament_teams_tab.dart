import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/academy_profile_route.dart';
import '../../services/api_service.dart';
import '../../utils/tournament_participants_helpers.dart';
import '../../widgets/tournament_participants_section.dart';
import '../../widgets/tournament_participants_states.dart';

class TournamentTeamsTab extends StatefulWidget {
  const TournamentTeamsTab({
    super.key,
    required this.api,
    required this.tournamentId,
    required this.resolveMediaUrl,
    this.categories = const [],
    this.tournamentTheme,
  });

  final ApiService api;
  final String tournamentId;
  final String Function(String) resolveMediaUrl;
  final List<dynamic> categories;
  final Map<String, dynamic>? tournamentTheme;

  @override
  State<TournamentTeamsTab> createState() => _TournamentTeamsTabState();
}

class _TournamentTeamsTabState extends State<TournamentTeamsTab>
    with AutomaticKeepAliveClientMixin {
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _loadInProgress = false;
  String _error = '';
  List<Map<String, dynamic>> _teams = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams({bool isRefresh = false}) async {
    if (_loadInProgress) return;

    if (widget.tournamentId.isEmpty) {
      setState(() {
        _isInitialLoading = false;
        _isRefreshing = false;
        _error = 'Torneo sin identificador';
      });
      return;
    }

    _loadInProgress = true;
    setState(() {
      _error = '';
      if (_teams.isEmpty) {
        _isInitialLoading = true;
      } else if (isRefresh) {
        _isRefreshing = true;
      } else {
        _isInitialLoading = true;
      }
    });

    try {
      final res = await widget.api.getTournamentTeamsGroupedByCategory(
        widget.tournamentId,
      );

      if (!mounted) return;

      if (res['status'] != 'ok') {
        setState(() {
          _isInitialLoading = false;
          _isRefreshing = false;
          _loadInProgress = false;
          if (_teams.isEmpty) {
            _error = 'load_failed';
          }
        });
        return;
      }

      final raw = (res['categories'] as List<dynamic>?) ?? [];
      final categoryBlocks = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final teams = TournamentParticipantsHelpers.flattenTeamsFromCategoryBlocks(
        categoryBlocks,
      );

      setState(() {
        _teams = teams;
        _isInitialLoading = false;
        _isRefreshing = false;
        _loadInProgress = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _isRefreshing = false;
        _loadInProgress = false;
        if (_teams.isEmpty) {
          _error = 'load_failed';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isInitialLoading) {
      return const TournamentParticipantsLoadingView();
    }

    if (_error.isNotEmpty && _teams.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: TournamentParticipantsErrorState(
              onRetry: () => _loadTeams(),
              isRetrying: _loadInProgress,
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: AppTheme.brandTeal,
      backgroundColor: AppTheme.navyPrimary,
      onRefresh: () => _loadTeams(isRefresh: true),
      child: TournamentParticipantsSection(
          api: widget.api,
          teams: _teams,
          resolveMediaUrl: widget.resolveMediaUrl,
          tournamentTheme: widget.tournamentTheme,
          tournamentCategories: widget.categories,
          isRefreshing: _isRefreshing,
          onViewAcademy: (academyId, academyName) {
            if (academyId.trim().isEmpty) return;

            final route = AcademyProfileRoute.routeFor(
              academyId,
              sourceTournamentId: widget.tournamentId,
            );
            Navigator.of(context).pushNamed(
              route,
              arguments: {
                'academyId': academyId.trim(),
                if (widget.tournamentId.trim().isNotEmpty)
                  'sourceTournamentId': widget.tournamentId.trim(),
              },
            );
          },
        ),
    );
  }
}
