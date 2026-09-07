import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../utils/navigation_helpers.dart';
import '../utils/tournament_catalog_helpers.dart';
import '../services/tournament_detail_route.dart';
import '../widgets/tournament_catalog_card.dart';

class TorneosPage extends StatefulWidget {
  const TorneosPage({super.key, required this.api});

  static const String route = '/torneos';

  final ApiService api;

  @override
  State<TorneosPage> createState() => _TorneosPageState();
}

class _TorneosPageState extends State<TorneosPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allTournaments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTournaments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.api.getAllTournamentsTp();
      final parsed = TournamentCatalogHelpers.parseResponse(result);
      if (!mounted) return;
      setState(() {
        _allTournaments = parsed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudieron cargar los torneos.';
      });
    }
  }

  void _openTournamentDetail(Map<String, dynamic> tournament) {
    final clave = (tournament['clave'] ?? '').toString().trim();
    final id = (tournament['id'] ?? '').toString().trim();
    final routeKey = TournamentCatalogHelpers.detailRouteKey(tournament);

    if (routeKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir este torneo')),
      );
      return;
    }

    Navigator.of(context).pushNamed(
      TournamentDetailRoute.routeFor(routeKey),
      arguments: {
        if (clave.isNotEmpty) 'clave': clave,
        if (id.isNotEmpty) 'id': id,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final actuales = TournamentCatalogHelpers.groupActuales(_allTournaments);
    final anteriores = TournamentCatalogHelpers.groupAnteriores(_allTournaments);

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1629),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => popOrGoHome(context),
        ),
        title: Text(
          'Torneos',
          style: GoogleFonts.oswald(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        bottom: _isLoading || _errorMessage != null
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.brandTeal,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                labelStyle: GoogleFonts.oswald(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
                unselectedLabelStyle: GoogleFonts.oswald(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
                tabs: [
                  Tab(text: 'ACTUALES (${actuales.length})'),
                  Tab(text: 'ANTERIORES (${anteriores.length})'),
                ],
              ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.brandTeal),
            )
          : _errorMessage != null
              ? _ErrorState(
                  message: _errorMessage!,
                  onRetry: _loadTournaments,
                )
              : actuales.isEmpty && anteriores.isEmpty
                  ? _EmptyState(onRetry: _loadTournaments)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _TournamentTabList(
                          tournaments: actuales,
                          showActiveBadge: true,
                          emptyMessage: 'No hay torneos actuales',
                          onRefresh: _loadTournaments,
                          onTap: _openTournamentDetail,
                        ),
                        _TournamentTabList(
                          tournaments: anteriores,
                          showActiveBadge: false,
                          emptyMessage: 'No hay torneos anteriores',
                          onRefresh: _loadTournaments,
                          onTap: _openTournamentDetail,
                        ),
                      ],
                    ),
    );
  }
}

class _TournamentTabList extends StatelessWidget {
  const _TournamentTabList({
    required this.tournaments,
    required this.showActiveBadge,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onTap,
  });

  final List<Map<String, dynamic>> tournaments;
  final bool showActiveBadge;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic>) onTap;

  @override
  Widget build(BuildContext context) {
    if (tournaments.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.brandTeal,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.45,
              child: Center(
                child: Text(
                  emptyMessage,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.brandTeal,
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: tournaments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final tournament = tournaments[index];
          return TournamentCatalogCard(
            tournament: tournament,
            showActiveBadge: showActiveBadge,
            onTap: () => onTap(tournament),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'No hay torneos disponibles',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandTeal,
                foregroundColor: Colors.black,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
