import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';
import '../services/toast_service.dart';
import 'home_page.dart';

class PlayerDashboardPage extends StatefulWidget {
  const PlayerDashboardPage({
    super.key,
    required this.api,
    required this.storage,
    required this.socketService,
    required this.playerId,
    required this.playerName,
    this.autoOpenRequests = false,
  });

  static const String route = '/jugador';

  final ApiService api;
  final StorageService storage;
  final SocketService socketService;
  final String playerId;
  final String playerName;
  final bool autoOpenRequests;

  @override
  State<PlayerDashboardPage> createState() => _PlayerDashboardPageState();
}

class _PlayerDashboardPageState extends State<PlayerDashboardPage> {
  static const _animDuration = Duration(milliseconds: 280);
  bool isLoading = true;
  bool isLoadingStats = false;
  bool isLoadingTeamStats = false;
  bool autoOpenRequests = false;
  bool isModalOpen = false;
  String userId = '';
  String selectedTab = 'general';
  int activeCarouselIndex = 0;

  Map<String, dynamic>? playerData;
  Map<String, dynamic>? statsSummary;
  Map<String, dynamic>? teamStats;
  Map<String, dynamic>? statsHistory;
  List<dynamic> playerRequests = [];
  List<dynamic> currentTeams = [];
  List<dynamic> oldTeams = [];
  int pendingRequestsCount = 0;

  StreamSubscription<dynamic>? socketSub;

  List<dynamic> get carouselOptions {
    final general = {
      'type': 'general',
      'name': 'Resumen',
      'logo': 'https://cuerposallimite.net/nlff/resources/images/logo_tochito_pro.png',
    };
    final allTeams = [...currentTeams, ...oldTeams];
    return [general, ...allTeams];
  }

  Map<String, dynamic> get activeStats {
    final selected = carouselOptions[activeCarouselIndex];
    if (selected['type'] == 'general') return statsSummary ?? _defaultStats();
    return teamStats ?? _defaultStats();
  }

  @override
  void initState() {
    super.initState();
    autoOpenRequests = widget.autoOpenRequests;
    _loadUser();
    _loadDashboardData();
    _setupWebsockets();
  }

  @override
  void dispose() {
    socketSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final session = await widget.storage.getJson(AppConfig.sessionKey);
    if (session == null) return;
    userId = session['id']?.toString() ?? '';
  }

  void _setupWebsockets() {
    widget.socketService.joinRoom(widget.playerId);
    socketSub = widget.socketService.requestUpdatesStream.listen((data) async {
      await _loadPlayerRequests();
      if (!isModalOpen) {
        _toast('Solicitud actualizada');
      }
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);
    try {
      final response = await widget.api.loadPlayerDashboardData(widget.playerId);
      playerData = response['playerData'] as Map<String, dynamic>?;
      statsSummary = response['statsSummary'] as Map<String, dynamic>?;
      playerRequests = (response['requests'] as List<dynamic>?) ?? [];
      pendingRequestsCount = playerRequests.where((r) => r['mood'] == 0).length;
      _processTeams((playerData?['teams'] as List<dynamic>?) ?? []);
    } catch (_) {
      _toast('No se pudieron cargar los datos', isError: true);
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil(HomePage.route, (_) => false);
    } finally {
      if (mounted) setState(() => isLoading = false);
      if (autoOpenRequests && mounted) {
        autoOpenRequests = false;
        _openRequestsModal();
      }
    }
  }

  Future<void> _loadPlayerRequests() async {
    try {
      final requests = await widget.api.getMyRequests(widget.playerId);
      if (!mounted) return;
      setState(() {
        playerRequests = requests;
        pendingRequestsCount = playerRequests.where((r) => r['mood'] == 0).length;
      });
    } catch (_) {}
  }

  Future<void> _loadStatsHistory() async {
    if (statsHistory != null) return;
    setState(() => isLoadingStats = true);
    try {
      final response = await widget.api.getPlayerStatsHistory(widget.playerId);
      statsHistory = response['history'] as Map<String, dynamic>?;
    } catch (_) {
      _toast('No se pudo cargar historial de stats', isError: true);
    } finally {
      if (mounted) setState(() => isLoadingStats = false);
    }
  }

  void _processTeams(List<dynamic> teams) {
    final now = DateTime.now();
    bool isCurrent(Map<String, dynamic> t) {
      final endRaw = t['tournament']?['end']?.toString();
      final end = endRaw == null ? null : DateTime.tryParse(endRaw);
      if (end == null) return false;
      return end.isAfter(now) || end.isAtSameMomentAs(now);
    }

    currentTeams = teams.whereType<Map<String, dynamic>>().where(isCurrent).toList();
    oldTeams = teams.whereType<Map<String, dynamic>>().where((t) => !isCurrent(t)).toList();
  }

  Future<void> _updateActiveStats() async {
    final selected = carouselOptions[activeCarouselIndex];
    if (selected['type'] == 'general') {
      setState(() => teamStats = null);
      return;
    }
    final teamId = selected['team']?['id']?.toString() ?? selected['id']?.toString() ?? '';
    if (teamId.isEmpty) return;
    setState(() => isLoadingTeamStats = true);
    try {
      final res = await widget.api.getPlayerStatsByTeam(teamId: teamId, playerId: widget.playerId);
      if (!mounted) return;
      setState(() => teamStats = (res['stats'] as Map<String, dynamic>?) ?? <String, dynamic>{});
    } catch (_) {
      _toast('No se pudieron cargar stats del equipo', isError: true);
    } finally {
      if (mounted) setState(() => isLoadingTeamStats = false);
    }
  }

  Future<void> _changePublicPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    try {
      final res = await widget.api.updatePlayerPublicPhoto(
        playerId: widget.playerId,
        bytes: await file.readAsBytes(),
      );
      if (res['status'] == 'ok') {
        setState(() {
          playerData?['photo'] = res['newPhotoUrl'] ?? playerData?['photo'];
        });
        _toast('Foto actualizada');
      }
    } catch (_) {
      _toast('No se pudo actualizar foto', isError: true);
    }
  }

  Future<void> _openRequestsModal() async {
    if (isLoading || playerData == null) return;
    isModalOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final moodNames = ['Pendiente', 'Aceptado', 'Rechazado', 'Cancelado'];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Solicitudes de equipo', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...playerRequests.map((r) => ListTile(
                      title: Text((r['academy']?['name'] ?? 'Academia').toString()),
                      subtitle: Text('Estado: ${moodNames[(r['mood'] ?? 0) as int]}'),
                    )),
              ],
            ),
          ),
        );
      },
    );
    isModalOpen = false;
    await _loadDashboardData();
  }

  Map<String, dynamic> _defaultStats() => {
        'totalPoints': 0,
        'passingTD': 0,
        'totalRecepciones': 0,
        'totalCarreras': 0,
        'sacks': 0,
        'interceptions': 0,
      };

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ToastService.show(context, msg, isError: isError);
  }

  @override
  Widget build(BuildContext context) {
    final name = playerData?['name']?.toString() ?? widget.playerName;
    final photo = playerData?['photo']?.toString() ?? '';
    final stats = activeStats;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.sports_football, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'TOCHITO PRO',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 2.1,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6F7680),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _openRequestsModal,
                      icon: Badge(
                        label: Text('$pendingRequestsCount'),
                        isLabelVisible: pendingRequestsCount > 0,
                        child: const Icon(Icons.notifications_active_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                ),
                const SizedBox(height: 2),
                Text('CURP: ${playerData?['curp'] ?? '-'}',
                    style: const TextStyle(color: Color(0xFF646C76), fontSize: 14)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8))],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                        child: photo.isEmpty ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Dashboard de rendimiento', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      IconButton(onPressed: _changePublicPhoto, icon: const Icon(Icons.camera_alt_outlined)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected) ? Colors.black : Colors.white,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected) ? Colors.white : Colors.black,
                    ),
                    side: WidgetStateProperty.all(BorderSide(color: Colors.grey.shade300)),
                  ),
                  segments: const [
                    ButtonSegment(value: 'general', label: Text('General')),
                    ButtonSegment(value: 'teams', label: Text('Equipos')),
                    ButtonSegment(value: 'stats', label: Text('Stats')),
                  ],
                  selected: {selectedTab},
                  onSelectionChanged: (v) async {
                    setState(() => selectedTab = v.first);
                    if (selectedTab == 'stats') await _loadStatsHistory();
                  },
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: _animDuration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: selectedTab == 'stats'
                      ? _buildStatsHistoryCard()
                      : selectedTab == 'teams'
                          ? _buildTeamsListCard()
                          : _buildGeneralStatsCard(stats),
                ),
              ],
            ),
    );
  }

  Widget _buildGeneralStatsCard(Map<String, dynamic> stats) {
    return Container(
      key: const ValueKey('general-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () async {
                  final len = carouselOptions.length;
                  if (len <= 1) return;
                  setState(() => activeCarouselIndex = (activeCarouselIndex - 1 + len) % len);
                  await _updateActiveStats();
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  (carouselOptions[activeCarouselIndex]['name'] ?? 'Resumen').toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final len = carouselOptions.length;
                  if (len <= 1) return;
                  setState(() => activeCarouselIndex = (activeCarouselIndex + 1) % len);
                  await _updateActiveStats();
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (isLoadingTeamStats) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statChip('PTS', stats['totalPoints'] ?? stats['points'] ?? 0),
              _statChip('PAS', stats['passingTD'] ?? stats['pass'] ?? 0),
              _statChip('REC', stats['totalRecepciones'] ?? stats['catch'] ?? 0),
              _statChip('RUN', stats['totalCarreras'] ?? stats['run'] ?? 0),
              _statChip('SCK', stats['sacks'] ?? stats['sack'] ?? 0),
              _statChip('INT', stats['interceptions'] ?? stats['inter'] ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsListCard() {
    final teams = [...currentTeams, ...oldTeams];
    return Container(
      key: const ValueKey('teams-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: teams.isEmpty
          ? const Text('Este jugador no tiene equipos asignados.')
          : Column(
              children: teams
                  .map(
                    (t) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text((t['name'] ?? 'Equipo').toString()),
                      subtitle: Text((t['tournament']?['name'] ?? 'Sin torneo').toString()),
                      trailing: Text('#${t['num'] ?? '-'}'),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildStatsHistoryCard() {
    return Container(
      key: const ValueKey('stats-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: isLoadingStats
          ? const Center(child: CircularProgressIndicator())
          : Text(
              statsHistory == null
                  ? 'Sin historial de estadísticas'
                  : 'Historial cargado correctamente',
            ),
    );
  }

  Widget _statChip(String label, dynamic value) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6A727D))),
        ],
      ),
    );
  }
}
