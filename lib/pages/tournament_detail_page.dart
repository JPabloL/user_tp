import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/tournament_detail_route.dart';
import '../utils/navigation_helpers.dart';
import 'widgets/tournament_standings_tab.dart';
import 'widgets/tournament_games_tab.dart';
import 'widgets/tournament_leaders_tab.dart';
import 'widgets/tournament_teams_tab.dart';

class TournamentDetailPage extends StatefulWidget {
  static const String route = TournamentDetailRoute.baseRoute;

  final ApiService api;
  final String? tournamentClave;

  const TournamentDetailPage({super.key, required this.api, this.tournamentClave});

  @override
  State<TournamentDetailPage> createState() => _TournamentDetailPageState();
}

class _TournamentDetailPageState extends State<TournamentDetailPage> {
  String? tournamentClave;
  bool isLoading = true;
  Map<String, dynamic>? tournamentData;
  String? errorMessage;

  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;
  Timer? _countdownTimer;
  Duration _countdownRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final collapsed = _scrollController.offset > 180;
      if (collapsed != _isCollapsed) {
        setState(() {
          _isCollapsed = collapsed;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (tournamentClave == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final map = Map<String, dynamic>.from(args);
        tournamentClave = (map['clave'] ?? map['id'] ?? widget.tournamentClave)?.toString();
      } else if (args is String && args.isNotEmpty) {
        tournamentClave = args;
      } else {
        tournamentClave = widget.tournamentClave;
      }

      tournamentClave = Uri.decodeComponent(tournamentClave ?? '').trim();

      if (tournamentClave != null && tournamentClave!.isNotEmpty) {
        _loadTournament();
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'ID de torneo no válido';
        });
      }
    }
  }

  Future<void> _loadTournament() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      Map<String, dynamic>? tournament;
      final lookupKey = tournamentClave!.trim();

      try {
        final res = await widget.api.getOnlyTournamentDetailByClave(lookupKey);
        if (res['status'] == 'ok' && res['tournament'] is Map) {
          tournament = Map<String, dynamic>.from(res['tournament'] as Map);
        }
      } catch (_) {
        // Fallback a consulta por id de documento.
      }

      tournament ??= await widget.api.getTournamentById(lookupKey);

      if (tournament != null) {
        setState(() {
          tournamentData = tournament;
          isLoading = false;
        });
        _syncCountdownTimer();
      } else {
        setState(() {
          errorMessage = 'No se encontró el torneo';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error de conexión';
        isLoading = false;
      });
    }
  }

  String _resolveMediaUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('/')) return 'https://cuerposallimite.net$value';
    return 'https://cuerposallimite.net/nlff/resources/images/$value';
  }

  bool _isShowDataEnabled(Map<String, dynamic> t) {
    final raw = t['showData'];
    if (raw is bool) return raw;
    if (raw == null) return true;
    final normalized = raw.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'si';
  }

  DateTime? _parseTournamentStart(Map<String, dynamic> t) {
    final raw = (t['start'] ?? t['startDate'] ?? t['fechaInicio'] ?? '').toString().trim();
    if (raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;

    final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (dateOnly != null) {
      return DateTime(
        int.parse(dateOnly.group(1)!),
        int.parse(dateOnly.group(2)!),
        int.parse(dateOnly.group(3)!),
      );
    }
    return null;
  }

  DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

  _TournamentViewMode _viewModeFor(Map<String, dynamic> t) {
    if (_isShowDataEnabled(t)) return _TournamentViewMode.fullTabs;

    final start = _parseTournamentStart(t);
    if (start == null) return _TournamentViewMode.comingSoon;

    final today = _startOfDay(DateTime.now());
    final startDay = _startOfDay(start);
    if (startDay.isAfter(today)) {
      return _TournamentViewMode.countdown;
    }
    return _TournamentViewMode.comingSoon;
  }

  DateTime? _countdownTarget(Map<String, dynamic> t) {
    final start = _parseTournamentStart(t);
    if (start == null) return null;
    return _startOfDay(start);
  }

  void _syncCountdownTimer() {
    _countdownTimer?.cancel();
    final t = tournamentData;
    if (t == null || _viewModeFor(t) != _TournamentViewMode.countdown) {
      _countdownRemaining = Duration.zero;
      return;
    }

    void tick() {
      final target = _countdownTarget(t);
      if (target == null || !mounted) return;
      final remaining = target.difference(DateTime.now());
      setState(() {
        _countdownRemaining = remaining.isNegative ? Duration.zero : remaining;
      });
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        _countdownTimer?.cancel();
        _loadTournament();
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  PreferredSizeWidget? _buildTabBar() {
    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.center,
      indicatorColor: AppTheme.brandTeal,
      indicatorWeight: 2,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white54,
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.zero,
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 9.5, letterSpacing: 0.5),
      unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 9.5, letterSpacing: 0.5),
      tabs: const [
        Tab(
          height: 44,
          iconMargin: EdgeInsets.only(bottom: 2),
          icon: Icon(Icons.calendar_month_outlined, size: 16),
          text: 'JUEGOS',
        ),
        Tab(
          height: 44,
          iconMargin: EdgeInsets.only(bottom: 2),
          icon: Icon(Icons.emoji_events_outlined, size: 16),
          text: 'TABLA',
        ),
        Tab(
          height: 44,
          iconMargin: EdgeInsets.only(bottom: 2),
          icon: Icon(Icons.bolt_outlined, size: 16),
          text: 'LÍDERES',
        ),
        Tab(
          height: 44,
          iconMargin: EdgeInsets.only(bottom: 2),
          icon: Icon(Icons.groups_outlined, size: 16),
          text: 'PARTICIPANTES',
        ),
        Tab(
          height: 44,
          iconMargin: EdgeInsets.only(bottom: 2),
          icon: Icon(Icons.info_outline, size: 16),
          text: 'INFO',
        ),
      ],
    );
  }

  Widget _buildHeaderFlexibleSpace(
    BuildContext context, {
    required String name,
    required String subname,
    required String coverUrl,
    required String logoUrl,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double top = constraints.biggest.height;
        final double statusBarHeight = MediaQuery.of(context).padding.top;
        final double minHeight = kToolbarHeight + statusBarHeight;
        const double maxHeight = 220.0;

        final double progress = ((top - minHeight) / (maxHeight - minHeight)).clamp(0.0, 1.0);

        final double titleLeft = 56.0 - (36.0 * progress);
        final double titleRight = 56.0 + (44.0 * progress);
        final double titleBottom = 66.0 + (18.0 * progress);
        final double titleSize = 16.0 + (8.0 * progress);

        final double logoRight = 16.0 + (4.0 * progress);
        final double logoBottom = 62.0 + (6.0 * progress);
        final double logoSize = 28.0 + (32.0 * progress);
        final double borderWidth = 1.2 + (0.8 * progress);

        return Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl.isNotEmpty)
              Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppTheme.navySurface),
              )
            else
              Container(color: AppTheme.navySurface),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.navyPrimary.withOpacity(0.1),
                    AppTheme.navyPrimary.withOpacity(0.6),
                    AppTheme.navyPrimary,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 120,
              child: Opacity(
                opacity: (progress * progress).clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brandTeal,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'TORNEO REGULAR',
                    style: TextStyle(
                      color: AppTheme.navyPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: titleLeft,
              bottom: titleBottom,
              right: titleRight,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.oswald(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: progress < 0.25 ? FontWeight.bold : FontWeight.w900,
                  letterSpacing: 0.5 + (0.7 * progress),
                  height: 1.1,
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 58,
              child: Opacity(
                opacity: (progress * progress).clamp(0.0, 1.0),
                child: Row(
                  children: [
                    const Icon(Icons.location_city, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      subname,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            if (logoUrl.isNotEmpty)
              Positioned(
                right: logoRight,
                bottom: logoBottom,
                child: Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.brandTeal, width: borderWidth),
                    image: DecorationImage(
                      image: NetworkImage(logoUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _handleBack() {
    popOrGoHome(context);
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Volver',
      onPressed: _handleBack,
    );
  }

  PreferredSizeWidget _buildSimpleAppBar() {
    return AppBar(
      backgroundColor: AppTheme.navyPrimary,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: _buildBackButton(),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  SliverAppBar _buildHeaderSliver({
    required String name,
    required String subname,
    required String coverUrl,
    required String logoUrl,
    PreferredSizeWidget? bottom,
  }) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppTheme.navyPrimary,
      automaticallyImplyLeading: false,
      leading: _buildBackButton(),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: _buildHeaderFlexibleSpace(
        context,
        name: name,
        subname: subname,
        coverUrl: coverUrl,
        logoUrl: logoUrl,
      ),
      bottom: bottom,
    );
  }

  Widget _buildCountdownPanel(Map<String, dynamic> t) {
    final start = _parseTournamentStart(t);
    final startLabel = start != null
        ? '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}'
        : (t['start'] ?? '').toString();

    final days = _countdownRemaining.inDays;
    final hours = _countdownRemaining.inHours.remainder(24);
    final minutes = _countdownRemaining.inMinutes.remainder(60);
    final seconds = _countdownRemaining.inSeconds.remainder(60);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, color: AppTheme.brandTeal.withValues(alpha: 0.9), size: 42),
            const SizedBox(height: 16),
            Text(
              'EL TORNEO AÚN NO INICIA',
              textAlign: TextAlign.center,
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Inicio programado: $startLabel',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _countdownUnit(days.toString(), 'DÍAS'),
                _countdownUnit(hours.toString().padLeft(2, '0'), 'HORAS'),
                _countdownUnit(minutes.toString().padLeft(2, '0'), 'MIN'),
                _countdownUnit(seconds.toString().padLeft(2, '0'), 'SEG'),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Muy pronto podrás consultar juegos, tabla, líderes y equipos.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countdownUnit(String value, String label) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.oswald(
              color: AppTheme.brandTeal,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top_rounded, color: AppTheme.brandTeal, size: 40),
              const SizedBox(height: 16),
              Text(
                'Datos en preparación',
                textAlign: TextAlign.center,
                style: GoogleFonts.oswald(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Próximamente podrán ver todos los datos del torneo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedBody(Map<String, dynamic> t, _TournamentViewMode mode) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        _buildHeaderSliver(
          name: (t['name'] ?? 'Torneo').toString().toUpperCase(),
          subname: (t['subname'] ?? '').toString(),
          coverUrl: _resolveMediaUrl((t['img'] ?? '').toString()),
          logoUrl: _resolveMediaUrl((t['logo'] ?? '').toString()),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: mode == _TournamentViewMode.countdown
              ? _buildCountdownPanel(t)
              : _buildComingSoonPanel(),
        ),
      ],
    );
  }

  Widget _buildTabsBody(Map<String, dynamic> t) {
    return DefaultTabController(
      length: 5,
      child: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildHeaderSliver(
              name: (t['name'] ?? 'Torneo').toString().toUpperCase(),
              subname: (t['subname'] ?? '').toString(),
              coverUrl: _resolveMediaUrl((t['img'] ?? '').toString()),
              logoUrl: _resolveMediaUrl((t['logo'] ?? '').toString()),
              bottom: _buildTabBar(),
            ),
          ];
        },
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            TournamentGamesTab(
              api: widget.api,
              tournamentId: (t['_id'] ?? t['id'] ?? '').toString(),
              modalidad: (t['modalidad'] ?? t['modality'] ?? '').toString(),
              resolveMediaUrl: _resolveMediaUrl,
            ),
            TournamentStandingsTab(
              api: widget.api,
              tournamentId: (t['_id'] ?? t['id'] ?? '').toString(),
              categories: t['categories'] ?? [],
              resolveMediaUrl: _resolveMediaUrl,
            ),
            TournamentLeadersTab(
              api: widget.api,
              tournamentId: (t['_id'] ?? t['id'] ?? '').toString(),
              categories: t['categories'] ?? [],
              resolveMediaUrl: _resolveMediaUrl,
            ),
            TournamentTeamsTab(
              api: widget.api,
              tournamentId: (t['_id'] ?? t['id'] ?? '').toString(),
              categories: t['categories'] ?? [],
              resolveMediaUrl: _resolveMediaUrl,
              tournamentTheme: t['theme'] is Map
                  ? Map<String, dynamic>.from(t['theme'] as Map)
                  : null,
            ),
            _buildInfoTab(t),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.navyPrimary,
        appBar: _buildSimpleAppBar(),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.brandTeal)),
      );
    }

    if (errorMessage != null || tournamentData == null) {
      return Scaffold(
        backgroundColor: AppTheme.navyPrimary,
        appBar: _buildSimpleAppBar(),
        body: Center(
          child: Text(
            errorMessage ?? 'Torneo no encontrado',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final t = tournamentData!;
    final viewMode = _viewModeFor(t);

    return Scaffold(
      backgroundColor: AppTheme.navyPrimary,
      body: viewMode == _TournamentViewMode.fullTabs
          ? _buildTabsBody(t)
          : _buildLockedBody(t, viewMode),
    );
  }

  Widget _buildInfoTab(Map<String, dynamic> t) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'DETALLES DEL TORNEO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        _buildInfoRow(Icons.calendar_today, 'Fecha de inicio', t['start']?.toString() ?? 'No especificada'),
        const SizedBox(height: 16),
        _buildInfoRow(Icons.event, 'Fecha de fin', t['end']?.toString() ?? 'No especificada'),
        const SizedBox(height: 16),
        _buildInfoRow(Icons.map, 'Sede / Liga', (t['subname'] ?? 'General').toString()),
        const SizedBox(height: 16),
        _buildInfoRow(Icons.description, 'Descripción', (t['description'] ?? 'Sin descripción disponible').toString()),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.brandTeal, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}

enum _TournamentViewMode {
  fullTabs,
  countdown,
  comingSoon,
}
