import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../config/theme.dart';
import '../services/user_matches_store.dart';
import '../utils/match_helpers.dart';
import 'dashboard/user_related_match_card.dart';

enum _MatchStatusFilter { all, live, scheduled, finished }

class PlayerTournamentMatchesPanel extends StatefulWidget {
  const PlayerTournamentMatchesPanel({
    super.key,
    required this.dashboard,
    required this.isLoading,
    required this.matchesStore,
    required this.resolveMediaUrl,
    required this.onMatchTap,
  });

  final Map<String, dynamic>? dashboard;
  final bool isLoading;
  final UserMatchesStore matchesStore;
  final String Function(String) resolveMediaUrl;
  final void Function(Map<String, dynamic> match) onMatchTap;

  @override
  State<PlayerTournamentMatchesPanel> createState() =>
      _PlayerTournamentMatchesPanelState();
}

class _PlayerTournamentMatchesPanelState
    extends State<PlayerTournamentMatchesPanel> {
  bool _isLoading = true;
  String? _error;
  String? _selectedTournamentId;
  _MatchStatusFilter _statusFilter = _MatchStatusFilter.all;
  String? _selectedPlayerId;
  String? _selectedJourney;
  String _searchQuery = '';

  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _tournaments = [];
  Map<String, dynamic> _summary = {};

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null);
    _applyDashboard(widget.dashboard, widget.isLoading);
  }

  @override
  void didUpdateWidget(covariant PlayerTournamentMatchesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dashboard != widget.dashboard ||
        oldWidget.isLoading != widget.isLoading) {
      _applyDashboard(widget.dashboard, widget.isLoading);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyDashboard(Map<String, dynamic>? dashboard, bool isLoading) {
    if (isLoading && dashboard == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      return;
    }

    if (dashboard == null) {
      setState(() {
        _isLoading = false;
        _players = [];
        _tournaments = [];
        _summary = {};
        _error = 'No hay datos de partidos disponibles.';
      });
      return;
    }

    final tournaments = (dashboard['activeTournaments'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final summary = dashboard['summary'] is Map
        ? Map<String, dynamic>.from(dashboard['summary'] as Map)
        : <String, dynamic>{};
    final profiles = dashboard['profiles'] as List<dynamic>? ?? [];

    setState(() {
      _tournaments = tournaments;
      _summary = summary;
      _players = MatchHelpers.playersFromProfiles(profiles);
      _isLoading = false;
      _error = null;
    });
  }

  String _tournamentId(Map<String, dynamic> t) =>
      (t['id'] ?? t['_id'] ?? t['tournamentId'] ?? '').toString();

  String _tournamentIdFromMatch(Map<String, dynamic> match) {
    final t = match['tournament'];
    if (t is! Map) return '';
    return (t['id'] ?? t['_id'] ?? t['tournamentId'] ?? '').toString();
  }

  bool _matchIncludesPlayer(Map<String, dynamic> match, String playerId) {
    final related = match['relatedPlayers'] as List<dynamic>? ?? [];
    for (final raw in related) {
      if (raw is! Map) continue;
      final id = (raw['playerId'] ?? raw['id'] ?? '').toString();
      if (id == playerId) return true;
    }
    final primary = match['primaryPlayer'];
    if (primary is Map) {
      final id = (primary['playerId'] ?? primary['id'] ?? '').toString();
      if (id == playerId) return true;
    }
    return _playerIdFromMatch(match) == playerId;
  }

  String _playerIdFromMatch(Map<String, dynamic> match) {
    final primary = match['primaryPlayer'];
    if (primary is Map) {
      return (primary['playerId'] ?? primary['id'] ?? '').toString();
    }
    final related = match['relatedPlayers'] as List<dynamic>? ?? [];
    if (related.isNotEmpty && related.first is Map) {
      final p = Map<String, dynamic>.from(related.first as Map);
      return (p['playerId'] ?? p['id'] ?? '').toString();
    }
    return '';
  }

  bool _isFinished(Map<String, dynamic> match) =>
      MatchHelpers.isFinished(match);

  bool _isScheduled(Map<String, dynamic> match) =>
      MatchHelpers.isScheduled(match);

  String _journeyOf(Map<String, dynamic> match) => MatchHelpers.journeyOf(match);

  String _categoryOf(Map<String, dynamic> match) =>
      MatchHelpers.categoryName(match) ?? '';

  String _teamName(dynamic team, String fallback) {
    if (team is! Map) return fallback;
    return (team['name'] ?? fallback).toString();
  }

  List<String> _availableJourneys() {
    final journeys = <String>{};
    for (final m in widget.matchesStore.allMatches) {
      final j = _journeyOf(m);
      if (j.isNotEmpty) journeys.add(j);
    }
    final list = journeys.toList();
    list.sort(_compareJourneyKeys);
    return list;
  }

  int _compareJourneyKeys(String a, String b) {
    final ai = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
    final bi = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
    if (ai != null && bi != null) return ai.compareTo(bi);
    return a.compareTo(b);
  }

  List<Map<String, dynamic>> _applyFilters() {
    var pool = List<Map<String, dynamic>>.from(widget.matchesStore.allMatches);

    if (_selectedTournamentId != null && _selectedTournamentId!.isNotEmpty) {
      pool = pool
          .where((m) => _tournamentIdFromMatch(m) == _selectedTournamentId)
          .toList();
    }

    if (_selectedPlayerId != null) {
      pool = pool.where((m) => _matchIncludesPlayer(m, _selectedPlayerId!)).toList();
    }

    if (_selectedJourney != null && _selectedJourney!.isNotEmpty) {
      pool = pool
          .where((m) => _journeyOf(m).toLowerCase() == _selectedJourney!.toLowerCase())
          .toList();
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      pool = pool.where((m) {
        final home = _teamName(m['home'], '').toLowerCase();
        final visitor = _teamName(m['visitor'], '').toLowerCase();
        final cat = _categoryOf(m).toLowerCase();
        final tour =
            (m['tournament'] is Map ? m['tournament']['name'] : '').toString().toLowerCase();
        return home.contains(q) ||
            visitor.contains(q) ||
            cat.contains(q) ||
            tour.contains(q);
      }).toList();
    }

    switch (_statusFilter) {
      case _MatchStatusFilter.live:
        pool = pool.where(MatchHelpers.isLive).toList();
        break;
      case _MatchStatusFilter.scheduled:
        pool = pool.where(_isScheduled).toList();
        break;
      case _MatchStatusFilter.finished:
        pool = pool.where(_isFinished).toList();
        break;
      case _MatchStatusFilter.all:
        break;
    }

    pool.sort((a, b) {
      if (_statusFilter == _MatchStatusFilter.finished) {
        final ad = DateTime.tryParse((a['date'] ?? '').toString());
        final bd = DateTime.tryParse((b['date'] ?? '').toString());
        if (ad != null && bd != null) return bd.compareTo(ad);
      }
      return MatchHelpers.compareMatches(a, b);
    });

    return pool;
  }

  String _playerLabel(Map<String, dynamic> profile) {
    final alias = (profile['alias'] ?? '').toString().trim();
    if (alias.isNotEmpty) return alias;
    final name = (profile['name'] ?? '').toString().trim();
    if (name.isEmpty) return 'Jugador';
    return name.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.matchesStore,
      builder: (context, _) => _buildContent(),
    );
  }

  Widget _buildContent() {
    final filtered = _applyFilters();
    final journeys = _availableJourneys();
    Map<String, dynamic>? selectedTournament;
    for (final t in _tournaments) {
      if (_tournamentId(t) == _selectedTournamentId) {
        selectedTournament = t;
        break;
      }
    }
    selectedTournament ??=
        _tournaments.isNotEmpty ? _tournaments.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PARTIDOS',
          style: GoogleFonts.oswald(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.5,
          ),
        ),
        if (selectedTournament != null) ...[
          const SizedBox(height: 6),
          Text(
            (selectedTournament['name'] ?? 'Torneo activo').toString(),
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ] else if (_tournaments.length > 1) ...[
          const SizedBox(height: 6),
          Text(
            '${_tournaments.length} torneos activos',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
        if (_summarySubtitle().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _summarySubtitle(),
            style: GoogleFonts.publicSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.38),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _buildCompactFilterBar(journeys),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppTheme.brandTeal),
            ),
          )
        else if (_error != null)
          _buildMessage(_error!, isError: true)
        else if (_tournaments.isEmpty)
          _buildMessage('No hay torneos activos para tus jugadores.')
        else if (filtered.isEmpty)
          _buildMessage('No hay partidos con los filtros seleccionados.')
        else
          _buildMatchList(filtered),
      ],
    );
  }

  String _summarySubtitle() {
    final matches = widget.matchesStore.allMatches;
    if (_summary.isEmpty && matches.isEmpty) return '';
    final related = _summary['relatedMatchesCount'] ?? matches.length;
    final live = matches.where(MatchHelpers.isLive).length;
    final upcoming = matches.where(MatchHelpers.isScheduled).length;
    final parts = <String>['$related partidos'];
    if (live > 0) parts.add('$live en vivo');
    if (upcoming > 0) parts.add('$upcoming programados');
    return parts.join(' · ');
  }

  int _advancedFilterCount() {
    var count = 0;
    if (_selectedPlayerId != null) count++;
    if (_selectedJourney != null) count++;
    if (_tournaments.length > 1 && _selectedTournamentId != null) count++;
    return count;
  }

  bool _hasActiveFilterPills() {
    return _advancedFilterCount() > 0 || _searchQuery.trim().isNotEmpty;
  }

  void _clearAdvancedFilters() {
    setState(() {
      _selectedPlayerId = null;
      _selectedJourney = null;
      if (_tournaments.length > 1) _selectedTournamentId = null;
    });
  }

  String? _selectedPlayerLabel() {
    if (_selectedPlayerId == null) return null;
    for (final p in _players) {
      final id = (p['playerId'] ?? p['id'] ?? '').toString();
      if (id == _selectedPlayerId) {
        final followed = p['relation']?.toString() == 'followed';
        final label = _playerLabel(p);
        return followed ? '$label (seguido)' : label;
      }
    }
    return null;
  }

  String? _selectedTournamentLabel() {
    if (_selectedTournamentId == null) return null;
    for (final t in _tournaments) {
      if (_tournamentId(t) == _selectedTournamentId) {
        return (t['name'] ?? 'Torneo').toString();
      }
    }
    return null;
  }

  Widget _buildCompactFilterBar(List<String> journeys) {
    final advancedCount = _advancedFilterCount();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSearchField(compact: true)),
            const SizedBox(width: 8),
            Material(
              color: const Color(0xFF131B2F),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => _showAdvancedFiltersSheet(journeys),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: advancedCount > 0
                          ? AppTheme.brandTeal.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 22,
                        color: advancedCount > 0
                            ? AppTheme.brandTeal
                            : Colors.white.withValues(alpha: 0.55),
                      ),
                      if (advancedCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: AppTheme.brandTeal,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$advancedCount',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.navyPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatusSegmented(),
        if (_hasActiveFilterPills()) ...[
          const SizedBox(height: 10),
          _buildActiveFilterPills(),
        ],
      ],
    );
  }

  Widget _buildStatusSegmented() {
    const options = [
      ('Todos', _MatchStatusFilter.all, AppTheme.brandTeal),
      ('EN VIVO', _MatchStatusFilter.live, Color(0xFFEF4444)),
      ('Programados', _MatchStatusFilter.scheduled, AppTheme.brandTeal),
      ('Finalizados', _MatchStatusFilter.finished, Colors.white54),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: options.map((opt) {
            final selected = _statusFilter == opt.$2;
            final color = opt.$3;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () => setState(() => _statusFilter = opt.$2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? color.withValues(alpha: 0.22) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? color.withValues(alpha: 0.55)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    opt.$1,
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? color : Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActiveFilterPills() {
    final pills = <Widget>[];

    if (_searchQuery.trim().isNotEmpty) {
      pills.add(_activePill(
        'Búsqueda: ${_searchQuery.trim()}',
        () {
          _searchCtrl.clear();
          setState(() => _searchQuery = '');
        },
      ));
    }

    final playerLabel = _selectedPlayerLabel();
    if (playerLabel != null) {
      pills.add(_activePill('Jugador: $playerLabel', () {
        setState(() => _selectedPlayerId = null);
      }));
    }

    if (_selectedJourney != null) {
      pills.add(_activePill('Jornada J$_selectedJourney', () {
        setState(() => _selectedJourney = null);
      }));
    }

    final tournamentLabel = _selectedTournamentLabel();
    if (tournamentLabel != null) {
      pills.add(_activePill(tournamentLabel, () {
        setState(() => _selectedTournamentId = null);
      }));
    }

    if (pills.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...pills,
          if (_advancedFilterCount() > 0)
            GestureDetector(
              onTap: _clearAdvancedFilters,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Limpiar',
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brandTeal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _activePill(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 4, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: AppTheme.brandTeal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.publicSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.brandTeal,
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 14),
              color: AppTheme.brandTeal,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdvancedFiltersSheet(List<String> journeys) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B101E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'FILTROS',
                      style: GoogleFonts.oswald(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    if (_advancedFilterCount() > 0)
                      TextButton(
                        onPressed: () {
                          _clearAdvancedFilters();
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          'Limpiar',
                          style: TextStyle(
                            color: AppTheme.brandTeal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    ),
                  ],
                ),
                if (_tournaments.length > 1) ...[
                  _sheetSectionTitle('Torneo'),
                  _sheetOption(
                    label: 'Todos los torneos',
                    selected: _selectedTournamentId == null,
                    onTap: () {
                      setState(() => _selectedTournamentId = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  ..._tournaments.map((t) {
                    final id = _tournamentId(t);
                    return _sheetOption(
                      label: (t['name'] ?? 'Torneo').toString(),
                      selected: _selectedTournamentId == id,
                      onTap: () {
                        setState(() {
                          _selectedTournamentId = id;
                          _selectedJourney = null;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                if (_players.isNotEmpty) ...[
                  _sheetSectionTitle('Jugador'),
                  _sheetOption(
                    label: 'Todos los jugadores',
                    selected: _selectedPlayerId == null,
                    onTap: () {
                      setState(() => _selectedPlayerId = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  ..._players.map((p) {
                    final id = (p['playerId'] ?? p['id'] ?? '').toString();
                    final followed = p['relation']?.toString() == 'followed';
                    final label = followed
                        ? '${_playerLabel(p)} (seguido)'
                        : _playerLabel(p);
                    return _sheetOption(
                      label: label,
                      selected: _selectedPlayerId == id,
                      onTap: () {
                        setState(() => _selectedPlayerId = id);
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                if (journeys.isNotEmpty) ...[
                  _sheetSectionTitle('Jornada'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _journeySheetChip('Todas', null, journeys, ctx),
                      ...journeys.map(
                        (j) => _journeySheetChip('J$j', j, journeys, ctx),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.publicSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white38,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _sheetOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.brandTeal.withValues(alpha: 0.12)
                : const Color(0xFF131B2F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppTheme.brandTeal.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: AppTheme.brandTeal, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _journeySheetChip(
    String label,
    String? journey,
    List<String> journeys,
    BuildContext sheetCtx,
  ) {
    final selected = _selectedJourney == journey;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedJourney = journey);
        Navigator.pop(sheetCtx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFD600).withValues(alpha: 0.15)
              : const Color(0xFF131B2F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFFFFD600).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFFFFD600) : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField({bool compact = false}) {
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _searchQuery = v),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: compact ? 14 : 15,
      ),
      decoration: InputDecoration(
        hintText: compact ? 'Buscar...' : 'Buscar equipo, categoría o torneo...',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: compact ? 13 : 14,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: compact ? 20 : 22,
          color: Colors.white.withValues(alpha: 0.45),
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                color: Colors.white54,
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF131B2F),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 10 : 12,
        ),
        isDense: compact,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildMessage(String text, {bool isError = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError
              ? const Color(0xFFEF4444).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          color: isError ? const Color(0xFFEF4444) : Colors.white54,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMatchList(List<Map<String, dynamic>> matches) {
    if (_statusFilter != _MatchStatusFilter.all) {
      return Column(children: matches.map(_buildMatchCard).toList());
    }
    return _buildDateGroupedList(matches);
  }

  DateTime? _matchDay(Map<String, dynamic> match) =>
      MatchHelpers.matchLocalDay(match);

  List<({String label, List<Map<String, dynamic>> matches})> _groupMatchesByDate(
    List<Map<String, dynamic>> matches,
  ) {
    final groups = <({String label, List<Map<String, dynamic>> matches})>[];

    for (final match in matches) {
      final day = _matchDay(match);
      final label = day != null
          ? MatchHelpers.formatListSectionDate(day)
          : 'SIN FECHA';

      if (groups.isNotEmpty && groups.last.label == label) {
        groups.last.matches.add(match);
      } else {
        groups.add((label: label, matches: [match]));
      }
    }

    return groups;
  }

  Widget _buildDateSectionHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.oswald(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.brandTeal,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: GoogleFonts.publicSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.28),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateGroupedList(List<Map<String, dynamic>> matches) {
    final groups = _groupMatchesByDate(matches);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          _buildDateSectionHeader(groups[i].label, groups[i].matches.length),
          ...groups[i].matches.map(_buildMatchCard),
          if (i < groups.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    return UserRelatedMatchCard(
      match: match,
      onTap: () => widget.onMatchTap(match),
      resolveMediaUrl: widget.resolveMediaUrl,
    );
  }
}
