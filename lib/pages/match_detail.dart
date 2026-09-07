import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/category_palette.dart';
import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../services/match_detail_route.dart';
import '../../services/socket_service.dart';
import '../../services/user_matches_store.dart';
import '../../services/storage_service.dart';
import '../../utils/match_awards.dart';
import '../../utils/match_helpers.dart';
import '../../utils/navigation_helpers.dart';
import '../../widgets/match_awards_section.dart';
import '../../widgets/match_special_mention_section.dart';

class MatchDetailPage extends StatefulWidget {
  static const String route = '/match_detail';
  final ApiService api;
  final SocketService socketService;

  const MatchDetailPage({
    Key? key,
    required this.api,
    required this.socketService,
  }) : super(key: key);

  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage> with TickerProviderStateMixin {
  // Stealth Tokens
  static const Color brandBg = Color(0xFF0F172A);
  static const Color brandSurface = Color(0xFF1E293B);
  static const Color brandPrimary = Color(0xFF2DD4BF);
  static const Color visitColor = Color(0xFFE040FB);
  static const Color successColor = Color(0xFF34D399);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color textMuted = Color(0xFF94A3B8);

  String? matchId;
  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic> matchData = {};
  Map<String, dynamic> homeTeam = {};
  Map<String, dynamic> visitorTeam = {};
  List<dynamic> actions = [];

  // Socket
  StreamSubscription<dynamic>? _matchSocketSub;
  Set<String> highlightedActionIds = {};

  // Stats
  Map<String, int> _gameTotals = {
    'pts': 0,
    'pass': 0,
    'catch': 0,
    'run': 0,
    'sack': 0,
    'int': 0,
  };
  Map<String, Map<String, int>> _teamTotals = {
    'pts': {'home': 0, 'visit': 0},
    'pass': {'home': 0, 'visit': 0},
    'catch': {'home': 0, 'visit': 0},
    'run': {'home': 0, 'visit': 0},
    'sack': {'home': 0, 'visit': 0},
    'int': {'home': 0, 'visit': 0},
  };
  Map<String, Map<String, List<dynamic>>> _detailedStats = {
    'pts': {'home': [], 'visit': []},
    'pass': {'home': [], 'visit': []},
    'catch': {'home': [], 'visit': []},
    'run': {'home': [], 'visit': []},
    'sack': {'home': [], 'visit': []},
    'int': {'home': [], 'visit': []},
  };

  Map<String, List<Map<String, dynamic>>> _statLeaders = {
    'pass': [],
    'run': [],
    'catch': [],
    'sack': [],
    'int': [],
  };

  Map<String, Map<String, dynamic>> _playerGameStats = {};
  List<Map<String, dynamic>> _specialMentionPlayers = [];
  List<Map<String, dynamic>> _mentionUserProfiles = [];
  bool _mentionProfilesLoadStarted = false;

  static const List<(String statKey, String title, String statLabel)> _statLeaderCategories = [
    ('pass', 'LÍDER EN PASES', 'PASES'),
    ('run', 'LÍDER EN CARRERAS', 'CARRERAS'),
    ('catch', 'LÍDER EN RECEPCIONES', 'REC'),
    ('sack', 'LÍDER EN SACKS', 'SACKS'),
    ('int', 'LÍDER EN INTERCEPCIONES', 'INT'),
  ];

  static const List<(String chip, String statKey, String title)> _breakdownCategories = [
    ('PTS', 'pts', 'PUNTOS'),
    ('PASS', 'pass', 'PASES'),
    ('REC', 'catch', 'RECEPCIONES'),
    ('RUN', 'run', 'CARRERAS'),
    ('SACK', 'sack', 'SACKS'),
    ('INT', 'int', 'INTERCEPCIONES'),
  ];

  MatchAwardsResult _matchAwards = MatchAwardsResult.empty;

  // UI state
  String _selectedCategory = 'PTS';
  bool _rosterTabIsHome = true;
  late ScrollController _scrollController;
  late ScrollController _statsScrollController;
  bool _isCompactHeader = false;
  late AnimationController _pulseController;

  // Live sync indicator
  SocketConnectionState _socketState = SocketConnectionState.disconnected;
  int _socketReconnectAttempt = 0;
  DateTime? _lastLiveUpdateAt;
  bool _isManualRefreshing = false;
  StreamSubscription<SocketConnectionState>? _socketConnSub;
  Timer? _fallbackRefreshTimer;
  Timer? _matchAwardsRecalcTimer;

  MatchAwardsResult get matchAwards => _matchAwards;
  bool get hasMvp => _matchAwards.hasMvp;
  bool get hasFeaturedPlayer => _matchAwards.hasFeaturedPlayer;
  bool get hasOffensiveLeader => _matchAwards.hasOffensiveLeader;
  bool get hasDefensiveLeader => _matchAwards.hasDefensiveLeader;
  bool get hasAnyAward => _matchAwards.hasAnyAward;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _statsScrollController = ScrollController();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (matchId == null) {
      final route = ModalRoute.of(context)?.settings;
      final resolved = MatchDetailRoute.resolve(
        routeName: route?.name,
        arguments: route?.arguments,
      );

      matchId = resolved.matchId;

      if (resolved.matchSnapshot != null) {
        matchData = Map<String, dynamic>.from(resolved.matchSnapshot!);
        final h = matchData['home'];
        if (h is Map) homeTeam = Map<String, dynamic>.from(h);
        final v = matchData['visitor'];
        if (v is Map) visitorTeam = Map<String, dynamic>.from(v);
      }

      if (matchId != null && matchId!.isNotEmpty) {
        _loadMatchDetail();
        _setupSocket();
        _loadMentionUserProfiles();
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'ID de partido no válido';
        });
      }
    }
  }

  @override
  void dispose() {
    _matchSocketSub?.cancel();
    _matchSocketSub = null;
    _socketConnSub?.cancel();
    _socketConnSub = null;
    _fallbackRefreshTimer?.cancel();
    _fallbackRefreshTimer = null;
    _matchAwardsRecalcTimer?.cancel();
    _matchAwardsRecalcTimer = null;
    _scrollController.dispose();
    _statsScrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final isCompact = _scrollController.offset > 240;
      if (isCompact != _isCompactHeader) {
        setState(() => _isCompactHeader = isCompact);
      }
    }
  }

  Future<void> _loadMatchDetail({bool silent = false}) async {
    try {
      final res = await widget.api.post('/getMatchDetail', {'matchId': matchId});
      if (res != null && res['status'] == 'ok' && res['match'] != null) {
        if (!mounted) return;
        setState(() {
          final previousRelated = matchData['relatedPlayers'];
          matchData = Map<String, dynamic>.from(res['match']);
          final relatedFromApi = res['relatedPlayers'] ?? res['match']?['relatedPlayers'];
          if (relatedFromApi is List && relatedFromApi.isNotEmpty) {
            matchData['relatedPlayers'] = relatedFromApi;
          } else if (previousRelated is List && previousRelated.isNotEmpty) {
            matchData['relatedPlayers'] = previousRelated;
          }
          final t = res['teams'] ?? {};
          if (t['home'] != null) homeTeam = Map<String, dynamic>.from(t['home']);
          if (t['visitor'] != null) visitorTeam = Map<String, dynamic>.from(t['visitor']);
          
          final acts = res['actions'] as List? ?? [];
          actions = acts
              .whereType<Map>()
              .map((a) => Map<String, dynamic>.from(a))
              .where((a) => !_shouldOmitAction(a))
              .toList();
          
          isLoading = false;
          _markLiveUpdate();
          _refreshGameStats(awardsImmediate: true);
        });
      } else {
        if (!mounted) return;
        if (!silent) {
          setState(() {
            isLoading = false;
            errorMessage = 'No se pudo cargar la información.';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error de conexión';
        });
      }
    }
  }

  void _markLiveUpdate() {
    _lastLiveUpdateAt = DateTime.now();
  }

  Future<void> _manualRefreshMatch() async {
    if (_isManualRefreshing) return;
    setState(() => _isManualRefreshing = true);
    widget.socketService.connect();
    final id = (matchId ?? '').trim();
    if (id.isNotEmpty) {
      widget.socketService.joinMatch(id);
    }
    await _loadMatchDetail(silent: true);
    if (mounted) {
      setState(() => _isManualRefreshing = false);
    }
  }

  void _onSocketConnectionState(SocketConnectionState state) {
    if (!mounted) return;
    final attempt = widget.socketService.reconnectionAttempt;
    setState(() {
      _socketState = state;
      _socketReconnectAttempt = attempt;
    });

    if (state == SocketConnectionState.connected) {
      _fallbackRefreshTimer?.cancel();
      return;
    }

    if (_isMatchLive() && attempt >= 10) {
      _scheduleSpacedFallbackRefresh();
    }
  }

  void _scheduleSpacedFallbackRefresh() {
    _fallbackRefreshTimer?.cancel();
    if (!_isMatchLive()) return;
    if (widget.socketService.isConnected) return;

    final attempt = math.max(_socketReconnectAttempt, 10);
    final spacingSeconds = math.min(30 + (attempt - 10) * 15, 120);

    _fallbackRefreshTimer = Timer(Duration(seconds: spacingSeconds), () async {
      if (!mounted) return;
      if (widget.socketService.isConnected) return;
      await _loadMatchDetail(silent: true);
      if (mounted) {
        _scheduleSpacedFallbackRefresh();
      }
    });
  }

  void _setupSocket() {
    final id = (matchId ?? '').trim();
    if (id.isEmpty) return;

    widget.socketService.connect();
    widget.socketService.joinMatch(id);

    _socketConnSub?.cancel();
    _socketConnSub = widget.socketService.connectionStateStream.listen(
      _onSocketConnectionState,
    );

    _onSocketConnectionState(
      widget.socketService.isConnected
          ? SocketConnectionState.connected
          : widget.socketService.connectionState,
    );

    _matchSocketSub?.cancel();
    _matchSocketSub = widget.socketService.matchUpdates.listen(_onMatchSocketMessage);
  }

  void _onMatchSocketMessage(dynamic raw) {
    if (!mounted) return;

    final envelope = raw is Map
        ? MatchHelpers.asMap(raw)
        : <String, dynamic>{};
    final event = (envelope['event'] ?? '').toString();
    final dataRaw = envelope['data'] ?? envelope;
    final data = dataRaw is Map
        ? MatchHelpers.asMap(dataRaw)
        : <String, dynamic>{};
    _handleSocketEvent(event, data);
  }

  String _incomingMatchId(Map<String, dynamic> payload) {
    final matchObj = payload['match'];
    if (matchObj is Map) {
      return MatchHelpers.matchId(MatchHelpers.asMap(matchObj));
    }
    return MatchHelpers.matchId(payload);
  }

  bool _isSameMatch(String incomingId) {
    final a = incomingId.trim();
    final b = (matchId ?? '').trim();
    if (a.isEmpty || b.isEmpty) return false;
    return a == b;
  }

  void _handleSocketEvent(String event, Map<String, dynamic> data) {
    if (!mounted || data.isEmpty) return;

    final payload = data['payload'] is Map
        ? MatchHelpers.asMap(data['payload'])
        : data;
    if (payload.isEmpty) return;

    final incomingId = _incomingMatchId(payload);
    if (!_isSameMatch(incomingId)) return;

    setState(() {
      _applyLiveMatchPatch(payload, event);
      _markLiveUpdate();
    });
  }

  void _applyLiveMatchPatch(Map<String, dynamic> payload, String event) {
    final matchObj = payload['match'];
    final patch = matchObj is Map
        ? MatchHelpers.asMap(matchObj)
        : Map<String, dynamic>.from(payload);

    MatchHelpers.applyLegacyScores(patch);

    for (final entry in patch.entries) {
      final key = entry.key;
      final val = entry.value;
      if (val == null) continue;

      if (key == 'home' || key == 'visitor') {
        matchData[key] = MatchHelpers.deepMergeTeam(
          MatchHelpers.asMap(matchData[key]),
          MatchHelpers.asMap(val),
        );
      } else if (val is Map) {
        if (val.isEmpty) continue;
        matchData[key] = MatchHelpers.asMap(val);
      } else {
        matchData[key] = val;
      }
    }

    if (payload['gameStatus'] != null) {
      matchData['gameStatus'] = payload['gameStatus'];
    }

    if (payload['score'] is Map) {
      matchData['score'] = MatchHelpers.deepMergeTeam(
        MatchHelpers.asMap(matchData['score']),
        MatchHelpers.asMap(payload['score']),
      );
    }

    final normalized = Map<String, dynamic>.from(matchData);
    MatchHelpers.applyLegacyScores(normalized);
    matchData['home'] = MatchHelpers.asMap(normalized['home']);
    matchData['visitor'] = MatchHelpers.asMap(normalized['visitor']);
    if (normalized['score'] is Map) {
      matchData['score'] = MatchHelpers.asMap(normalized['score']);
    }

    homeTeam = Map<String, dynamic>.from(MatchHelpers.asMap(matchData['home']));
    visitorTeam =
        Map<String, dynamic>.from(MatchHelpers.asMap(matchData['visitor']));

    if (payload['mvp'] != null || patch.containsKey('mvp')) {
      _applyMvpFromPayload(payload, patch);
    }

    if (patch['actions'] is List) {
      _syncActionsFromPayload({'actions': patch['actions']});
    }
    _syncActionsFromPayload(payload);

    if (payload['action'] is Map) {
      _upsertAction(MatchHelpers.asMap(payload['action']));
    }

    if (event == 'match_action_deleted' ||
        payload['actionId'] != null ||
        payload['deletedId'] != null) {
      final delId = (payload['actionId'] ??
              payload['deletedId'] ??
              payload['_id'] ??
              payload['id'] ??
              '')
          .toString();
      if (delId.isNotEmpty) {
        actions.removeWhere((a) => (a['_id'] ?? a['id']).toString() == delId);
      }
    }

    _refreshGameStats(awardsImmediate: false);
  }

  void _applyMvpFromPayload(
    Map<String, dynamic> payload,
    Map<String, dynamic> patch,
  ) {
    if (payload.containsKey('mvp')) {
      final raw = payload['mvp'];
      if (raw == null) {
        matchData.remove('mvp');
      } else if (raw is Map && raw.isNotEmpty) {
        matchData['mvp'] = MatchHelpers.asMap(raw);
      } else if (raw is String && raw.trim().isNotEmpty) {
        matchData['mvp'] = raw.trim();
      }
      return;
    }

    if (patch.containsKey('mvp')) {
      final raw = patch['mvp'];
      if (raw == null) {
        matchData.remove('mvp');
      } else if (raw is Map && raw.isNotEmpty) {
        matchData['mvp'] = MatchHelpers.asMap(raw);
      } else if (raw is String && raw.trim().isNotEmpty) {
        matchData['mvp'] = raw.trim();
      }
    }
  }

  void _syncActionsFromPayload(Map<String, dynamic> payload) {
    final raw = payload['actions'];
    if (raw is! List) return;

    final byId = <String, Map<String, dynamic>>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final action = Map<String, dynamic>.from(item);
      if (_shouldOmitAction(action)) continue;
      final id = (action['_id'] ?? action['id'] ?? '').toString();
      if (id.isEmpty) continue;
      byId[id] = action;
    }

    if (byId.isEmpty) return;

    actions = byId.values.toList();
    actions.sort(
      (a, b) => (b['date'] ?? '').toString().compareTo(
        (a['date'] ?? '').toString(),
      ),
    );
  }

  void _upsertAction(Map<String, dynamic> action) {
    final aId = (action['_id'] ?? action['id'] ?? '').toString();
    if (aId.isEmpty || _shouldOmitAction(action)) return;

    final idx = actions.indexWhere(
      (a) => (a['_id'] ?? a['id']).toString() == aId,
    );

    if (idx >= 0) {
      actions[idx] = action;
    } else {
      actions.insert(0, action);
      highlightedActionIds.add(aId);
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) {
          setState(() => highlightedActionIds.remove(aId));
        }
      });
    }

    actions.sort(
      (a, b) => (b['date'] ?? '').toString().compareTo(
        (a['date'] ?? '').toString(),
      ),
    );
  }

  bool _shouldSkipForStats(Map<String, dynamic> action) {
    return _shouldOmitAction(action) ||
        _isTimeoutAction(action) ||
        _isMatchMilestone(action);
  }

  void _refreshGameStats({bool awardsImmediate = false}) {
    _calculateGameStats();
    if (awardsImmediate) {
      _recalculateMatchAwards(immediate: true);
    } else {
      _scheduleMatchAwardsRecalc();
    }
  }

  bool _canCalculateMatchAwards() {
    if (isLoading) return false;
    final id = (matchId ?? matchData['_id'] ?? matchData['id'] ?? '')
        .toString()
        .trim();
    if (id.isEmpty || matchData.isEmpty) return false;

    final hasHome = homeTeam.isNotEmpty ||
        MatchHelpers.asMap(matchData['home']).isNotEmpty;
    final hasVisitor = visitorTeam.isNotEmpty ||
        MatchHelpers.asMap(matchData['visitor']).isNotEmpty;
    return hasHome && hasVisitor;
  }

  MatchAwardsResult _computeMatchAwards() {
    if (!_canCalculateMatchAwards()) return MatchAwardsResult.empty;
    return calculateMatchAwards(
      match: matchData,
      players: _awardsPlayerPool(),
      actions: actions,
    );
  }

  void _recalculateMatchAwards({bool immediate = false}) {
    _matchAwardsRecalcTimer?.cancel();
    _matchAwardsRecalcTimer = null;

    if (!immediate && !mounted) return;

    final next = _computeMatchAwards();
    if (immediate) {
      _matchAwards = next;
      return;
    }

    if (!mounted) return;
    setState(() => _matchAwards = next);
  }

  void _scheduleMatchAwardsRecalc() {
    if (!_canCalculateMatchAwards()) return;

    _matchAwardsRecalcTimer?.cancel();
    _matchAwardsRecalcTimer = Timer(const Duration(milliseconds: 75), () {
      if (!mounted) return;
      _recalculateMatchAwards();
    });
  }

  List<Map<String, dynamic>> _awardsPlayerPool() {
    final pool = <Map<String, dynamic>>[];
    for (final raw in homeTeam['roster'] as List<dynamic>? ?? []) {
      if (raw is Map) pool.add(Map<String, dynamic>.from(raw));
    }
    for (final raw in visitorTeam['roster'] as List<dynamic>? ?? []) {
      if (raw is Map) pool.add(Map<String, dynamic>.from(raw));
    }
    return pool;
  }

  String _actionClave(Map<String, dynamic> action) =>
      (action['clave'] ?? action['type'] ?? '').toString().toLowerCase().trim();

  String _teamIdFromAction(Map<String, dynamic> action) {
    final team = action['team'];
    if (team is Map) {
      return (team['_id'] ?? team['id'] ?? '').toString().trim();
    }
    if (team != null) return team.toString().trim();
    return '';
  }

  String _entityId(dynamic entity) {
    if (entity is! Map) return '';
    return (entity['_id'] ?? entity['id'] ?? '').toString().trim();
  }

  bool _isHomeTeamAction(Map<String, dynamic> action) {
    final tId = _teamIdFromAction(action);
    if (tId.isEmpty) return false;

    final hId = (homeTeam['_id'] ?? homeTeam['id'] ?? '').toString().trim();
    final vId = (visitorTeam['_id'] ?? visitorTeam['id'] ?? '').toString().trim();
    if (hId.isNotEmpty && tId == hId) return true;
    if (vId.isNotEmpty && tId == vId) return false;

    final flatHome = (matchData['homeId'] ??
            matchData['idHome'] ??
            matchData['home_id'] ??
            '')
        .toString()
        .trim();
    final flatAway = (matchData['visitorId'] ??
            matchData['idVisitor'] ??
            matchData['visitor_id'] ??
            '')
        .toString()
        .trim();
    if (flatHome.isNotEmpty && tId == flatHome) return true;
    if (flatAway.isNotEmpty && tId == flatAway) return false;

    final hAcademy = homeTeam['academy'];
    final vAcademy = visitorTeam['academy'];
    final hAcademyId = (hAcademy is Map
            ? (hAcademy['id'] ?? hAcademy['_id'])
            : hAcademy)
        ?.toString()
        .trim() ??
        '';
    final vAcademyId = (vAcademy is Map
            ? (vAcademy['id'] ?? vAcademy['_id'])
            : vAcademy)
        ?.toString()
        .trim() ??
        '';
    if (hAcademyId.isNotEmpty && tId == hAcademyId) return true;
    if (vAcademyId.isNotEmpty && tId == vAcademyId) return false;

    return false;
  }

  bool _matchesActionClave(String clave, String key) {
    switch (key) {
      case 'pass':
        return clave == 'pass' || clave.contains('pase');
      case 'catch':
        return clave == 'catch' ||
            clave.contains('recep') ||
            clave.contains('reception');
      case 'run':
        return clave == 'run' || clave.contains('carrera');
      case 'sack':
        return clave == 'sack';
      case 'inter':
        return clave == 'inter' || clave.contains('intercep');
      default:
        return false;
    }
  }

  Map<String, dynamic>? _playerObjectForStat(
    Map<String, dynamic> action,
    String statKey,
  ) {
    switch (statKey) {
      case 'pass':
        final p = action['playerPass'];
        return p is Map ? Map<String, dynamic>.from(p) : null;
      case 'catch':
        final p = action['playerCatch'];
        return p is Map ? Map<String, dynamic>.from(p) : null;
      case 'pts':
      case 'run':
      case 'sack':
      case 'int':
        final p = action['player'];
        return p is Map ? Map<String, dynamic>.from(p) : null;
      default:
        return null;
    }
  }

  /// Atribuye puntos de una acción al jugador que anotó.
  /// En pases solo al receptor (`playerCatch`); nunca al pasador.
  void _creditPointsFromAction({
    required Map<String, Map<String, dynamic>> playerMap,
    required Map<String, dynamic> actMap,
    required String clave,
    required int pts,
    required bool isHome,
  }) {
    if (pts <= 0) return;

    _creditTeamStat(statKey: 'pts', isHome: isHome, value: pts);

    Map<String, dynamic>? scorer;
    if (_matchesActionClave(clave, 'pass')) {
      scorer = _playerObjectForStat(actMap, 'catch');
    } else {
      scorer = _playerObjectForStat(actMap, 'pts');
      scorer ??= _playerObjectForStat(actMap, 'catch');
    }

    _creditPlayerStat(
      playerMap: playerMap,
      playerObj: scorer,
      isHome: isHome,
      statKey: 'pts',
      value: pts,
    );
  }

  void _creditPlayerStat({
    required Map<String, Map<String, dynamic>> playerMap,
    required Map<String, dynamic>? playerObj,
    required bool isHome,
    required String statKey,
    required int value,
  }) {
    if (value <= 0 || playerObj == null) return;

    final pid = _entityId(playerObj);
    if (pid.isEmpty) return;

    playerMap.putIfAbsent(pid, () => {
          'id': pid,
          'name': playerObj['name'] ?? '',
          'alias': playerObj['alias'] ?? '',
          'number': playerObj['number'] ?? '',
          'photo': playerObj['photo'] ?? playerObj['thumb'] ?? '',
          'isHome': isHome,
          'pts': 0,
          'pass': 0,
          'catch': 0,
          'run': 0,
          'sack': 0,
          'int': 0,
        });

    if ((playerMap[pid]!['photo']?.toString() ?? '').isEmpty) {
      final rosterList = isHome
          ? (homeTeam['roster'] as List? ?? [])
          : (visitorTeam['roster'] as List? ?? []);
      for (var rp in rosterList) {
        if (rp is Map && _entityId(rp) == pid) {
          playerMap[pid]!['photo'] = rp['photo'] ?? rp['thumb'] ?? '';
          playerMap[pid]!['number'] = rp['number'] ?? playerMap[pid]!['number'];
          break;
        }
      }
    }

    playerMap[pid]![statKey] =
        (int.tryParse(playerMap[pid]![statKey]?.toString() ?? '0') ?? 0) + value;
  }

  void _creditTeamStat({
    required String statKey,
    required bool isHome,
    required int value,
  }) {
    if (value <= 0) return;
    final side = isHome ? 'home' : 'visit';
    _gameTotals[statKey] = (_gameTotals[statKey] ?? 0) + value;
    _teamTotals[statKey]![side] = (_teamTotals[statKey]![side] ?? 0) + value;
  }

  void _calculateGameStats() {
    _gameTotals = {
      'pts': 0,
      'pass': 0,
      'catch': 0,
      'run': 0,
      'sack': 0,
      'int': 0,
    };
    _teamTotals = {
      'pts': {'home': 0, 'visit': 0},
      'pass': {'home': 0, 'visit': 0},
      'catch': {'home': 0, 'visit': 0},
      'run': {'home': 0, 'visit': 0},
      'sack': {'home': 0, 'visit': 0},
      'int': {'home': 0, 'visit': 0},
    };
    _detailedStats = {
      'pts': {'home': [], 'visit': []},
      'pass': {'home': [], 'visit': []},
      'catch': {'home': [], 'visit': []},
      'run': {'home': [], 'visit': []},
      'sack': {'home': [], 'visit': []},
      'int': {'home': [], 'visit': []},
    };
    _statLeaders = {
      'pass': [],
      'run': [],
      'catch': [],
      'sack': [],
      'int': [],
    };
    final Map<String, Map<String, dynamic>> playerMap = {};

    for (var act in actions) {
      if (act is! Map) continue;
      final actMap = Map<String, dynamic>.from(act);
      if (_shouldSkipForStats(actMap)) continue;

      final clave = _actionClave(actMap);
      final pts = int.tryParse(actMap['points']?.toString() ?? '0') ?? 0;
      final isHome = _isHomeTeamAction(actMap);

      if (pts > 0) {
        _creditPointsFromAction(
          playerMap: playerMap,
          actMap: actMap,
          clave: clave,
          pts: pts,
          isHome: isHome,
        );
      }

      if (_matchesActionClave(clave, 'pass')) {
        final passer = _playerObjectForStat(actMap, 'pass');
        if (passer != null) {
          _creditTeamStat(statKey: 'pass', isHome: isHome, value: 1);
          _creditPlayerStat(
            playerMap: playerMap,
            playerObj: passer,
            isHome: isHome,
            statKey: 'pass',
            value: 1,
          );
        }
        final catcher = _playerObjectForStat(actMap, 'catch');
        if (catcher != null) {
          _creditTeamStat(statKey: 'catch', isHome: isHome, value: 1);
          _creditPlayerStat(
            playerMap: playerMap,
            playerObj: catcher,
            isHome: isHome,
            statKey: 'catch',
            value: 1,
          );
        }
      } else if (_matchesActionClave(clave, 'catch')) {
        _creditTeamStat(statKey: 'catch', isHome: isHome, value: 1);
        _creditPlayerStat(
          playerMap: playerMap,
          playerObj: _playerObjectForStat(actMap, 'catch'),
          isHome: isHome,
          statKey: 'catch',
          value: 1,
        );
      } else if (_matchesActionClave(clave, 'run')) {
        _creditTeamStat(statKey: 'run', isHome: isHome, value: 1);
        _creditPlayerStat(
          playerMap: playerMap,
          playerObj: _playerObjectForStat(actMap, 'run'),
          isHome: isHome,
          statKey: 'run',
          value: 1,
        );
      } else if (_matchesActionClave(clave, 'sack')) {
        _creditTeamStat(statKey: 'sack', isHome: isHome, value: 1);
        _creditPlayerStat(
          playerMap: playerMap,
          playerObj: _playerObjectForStat(actMap, 'sack'),
          isHome: isHome,
          statKey: 'sack',
          value: 1,
        );
      } else if (_matchesActionClave(clave, 'inter')) {
        _creditTeamStat(statKey: 'int', isHome: isHome, value: 1);
        _creditPlayerStat(
          playerMap: playerMap,
          playerObj: _playerObjectForStat(actMap, 'int'),
          isHome: isHome,
          statKey: 'int',
          value: 1,
        );
      }
    }

    final list = playerMap.values.toList();
    List<dynamic> filterSort(String stat) {
      final f = list
          .where((p) => (int.tryParse(p[stat]?.toString() ?? '0') ?? 0) > 0)
          .toList();
      f.sort((a, b) => (int.tryParse(b[stat]?.toString() ?? '0') ?? 0)
          .compareTo(int.tryParse(a[stat]?.toString() ?? '0') ?? 0));
      return f;
    }

    final ptsL = filterSort('pts');
    final passL = filterSort('pass');
    final catchL = filterSort('catch');
    final runL = filterSort('run');
    final sackL = filterSort('sack');
    final intL = filterSort('int');

    void assignByTeam(String stat, List<dynamic> sorted) {
      final home = sorted.where((p) => p['isHome'] == true).toList();
      final visit = sorted.where((p) => p['isHome'] != true).toList();
      home.sort((a, b) => (int.tryParse(b[stat]?.toString() ?? '0') ?? 0)
          .compareTo(int.tryParse(a[stat]?.toString() ?? '0') ?? 0));
      visit.sort((a, b) => (int.tryParse(b[stat]?.toString() ?? '0') ?? 0)
          .compareTo(int.tryParse(a[stat]?.toString() ?? '0') ?? 0));
      _detailedStats[stat]!['home'] = home;
      _detailedStats[stat]!['visit'] = visit;
    }

    assignByTeam('pts', ptsL);
    assignByTeam('pass', passL);
    assignByTeam('catch', catchL);
    assignByTeam('run', runL);
    assignByTeam('sack', sackL);
    assignByTeam('int', intL);

    List<Map<String, dynamic>> topLeaders(List<dynamic> sorted, String stat) {
      if (sorted.isEmpty) return [];
      final maxV = int.tryParse(sorted.first[stat]?.toString() ?? '0') ?? 0;
      if (maxV <= 0) return [];
      return sorted
          .where(
            (p) => (int.tryParse(p[stat]?.toString() ?? '0') ?? 0) == maxV,
          )
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
    }

    _statLeaders['pass'] = topLeaders(passL, 'pass');
    _statLeaders['run'] = topLeaders(runL, 'run');
    _statLeaders['catch'] = topLeaders(catchL, 'catch');
    _statLeaders['sack'] = topLeaders(sackL, 'sack');
    _statLeaders['int'] = topLeaders(intL, 'int');

    _playerGameStats = playerMap.map(
      (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
    );
    _rebuildSpecialMentionPlayers();
  }

  Future<void> _loadMentionUserProfiles() async {
    if (_mentionProfilesLoadStarted) return;
    _mentionProfilesLoadStarted = true;

    try {
      final storage = StorageService();
      final session = await storage.getJson(AppConfig.sessionKey);
      final uid = session?['uid']?.toString().trim() ?? '';
      if (uid.isEmpty) return;

      final res = await widget.api.getUserContextV2(uid);
      if (res['status'] != 'ok') return;

      final dash = res['dashboard'];
      if (dash is! Map) return;

      final managed = (dash['profiles'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((p) => p['relation']?.toString() != 'followed')
          .toList();
      final followed = (dash['following']?['players'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) {
            final profile = Map<String, dynamic>.from(e);
            profile['relation'] = 'followed';
            return profile;
          })
          .toList();

      _mentionUserProfiles = [...managed, ...followed];
    } catch (_) {
      // Sin perfiles no se muestra la sección si no hay relatedPlayers.
    }

    if (!mounted) return;
    _rebuildSpecialMentionPlayers();
    setState(() {});
  }

  List<Map<String, dynamic>> _rosterAsMaps(List<dynamic>? raw) {
    return raw
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
  }

  Map<String, dynamic>? _matchSnapshotFromUserStore() {
    final id = (matchId ?? MatchHelpers.matchId(matchData)).trim();
    if (id.isEmpty) return null;
    for (final match in UserMatchesStore.instance.allMatches) {
      if (MatchHelpers.matchId(match) == id) {
        return Map<String, dynamic>.from(match);
      }
    }
    return null;
  }

  void _rebuildSpecialMentionPlayers() {
    final rosterIndex = MatchHelpers.rosterIndex(
      homeRoster: _rosterAsMaps(homeTeam['roster'] as List<dynamic>?),
      visitorRoster: _rosterAsMaps(visitorTeam['roster'] as List<dynamic>?),
    );

    final matchForRelated = Map<String, dynamic>.from(matchData);
    final storeMatch = _matchSnapshotFromUserStore();
    if (storeMatch != null) {
      final storeRelated = storeMatch['relatedPlayers'];
      final currentRelated = matchForRelated['relatedPlayers'] as List<dynamic>?;
      if (storeRelated is List &&
          storeRelated.isNotEmpty &&
          (currentRelated == null || currentRelated.isEmpty)) {
        matchForRelated['relatedPlayers'] = storeRelated;
      }
    }

    _specialMentionPlayers = MatchHelpers.specialMentionPlayersInMatch(
      match: matchForRelated,
      rosterByPlayerId: rosterIndex,
      userProfiles: _mentionUserProfiles,
    );
  }

  String _getTeamLogoUrl(Map<String, dynamic> t) {
    for (var k in ['thumb', 'logo', 'img', 'image']) {
      final val = (t[k] ?? '').toString().trim();
      if (val.isNotEmpty && val != 'null' && val != 'None' && val.length > 5) {
        return _resolveMedia(val);
      }
    }
    if (t['academy'] is Map) {
      final a = t['academy'];
      for (var k in ['thumb', 'logo']) {
        final val = (a[k] ?? '').toString().trim();
        if (val.isNotEmpty && val != 'null' && val != 'None' && val.length > 5) {
          return _resolveMedia(val);
        }
      }
    }
    return '';
  }

  String _resolveMedia(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return 'https://cuerposallimite.net$url';
    return 'https://cuerposallimite.net/nlff/resources/images/$url';
  }

  bool _checkPossession(Map<String, dynamic> team, String possId) {
    final pId = possId.trim();
    if (pId.isEmpty || pId == 'null') return false;

    final teamId = (team['_id'] ?? team['id'] ?? team['teamId'] ?? '').toString().trim();
    if (teamId.isNotEmpty && teamId == pId) return true;

    final academy = team['academy'];
    final academyId = (academy is Map ? (academy['id'] ?? academy['_id']) : academy)?.toString().trim() ?? '';
    if (academyId.isNotEmpty && academyId == pId) return true;

    final isHome = teamId == (homeTeam['_id'] ?? homeTeam['id'] ?? '').toString();
    final flatHome = (matchData['homeId'] ?? matchData['idHome'] ?? matchData['home_id'] ?? '').toString().trim();
    final flatAway = (matchData['visitorId'] ?? matchData['idVisitor'] ?? matchData['visitor_id'] ?? '').toString().trim();
    if (isHome && flatHome.isNotEmpty && flatHome == pId) return true;
    if (!isHome && flatAway.isNotEmpty && flatAway == pId) return true;

    return false;
  }

  Map<String, dynamic> _getActionConfig(
    String claveStr,
    int points, {
    Map<String, dynamic>? action,
  }) {
    final c = claveStr.toLowerCase();
    final name = action != null
        ? (action['name'] ?? '').toString().toUpperCase()
        : '';

    if (_isExtraPointFailure(action ?? {}, claveStr, points)) {
      return {
        'abbr': 'XP',
        'color': Colors.white.withValues(alpha: 0.45),
      };
    }

    if (c == 'inter' || c.contains('intercep')) {
      return {'abbr': 'INT', 'color': const Color(0xFFFF5252)};
    }
    if (c == 'sack') {
      return {'abbr': 'SCK', 'color': Colors.orange};
    }

    if (points > 0 && (c.contains('td') || c.contains('touchdown'))) {
      return {'abbr': 'TD', 'color': brandPrimary};
    }
    if (points > 0) {
      return {'abbr': 'PTS', 'color': brandPrimary};
    }
    if (c.contains('pass') || c.contains('pase')) {
      return {'abbr': 'PAS', 'color': Colors.blueAccent};
    }
    if (c.contains('run') || c.contains('carrera')) {
      return {'abbr': 'CAR', 'color': Colors.orangeAccent};
    }
    if (c.contains('safety')) return {'abbr': 'SAF', 'color': Colors.red};
    if (c.contains('inc')) return {'abbr': 'INC', 'color': Colors.grey};
    if (c.contains('xp1') || c.contains('xp2') || c.contains('xp')) {
      return {'abbr': c.toUpperCase(), 'color': brandPrimary};
    }
    return {'abbr': 'JUG', 'color': Colors.grey};
  }

  bool _isExtraPointFailure(
    Map<String, dynamic> action,
    String claveStr,
    int points,
  ) {
    final c = claveStr.toLowerCase();
    final name = (action['name'] ?? '').toString().toUpperCase();
    final isXp =
        c.contains('xp') ||
        c.contains('extra_point') ||
        c.contains('punto_extra') ||
        name.contains('PUNTO EXTRA') ||
        name.contains('EXTRA POINT');

    if (!isXp) return false;

    if (name.contains('FALLO') ||
        name.contains('FALL') ||
        name.contains('FALLIDO') ||
        name.contains('NO GOOD') ||
        name.contains('NO CONVERT')) {
      return true;
    }

    return points <= 0;
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    if (isLoading && matchData.isEmpty) {
      return const Scaffold(backgroundColor: brandBg, body: Center(child: CircularProgressIndicator(color: brandPrimary)));
    }
    if (errorMessage != null && matchData.isEmpty) {
      return Scaffold(backgroundColor: brandBg, appBar: AppBar(backgroundColor: Colors.transparent), body: Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.white))));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: brandBg,
        body: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (ctx, scrolled) {
            return [
              SliverAppBar(
                expandedHeight: 252,
                toolbarHeight: 52,
                pinned: true,
                backgroundColor: brandBg,
                centerTitle: true,
                automaticallyImplyLeading: false,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: InkWell(
                    onTap: () => popOrGoHome(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
                    ),
                  ),
                ),
                title: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _isCompactHeader
                      ? _buildCompactHeader()
                      : _buildHeaderCategoryLabel(),
                ),
                actions: [
                  if (!_isCompactHeader)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildHeaderDateStatus(),
                    ),
                  if (_isCompactHeader && _isMatchLive() && _isSocketConnected())
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(child: _buildMiniStatusBadge()),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _buildScoreboardSection(),
                ),
                bottom: TabBar(
                  indicatorColor: brandPrimary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.0,
                    fontFamily: 'Oswald',
                  ),
                  tabs: const [
                    Tab(text: 'JUGADAS'),
                    Tab(text: 'ESTADÍSTICAS'),
                    Tab(text: 'ROSTER'),
                  ],
                ),
              ),
            ];
          },
          body: Column(
            children: [
              if (_isMatchLive() && !_isSocketConnected()) _buildLiveSyncBanner(),
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildPlaysTab(),
                    _buildStatsTab(),
                    _buildRosterTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCategoryLabel() {
    final catRaw = MatchHelpers.categoryName(matchData) ?? '';
    return CategoryPalette.buildDarkCardLabel(
      catRaw,
      fontSize: 18,
      fontWeight: FontWeight.w800,
      textAlign: TextAlign.center,
      fallbackLabel: catRaw.isEmpty
          ? 'CATEGORÍA'
          : CategoryPalette.shortName(catRaw),
    );
  }

  Widget _buildHeaderDateStatus() {
    final dateStr = (matchData['date'] ?? '').toString();
    final status = (matchData['gameStatus'] ?? 'scheduled').toString();
    final isFinished = status == 'finished';
    final isLive = status == 'live' || status == 'in_progress';

    String shortDate = '';
    if (dateStr.isNotEmpty) {
      try {
        final d = DateTime.parse(dateStr).toLocal();
        shortDate = DateFormat('EEE d MMM', 'es_ES').format(d).toUpperCase();
      } catch (_) {}
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (shortDate.isNotEmpty)
          Text(
            shortDate,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (shortDate.isNotEmpty) const SizedBox(width: 8),
        if (isLive && _isSocketConnected())
          _buildMiniStatusBadge()
        else if (isFinished)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'FINAL',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  String _teamDisplayName(Map<String, dynamic> team, String fallback) {
    final short = (team['shortName'] ?? '').toString().trim();
    if (short.isNotEmpty) return short.toUpperCase();
    final raw = (team['name'] ?? fallback).toString().trim();
    if (raw.isEmpty) return fallback.toUpperCase();
    final parts = raw.split(RegExp(r'\s+'));
    if (parts.length > 2) return parts.last.toUpperCase();
    return raw.toUpperCase();
  }

  String _fieldLabel() {
    final field = (matchData['field'] ?? matchData['campo'] ?? '').toString().trim();
    if (field.isEmpty) return '';
    final upper = field.toUpperCase();
    if (upper.startsWith('CAMPO')) return upper;
    return 'CAMPO $upper';
  }

  String _sedeLabel() {
    final sede = matchData['sede'];
    if (sede is Map) {
      return (sede['name'] ?? '').toString().trim().toUpperCase();
    }
    return sede?.toString().trim().toUpperCase() ?? '';
  }

  Widget _buildScoreboardSection() {
    final fieldLabel = _fieldLabel();
    final sedeLabel = _sedeLabel();
    final status = (matchData['gameStatus'] ?? 'scheduled').toString();
    final isLive = status == 'live' || status == 'in_progress';
    final isFinished = status == 'finished';

    final hName = _teamDisplayName(homeTeam, 'LOCAL');
    final vName = _teamDisplayName(visitorTeam, 'VISITA');
    final hPts = homeTeam['points']?.toString() ?? '0';
    final vPts = visitorTeam['points']?.toString() ?? '0';
    final hLogo = _getTeamLogoUrl(homeTeam);
    final vLogo = _getTeamLogoUrl(visitorTeam);
    final possId = (matchData['possessionTeamId'] ?? '').toString();

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: brandBg),
        Positioned(
          left: -40,
          top: 40,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: brandPrimary.withValues(alpha: 0.18),
                  blurRadius: 80,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: -40,
          top: 60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: visitColor.withValues(alpha: 0.18),
                  blurRadius: 80,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 56, 12, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: _buildGlowingLogo(
                              hLogo,
                              brandPrimary,
                              _checkPossession(homeTeam, possId),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: _buildCenterScoreBlock(
                            fieldLabel: fieldLabel,
                            hPts: hPts,
                            vPts: vPts,
                            isLive: isLive,
                            isFinished: isFinished,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: _buildGlowingLogo(
                              vLogo,
                              visitColor,
                              _checkPossession(visitorTeam, possId),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              Text(
                                hName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.oswald(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'LOCAL',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: brandPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Expanded(flex: 4, child: SizedBox.shrink()),
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              Text(
                                vName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.oswald(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'VISITA',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: visitColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (sedeLabel.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        sedeLabel,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.32),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ],
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildCenterScoreBlock({
    required String fieldLabel,
    required String hPts,
    required String vPts,
    required bool isLive,
    required bool isFinished,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (fieldLabel.isNotEmpty)
          Text(
            fieldLabel,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (fieldLabel.isNotEmpty) const SizedBox(height: 4),
        if (isLive || isFinished)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  hPts,
                  key: ValueKey('h$hPts'),
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '-',
                  style: GoogleFonts.oswald(
                    color: Colors.white24,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  vPts,
                  key: ValueKey('v$vPts'),
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ],
          )
        else
          Text(
            'VS',
            style: GoogleFonts.oswald(
              color: Colors.white24,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
            ),
          ),
        const SizedBox(height: 6),
        if (isLive)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (ctx, _) => Opacity(
              opacity: 0.65 + (_pulseController.value * 0.35),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'EN VIVO • ${_getMatchPeriod()}T',
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          )
        else if (isFinished)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'FINALIZADO',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  String _getMatchPeriod() {
    final v = (matchData['currentHalf'] ?? matchData['half'] ?? matchData['periodo'] ?? matchData['tiempo'] ?? '').toString();
    if (v.isEmpty || v == '0' || v == 'NULL' || v == 'OT') return '1';
    return v;
  }

  Widget _buildGlowingLogo(String url, Color color, bool hasPossession) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (hasPossession)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (ctx, child) {
              final pulse = 0.6 + (_pulseController.value * 0.4);
              return Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45 * pulse),
                      blurRadius: 22 * pulse,
                      spreadRadius: 4 * pulse,
                    ),
                  ],
                ),
              );
            },
          ),
        Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: hasPossession ? 1.0 : 0.85),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipOval(
            child: url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.shield,
                      color: Colors.white.withValues(alpha: 0.24),
                      size: 32,
                    ),
                  )
                : Icon(
                    Icons.shield,
                    color: Colors.white.withValues(alpha: 0.24),
                    size: 32,
                  ),
          ),
        ),
        if (hasPossession)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(Icons.sports_rugby, color: color, size: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactHeader() {
    final catRaw = MatchHelpers.categoryName(matchData) ?? '';
    final catLabel = catRaw.isEmpty
        ? 'CAT'
        : CategoryPalette.shortName(catRaw).toUpperCase();
    final hPts = homeTeam['points']?.toString() ?? '0';
    final vPts = visitorTeam['points']?.toString() ?? '0';
    final hLogo = _getTeamLogoUrl(homeTeam);
    final vLogo = _getTeamLogoUrl(visitorTeam);

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: brandSurface,
            backgroundImage:
                hLogo.isNotEmpty ? NetworkImage(hLogo) : null,
            child: hLogo.isEmpty
                ? const Icon(Icons.shield, size: 14)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            hPts,
            style: GoogleFonts.oswald(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 88),
              child: Text(
                catLabel,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.oswald(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            vPts,
            style: GoogleFonts.oswald(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 14,
            backgroundColor: brandSurface,
            backgroundImage:
                vLogo.isNotEmpty ? NetworkImage(vLogo) : null,
            child: vLogo.isEmpty
                ? const Icon(Icons.shield, size: 14)
                : null,
          ),
        ],
      ),
    );
  }

  bool _isSocketConnected() =>
      _socketState == SocketConnectionState.connected;

  Widget _buildMiniStatusBadge() {
    final status = (matchData['gameStatus'] ?? 'scheduled').toString();
    if (status == 'live' || status == 'in_progress') {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (ctx, child) => Opacity(
          opacity: 0.6 + (_pulseController.value * 0.4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'VIVO',
                  style: GoogleFonts.oswald(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (status == 'finished') {
      return Text(
        'FINAL',
        style: GoogleFonts.inter(
          color: textMuted,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildLiveSyncBanner() {
    final isRetrying = _socketState == SocketConnectionState.reconnecting ||
        _socketState == SocketConnectionState.connecting;
    final attempts = _socketReconnectAttempt;
    final lastLabel = _lastLiveUpdateAt != null
        ? DateFormat('HH:mm', 'es_ES').format(_lastLiveUpdateAt!.toLocal())
        : null;

    final Color accent = isRetrying && attempts < 10
        ? Colors.orange.withValues(alpha: 0.85)
        : Colors.white54;
    final String message = isRetrying && attempts < 10
        ? 'Reintentando conexión… ($attempts)'
        : lastLabel != null
            ? 'Sin conexión · actualizado $lastLabel'
            : 'Sin conexión en vivo';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          if (isRetrying && attempts < 10)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: accent,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.cloud_off, size: 14, color: accent),
            ),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isRetrying || attempts >= 10)
            _isManualRefreshing
                ? Padding(
                    padding: const EdgeInsets.all(4),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: accent,
                      ),
                    ),
                  )
                : InkWell(
                    onTap: _manualRefreshMatch,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.refresh, color: accent, size: 16),
                    ),
                  ),
        ],
      ),
    );
  }

  bool _isMatchLive() {
    final status = (matchData['gameStatus'] ?? '').toString();
    return status == 'live' || status == 'in_progress';
  }

  bool _isMatchFinished() {
    return (matchData['gameStatus'] ?? '').toString() == 'finished';
  }

  int _actionDateCompare(Map<String, dynamic> a, Map<String, dynamic> b) {
    return (a['date'] ?? '').toString().compareTo((b['date'] ?? '').toString());
  }

  List<Map<String, dynamic>> _actionsForDisplay() {
    final list = actions
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .where((a) => !_shouldOmitAction(a))
        .toList();

    if (_isMatchFinished()) {
      list.sort(_actionDateCompare);
    } else if (_isMatchLive()) {
      list.sort((a, b) => _actionDateCompare(b, a));
    } else {
      list.sort((a, b) => _actionDateCompare(b, a));
    }

    return list;
  }

  String _actionTimeLabel(Map<String, dynamic> action) {
    final raw = (action['date'] ?? action['time'] ?? '').toString();
    if (raw.isEmpty) return '';
    try {
      if (raw.contains(' ')) {
        final parts = raw.split(' ');
        if (parts.length > 1) {
          final hm = parts[1].split(':');
          if (hm.length >= 2) return '${hm[0]}:${hm[1]}';
        }
      }
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return '';
  }

  bool _shouldOmitAction(Map<String, dynamic> action) {
    final name = (action['name'] ?? '').toString().toLowerCase();
    final clave = (action['clave'] ?? action['type'] ?? '').toString().toLowerCase();

    if (name.contains('cambio de posesión') ||
        name.contains('cambio de posesion') ||
        clave.contains('possession') ||
        clave == 'possession') {
      return true;
    }

    if (name.contains('expuls') ||
        name.contains('eject') ||
        clave.contains('expuls') ||
        clave.contains('ejection') ||
        clave.contains('eject')) {
      return true;
    }

    return false;
  }

  bool _isKickOffMilestoneName(String nameUpper) {
    if (nameUpper.contains('TIEMPO FUERA') || nameUpper.contains('TIMEOUT')) {
      return false;
    }
    if (nameUpper.contains('KICK OFF') || nameUpper.contains('KICKOFF')) {
      return true;
    }
    if (nameUpper.contains('INICIO') &&
        (nameUpper.contains('PARTIDO') ||
            nameUpper.contains('JUEGO') ||
            nameUpper.contains('MITAD') ||
            nameUpper.contains('2DA') ||
            nameUpper.contains('SEGUNDA'))) {
      return true;
    }
    if (nameUpper.contains('INICIO') && nameUpper.contains('MITAD')) {
      return true;
    }
    return nameUpper.contains('PARTIDO FINALIZADO') ||
        nameUpper.contains('FIN DEL PARTIDO') ||
        nameUpper.contains('FIN DEL JUEGO') ||
        nameUpper.contains('FIN DE JUEGO');
  }

  bool _isTimeoutAction(Map<String, dynamic> action) {
    final name = (action['name'] ?? '').toString().toUpperCase();
    final clave = (action['clave'] ?? action['type'] ?? '').toString().toLowerCase();
    return name.contains('TIEMPO FUERA') ||
        name.contains('TIMEOUT') ||
        clave.contains('timeout') ||
        clave.contains('tiempo_fuera');
  }

  bool _isMatchMilestone(Map<String, dynamic> action) {
    if (_isTimeoutAction(action) || _shouldOmitAction(action)) return false;

    final name = (action['name'] ?? '').toString().toUpperCase();
    final clave = (action['clave'] ?? action['type'] ?? '').toString().toLowerCase();

    if (clave.contains('kickoff') || clave.contains('kick_off')) return true;

    if (clave == 'system' || clave == 'sistema') {
      return _isKickOffMilestoneName(name);
    }

    return _isKickOffMilestoneName(name);
  }

  Map<String, String> _computeRunningScores() {
    final sorted = actions
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .where((a) => !_shouldOmitAction(a))
        .toList();
    sorted.sort(
      (a, b) => (a['date'] ?? '').toString().compareTo(
        (b['date'] ?? '').toString(),
      ),
    );

    final hId = (homeTeam['_id'] ?? homeTeam['id'] ?? '').toString();
    int h = 0;
    int v = 0;
    final out = <String, String>{};

    for (final a in sorted) {
      if (_shouldOmitAction(a)) continue;
      final pts = int.tryParse(a['points']?.toString() ?? '0') ?? 0;
      final tId = (a['team'] is Map
              ? (a['team']['_id'] ?? a['team']['id'])
              : '')
          ?.toString() ??
          '';

      if (pts > 0 && tId.isNotEmpty) {
        if (tId == hId) {
          h += pts;
        } else {
          v += pts;
        }
      }

      final fromAction = a['scoreHome'] ?? a['homePoints'] ?? a['scoreH'];
      final fromVisitor = a['scoreVisitor'] ?? a['visitorPoints'] ?? a['scoreV'];
      if (fromAction != null && fromVisitor != null) {
        h = int.tryParse(fromAction.toString()) ?? h;
        v = int.tryParse(fromVisitor.toString()) ?? v;
      }

      final id = (a['_id'] ?? a['id'] ?? '').toString();
      if (id.isNotEmpty) out[id] = '$h-$v';
    }

    return out;
  }

  Widget _buildFeedDividerRow(String label, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          time.isNotEmpty ? '$label $time' : label,
          textAlign: TextAlign.center,
          style: GoogleFonts.oswald(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeoutRow(Map<String, dynamic> action, String timeStr) {
    final teamName = (action['team'] is Map
            ? action['team']['name']
            : action['teamName'] ?? '')
        .toString()
        .trim()
        .toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.white24, width: 2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.timer_outlined, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'TIEMPO FUERA',
                      style: GoogleFonts.oswald(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: GoogleFonts.inter(
                          color: Colors.white24,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                if (teamName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    teamName,
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: JUGADAS ---

  Widget _buildPlaysTab() {
    if (actions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: textMuted, size: 40),
            const SizedBox(height: 16),
            Text(
              'Aún no hay acciones registradas.',
              style: GoogleFonts.inter(color: textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final hId = (homeTeam['_id'] ?? homeTeam['id'] ?? '').toString();
    final runningScores = _computeRunningScores();
    final displayActions = _actionsForDisplay();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 40),
      itemCount: displayActions.length,
      itemBuilder: (ctx, idx) {
        final a = displayActions[idx];
        final aId = (a['_id'] ?? a['id'] ?? '').toString();
        final timeStr = _actionTimeLabel(a);

        if (_isMatchMilestone(a)) {
          final name = (a['name'] ?? '').toString().toUpperCase();
          return _buildFeedDividerRow(name, timeStr);
        }

        if (_isTimeoutAction(a)) {
          return _buildTimeoutRow(a, timeStr);
        }

        final clave = (a['clave'] ?? a['type'] ?? '').toString();
        final pts = int.tryParse(a['points']?.toString() ?? '0') ?? 0;
        final tId = (a['team'] is Map
                ? (a['team']['_id'] ?? a['team']['id'])
                : '')
            ?.toString() ??
            '';

        final isHome = tId == hId;
        final sideColor = isHome ? brandPrimary : visitColor;
        final isHighlighted = highlightedActionIds.contains(aId);
        final runningScore = runningScores[aId] ?? '';

        final pPass = a['playerPass'] is Map ? a['playerPass'] as Map : null;
        final pCatch = a['playerCatch'] is Map ? a['playerCatch'] as Map : null;
        final pBase = a['player'] is Map ? a['player'] as Map : null;
        final isPass = clave.toLowerCase().contains('pass') &&
            pPass != null &&
            pCatch != null;

        final rawName = (a['name'] ?? '').toString();
        final cleanName = rawName.replaceAll('SISTEMA:', '').trim().toUpperCase();
        final conf = _getActionConfig(clave, pts, action: a);
        final isXpFail = _isExtraPointFailure(a, clave, pts);
        final actionColor = conf['color'] as Color;
        final nameColor = isXpFail
            ? Colors.white.withValues(alpha: 0.45)
            : (pts > 0 ? Colors.white : actionColor);
        final playerLineColor = isXpFail
            ? Colors.white.withValues(alpha: 0.32)
            : textMuted;
        final logoUrl = isHome ? _getTeamLogoUrl(homeTeam) : _getTeamLogoUrl(visitorTeam);

        String playerLine = '';
        if (isPass) {
          playerLine =
              '#${pPass['number'] ?? ''} ${(pPass['alias'] ?? pPass['name'] ?? 'QB').toString().toUpperCase()}'
              ' -> '
              '#${pCatch['number'] ?? ''} ${(pCatch['alias'] ?? pCatch['name'] ?? 'WR').toString().toUpperCase()}';
        } else if (pBase != null) {
          playerLine =
              '#${pBase['number'] ?? ''} ${(pBase['alias'] ?? pBase['name'] ?? '').toString().toUpperCase()}';
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isHighlighted
                ? neonCyan.withValues(alpha: 0.06)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isHighlighted ? neonCyan : sideColor,
                width: isHighlighted ? 3 : 2,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brandSurface,
                  image: logoUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(logoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: logoUrl.isEmpty
                    ? Icon(Icons.shield, color: Colors.white24, size: 14)
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          cleanName,
                          style: GoogleFonts.oswald(
                            color: nameColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (pts > 0)
                          Text(
                            '+$pts',
                            style: GoogleFonts.oswald(
                              color: brandPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: GoogleFonts.inter(
                              color: Colors.white24,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    if (playerLine.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        playerLine,
                        style: GoogleFonts.inter(
                          color: playerLineColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (runningScore.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text(
                    runningScore,
                    style: GoogleFonts.oswald(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 2: ESTADÍSTICAS ---

  Widget _buildStatsTab() {
    final hasData = _gameTotals.values.any((v) => v > 0) ||
        _specialMentionPlayers.isNotEmpty;
    if (!hasData) {
      return Center(child: Text('Datos insuficientes.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)));
    }

    return ListView(
      controller: _statsScrollController,
      padding: const EdgeInsets.all(16),
      children: [
        if (_specialMentionPlayers.isNotEmpty) ...[
          MatchSpecialMentionSection(
            players: _specialMentionPlayers,
            gameStatsByPlayerId: _playerGameStats,
            homeTeamName: _teamDisplayName(homeTeam, 'LOCAL'),
            visitorTeamName: _teamDisplayName(visitorTeam, 'VISITA'),
            homeColor: brandPrimary,
            visitColor: visitColor,
            mutedTextColor: textMuted,
            resolveMediaUrl: MatchHelpers.resolveMediaUrl,
          ),
          const SizedBox(height: 24),
        ],

        _buildStatLeadersSection(),

        const SizedBox(height: 24),
        RepaintBoundary(
          child: MatchAwardsSection(
            key: const ValueKey('match-awards-section'),
            matchAwards: _matchAwards,
            homeTeam: homeTeam,
            visitorTeam: visitorTeam,
            surfaceColor: brandSurface,
            accentColor: brandPrimary,
            visitColor: visitColor,
            mutedTextColor: textMuted,
            resolveMediaUrl: MatchHelpers.resolveMediaUrl,
          ),
        ),

        const SizedBox(height: 24),
        _buildComparativaSection(),

        const SizedBox(height: 24),
        _buildActionBreakdownSection(),
      ],
    );
  }

  Widget _buildComparativaSection() {
    int teamTotal(String stat, bool isHome) =>
        _teamTotals[stat]?[isHome ? 'home' : 'visit'] ?? 0;

    return Column(
      children: [
        Text(
          'Comparativa',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        _buildComparativaTeamHeader(),
        const SizedBox(height: 6),
        _DuelStatBar(
          key: const ValueKey('duel-pass'),
          title: 'PASES',
          homeVal: teamTotal('pass', true),
          visitVal: teamTotal('pass', false),
          homeColor: brandPrimary,
          visitColor: visitColor,
        ),
        _DuelStatBar(
          key: const ValueKey('duel-catch'),
          title: 'RECEPCIONES',
          homeVal: teamTotal('catch', true),
          visitVal: teamTotal('catch', false),
          homeColor: brandPrimary,
          visitColor: visitColor,
        ),
        _DuelStatBar(
          key: const ValueKey('duel-run'),
          title: 'CARRERAS',
          homeVal: teamTotal('run', true),
          visitVal: teamTotal('run', false),
          homeColor: brandPrimary,
          visitColor: visitColor,
        ),
        _DuelStatBar(
          key: const ValueKey('duel-sack'),
          title: 'SACKS',
          homeVal: teamTotal('sack', true),
          visitVal: teamTotal('sack', false),
          homeColor: brandPrimary,
          visitColor: visitColor,
        ),
        _DuelStatBar(
          key: const ValueKey('duel-int'),
          title: 'INTERCEPCIONES',
          homeVal: teamTotal('int', true),
          visitVal: teamTotal('int', false),
          homeColor: brandPrimary,
          visitColor: visitColor,
        ),
      ],
    );
  }

  Widget _buildStatLeadersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events_outlined, color: brandPrimary, size: 18),
            const SizedBox(width: 8),
            Text(
              'LÍDERES POR ESTADÍSTICA',
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Máximo individual por categoría en el partido',
          style: GoogleFonts.inter(color: textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            itemCount: _statLeaderCategories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              final category = _statLeaderCategories[index];
              final players = _statLeaders[category.$1] ?? [];
              return _buildStatLeaderCard(
                title: category.$2,
                statKey: category.$1,
                statLabel: category.$3,
                players: players,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatLeaderCard({
    required String title,
    required String statKey,
    required String statLabel,
    required List<Map<String, dynamic>> players,
  }) {
    const cardWidth = 148.0;
    const cardHeight = 188.0;

    if (players.isEmpty) {
      return Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          color: brandSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: Text(
            'SIN DATOS',
            style: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
          ),
        ),
      );
    }

    final isTie = players.length > 1;
    final leader = players.first;
    final val = leader[statKey]?.toString() ?? '0';
    final photoUrl = MatchHelpers.playerSpotlightPhotoUrl(leader);
    final pColor = leader['isHome'] == true ? brandPrimary : visitColor;
    final displayName = MatchHelpers.playerDisplayName(leader);

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pColor.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: pColor.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photoUrl.isNotEmpty)
            Image.network(
              photoUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) => ColoredBox(
                color: Color.alphaBlend(
                  pColor.withValues(alpha: 0.12),
                  const Color(0xFF0B1220),
                ),
              ),
            )
          else
            ColoredBox(
              color: Color.alphaBlend(
                pColor.withValues(alpha: 0.12),
                const Color(0xFF0B1220),
              ),
              child: Center(
                child: Text(
                  MatchHelpers.playerInitials(leader),
                  style: GoogleFonts.oswald(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  pColor.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.9),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(color: pColor.withValues(alpha: 0.65)),
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: pColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  height: 1.15,
                ),
              ),
            ),
          ),
          if (isTie)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'EMPATE',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTie
                      ? 'EMPATE (${players.length})'
                      : displayName.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      val,
                      style: GoogleFonts.oswald(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        statLabel,
                        style: GoogleFonts.inter(
                          color: pColor.withValues(alpha: 0.85),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _breakdownStatKey() {
    for (final c in _breakdownCategories) {
      if (c.$1 == _selectedCategory) return c.$2;
    }
    return 'pts';
  }

  String _breakdownCategoryTitle() {
    for (final c in _breakdownCategories) {
      if (c.$1 == _selectedCategory) return c.$3;
    }
    return 'PUNTOS';
  }

  Widget _buildActionBreakdownSection() {
    final stat = _breakdownStatKey();
    final categoryTitle = _breakdownCategoryTitle();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_list_numbered_rounded, color: brandPrimary, size: 18),
            const SizedBox(width: 8),
            Text(
              'DESGLOSE',
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Jugadores por acción, ordenados y agrupados por equipo',
          style: GoogleFonts.inter(color: textMuted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _breakdownCategories.map((c) {
              final selected = _selectedCategory == c.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: selected ? brandPrimary : brandSurface,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = c.$1),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? brandPrimary : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        c.$1,
                        style: GoogleFonts.oswald(
                          color: selected ? Colors.black : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          categoryTitle,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final homePanel = _buildBreakdownTeamPanel(isHome: true, stat: stat);
            final visitPanel = _buildBreakdownTeamPanel(isHome: false, stat: stat);
            if (constraints.maxWidth >= 520) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: homePanel),
                  const SizedBox(width: 12),
                  Expanded(child: visitPanel),
                ],
              );
            }
            return Column(
              children: [
                homePanel,
                const SizedBox(height: 12),
                visitPanel,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBreakdownTeamPanel({required bool isHome, required String stat}) {
    final team = isHome ? homeTeam : visitorTeam;
    final color = isHome ? brandPrimary : visitColor;
    final list = _detailedStats[stat]![isHome ? 'home' : 'visit']!;
    final teamTotal = _teamTotals[stat]?[isHome ? 'home' : 'visit'] ?? 0;
    final name = _teamDisplayName(team, isHome ? 'LOCAL' : 'VISITA');
    final logoUrl = _getTeamLogoUrl(team);
    final statLabel = stat == 'catch' ? 'REC' : stat.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: brandSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(color: color.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                if (logoUrl.isNotEmpty)
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                      image: DecorationImage(
                        image: NetworkImage(logoUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.oswald(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$teamTotal $statLabel',
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Sin jugadores con esta acción',
                      style: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
                    ),
                  )
                : Column(
                    children: list.asMap().entries.map((entry) {
                      return _buildBreakdownPlayerRow(
                        player: entry.value,
                        rank: entry.key + 1,
                        stat: stat,
                        color: color,
                        teamTotal: teamTotal,
                        statLabel: statLabel,
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownPlayerRow({
    required dynamic player,
    required int rank,
    required String stat,
    required Color color,
    required int teamTotal,
    required String statLabel,
  }) {
    final val = int.tryParse(player[stat]?.toString() ?? '0') ?? 0;
    final pct = teamTotal > 0 ? val / teamTotal : 0.0;
    final photo = (player['photo'] ?? player['thumb'] ?? '').toString();
    final name = (player['alias'] ?? player['name'] ?? 'Jugador').toString();
    final number = player['number'] ?? '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: GoogleFonts.oswald(
                color: Colors.white24,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: Colors.white10,
              backgroundImage: photo.isNotEmpty ? NetworkImage(_resolveMedia(photo)) : null,
              child: photo.isEmpty
                  ? const Icon(Icons.person, size: 18, color: Colors.white38)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '#$number',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: Colors.white.withValues(alpha: 0.08)),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: pct.clamp(0.0, 1.0),
                          child: ColoredBox(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$val',
                style: GoogleFonts.oswald(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                statLabel,
                style: GoogleFonts.inter(
                  color: color.withValues(alpha: 0.75),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparativaTeamHeader() {
    final hName = _teamDisplayName(homeTeam, 'LOCAL');
    final vName = _teamDisplayName(visitorTeam, 'VISITA');
    final hLogo = _getTeamLogoUrl(homeTeam);
    final vLogo = _getTeamLogoUrl(visitorTeam);

    Widget teamChip({
      required String name,
      required Color color,
      required String logoUrl,
      required bool alignEnd,
    }) {
      final logo = logoUrl.isNotEmpty
          ? Container(
              width: 20,
              height: 20,
              margin: alignEnd
                  ? const EdgeInsets.only(left: 6)
                  : const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandSurface,
                border: Border.all(color: color.withValues(alpha: 0.35)),
                image: DecorationImage(
                  image: NetworkImage(logoUrl),
                  fit: BoxFit.cover,
                ),
              ),
            )
          : null;

      final label = Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.oswald(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      );

      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: alignEnd
            ? [label, if (logo != null) logo]
            : [if (logo != null) logo, label],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: teamChip(name: hName, color: brandPrimary, logoUrl: hLogo, alignEnd: false)),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          Expanded(child: teamChip(name: vName, color: visitColor, logoUrl: vLogo, alignEnd: true)),
        ],
      ),
    );
  }

  // --- TAB 3: ROSTER ---

  Widget _buildRosterTab() {
    final hName = (homeTeam['name'] ?? 'LOCAL').toString().toUpperCase();
    final vName = (visitorTeam['name'] ?? 'VISITA').toString().toUpperCase();

    final rosterRaw = _rosterTabIsHome ? (homeTeam['roster'] as List? ?? []) : (visitorTeam['roster'] as List? ?? []);
    final activeColor = _rosterTabIsHome ? brandPrimary : visitColor;

    int presentes = 0;
    List<Map<String, dynamic>> roster = [];
    for (var p in rosterRaw) {
      if (p is Map) {
        final pm = Map<String, dynamic>.from(p);
        final att = int.tryParse(pm['stats']?['attendance']?.toString() ?? '0') ?? 0;
        if (att > 0) presentes++;
        pm['_att'] = att;
        roster.add(pm);
      }
    }

    roster.sort((a, b) {
      if (a['_att'] > 0 && b['_att'] == 0) return -1;
      if (b['_att'] > 0 && a['_att'] == 0) return 1;
      final nA = int.tryParse(a['number']?.toString() ?? '999') ?? 999;
      final nB = int.tryParse(b['number']?.toString() ?? '999') ?? 999;
      return nA.compareTo(nB);
    });

    return Column(
      children: [
        // Switcher
        Container(
          height: 50,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: brandSurface, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _rosterTabIsHome = true),
                  child: Container(
                    decoration: BoxDecoration(color: _rosterTabIsHome ? brandPrimary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(hName, style: GoogleFonts.oswald(color: _rosterTabIsHome ? Colors.black : Colors.white54, fontSize: 14, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _rosterTabIsHome = false),
                  child: Container(
                    decoration: BoxDecoration(color: !_rosterTabIsHome ? visitColor : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(vName, style: GoogleFonts.oswald(color: !_rosterTabIsHome ? Colors.white : Colors.white54, fontSize: 14, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('ASISTENCIA AL PARTIDO', style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
              const Spacer(),
              Icon(Icons.check_circle, color: activeColor, size: 14),
              const SizedBox(width: 4),
              Text('$presentes / ${roster.length}', style: GoogleFonts.oswald(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.5, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemCount: roster.length,
            itemBuilder: (ctx, idx) {
              final p = roster[idx];
              final isPresent = p['_att'] > 0;
              final photo = (p['photo'] ?? p['thumb'] ?? '').toString();

              return Opacity(
                opacity: isPresent ? 1.0 : 0.4,
                child: Container(
                  decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: isPresent ? activeColor : Colors.grey, width: 4))),
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(radius: 20, backgroundColor: brandSurface, backgroundImage: photo.isNotEmpty ? NetworkImage(_resolveMedia(photo)) : null, child: photo.isEmpty ? const Icon(Icons.person, color: Colors.white54) : null),
                          if (isPresent) Positioned(bottom: 0, right: 0, child: Container(decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: successColor, size: 12))),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('#${p['number']} ${p['name']}'.toUpperCase(), style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              isPresent
                                  ? MatchHelpers.playerPositionsLabel(p)
                                  : 'NO ASISTIÓ',
                              style: GoogleFonts.inter(
                                color: isPresent ? textMuted : Colors.redAccent,
                                fontSize: 9,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }
}

/// Barra comparativa tipo duelo: crece desde el centro hacia cada lado.
class _DuelStatBar extends StatefulWidget {
  const _DuelStatBar({
    super.key,
    required this.title,
    required this.homeVal,
    required this.visitVal,
    required this.homeColor,
    required this.visitColor,
  });

  final String title;
  final int homeVal;
  final int visitVal;
  final Color homeColor;
  final Color visitColor;

  @override
  State<_DuelStatBar> createState() => _DuelStatBarState();
}

class _DuelStatBarState extends State<_DuelStatBar>
    with TickerProviderStateMixin {
  static const double _trackHeight = 9;
  static const double _countSlotWidth = 30;

  late AnimationController _widthController;
  late AnimationController _pulseController;
  late Animation<double> _widthCurve;
  late Animation<double> _bumpCurve;
  late Animation<double> _flashCurve;

  double _fromHomeProgress = 0;
  double _fromVisitProgress = 0;
  double _toHomeProgress = 0;
  double _toVisitProgress = 0;

  @override
  void initState() {
    super.initState();
    _widthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _widthCurve = CurvedAnimation(
      parent: _widthController,
      curve: Curves.easeOutCubic,
    );
    _bumpCurve = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.16), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.16, end: 1.0), weight: 65),
    ]).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _flashCurve = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 75),
    ]).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _setTargetProgress(animate: false);
  }

  @override
  void didUpdateWidget(_DuelStatBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeVal != widget.homeVal ||
        oldWidget.visitVal != widget.visitVal) {
      _fromHomeProgress = _currentHomeProgress();
      _fromVisitProgress = _currentVisitProgress();
      _setTargetProgress(animate: true);
      _widthController.forward(from: 0);
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _setTargetProgress({required bool animate}) {
    final total = widget.homeVal + widget.visitVal;
    if (total <= 0) {
      _toHomeProgress = 0;
      _toVisitProgress = 0;
    } else {
      _toHomeProgress = widget.homeVal / total;
      _toVisitProgress = widget.visitVal / total;
    }
    if (!animate) {
      _fromHomeProgress = _toHomeProgress;
      _fromVisitProgress = _toVisitProgress;
    }
  }

  double _currentHomeProgress() =>
      _fromHomeProgress + (_toHomeProgress - _fromHomeProgress) * _widthCurve.value;

  double _currentVisitProgress() =>
      _fromVisitProgress + (_toVisitProgress - _fromVisitProgress) * _widthCurve.value;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_widthController, _pulseController]),
      builder: (context, _) {
        final homeProgress = _currentHomeProgress();
        final visitProgress = _currentVisitProgress();
        final flash = _flashCurve.value;
        final bump = _bumpCurve.value;

        final isZero = widget.homeVal == 0 && widget.visitVal == 0;
        final isTie = !isZero && widget.homeVal == widget.visitVal;
        final homeWins = !isZero && !isTie && widget.homeVal > widget.visitVal;
        final visitWins = !isZero && !isTie && widget.visitVal > widget.homeVal;

        final homeValueColor = isZero || isTie
            ? widget.homeColor.withValues(alpha: 0.7)
            : homeWins
                ? widget.homeColor
                : widget.homeColor.withValues(alpha: 0.5);
        final visitValueColor = isZero || isTie
            ? widget.visitColor.withValues(alpha: 0.7)
            : visitWins
                ? widget.visitColor
                : widget.visitColor.withValues(alpha: 0.5);

        Color barColor(Color base, bool isWinner, bool isLoser) {
          if (isZero) return base.withValues(alpha: 0.25);
          if (isTie) return base.withValues(alpha: 0.55);
          if (isWinner) return base;
          if (isLoser) return base.withValues(alpha: 0.38);
          return base.withValues(alpha: 0.55);
        }

        final homeBarColor = barColor(widget.homeColor, homeWins, visitWins);
        final visitBarColor = barColor(widget.visitColor, visitWins, homeWins);

        double glowAlpha(bool winner) {
          if (isZero || isTie) return 0.12;
          if (winner) return 0.35 + flash * 0.35;
          return 0.1;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            children: [
              Text(
                widget.title.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildCountSlot(
                    value: widget.homeVal,
                    color: homeValueColor,
                    teamColor: widget.homeColor,
                    winner: homeWins,
                    bump: bump,
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 14,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 2.5,
                            height: _trackHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.06,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final half = constraints.maxWidth / 2;
                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        if (homeProgress > 0)
                                          Positioned(
                                            right: half,
                                            top: 0,
                                            bottom: 0,
                                            width: half * homeProgress,
                                            child: ClipPath(
                                              clipper: const _DuelBarClipper(
                                                isHome: true,
                                              ),
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                    colors: [
                                                      homeBarColor.withValues(
                                                        alpha: homeWins || isTie
                                                            ? 0.55
                                                            : 0.28,
                                                      ),
                                                      homeBarColor,
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: widget.homeColor
                                                          .withValues(
                                                        alpha: glowAlpha(
                                                          homeWins,
                                                        ),
                                                      ),
                                                      blurRadius: homeWins
                                                          ? 8 + flash * 4
                                                          : 3,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (visitProgress > 0)
                                          Positioned(
                                            left: half,
                                            top: 0,
                                            bottom: 0,
                                            width: half * visitProgress,
                                            child: ClipPath(
                                              clipper: const _DuelBarClipper(
                                                isHome: false,
                                              ),
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                    colors: [
                                                      visitBarColor,
                                                      visitBarColor.withValues(
                                                        alpha: visitWins || isTie
                                                            ? 0.55
                                                            : 0.28,
                                                      ),
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: widget.visitColor
                                                          .withValues(
                                                        alpha: glowAlpha(
                                                          visitWins,
                                                        ),
                                                      ),
                                                      blurRadius: visitWins
                                                          ? 8 + flash * 4
                                                          : 3,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                _DuelCenterClash(
                                  height: _trackHeight,
                                  flash: flash,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildCountSlot(
                    value: widget.visitVal,
                    color: visitValueColor,
                    teamColor: widget.visitColor,
                    winner: visitWins,
                    bump: bump,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountSlot({
    required int value,
    required Color color,
    required Color teamColor,
    required bool winner,
    required double bump,
  }) {
    return SizedBox(
      width: _countSlotWidth,
      child: Transform.scale(
        scale: winner ? bump : 1.0,
        alignment: Alignment.center,
        child: Text(
          '${value}',
          textAlign: TextAlign.center,
          style: GoogleFonts.oswald(
            color: color,
            fontSize: 15,
            fontWeight: winner ? FontWeight.w900 : FontWeight.w700,
            height: 1,
            shadows: winner
                ? [
                    Shadow(
                      color: teamColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _DuelCenterClash extends StatelessWidget {
  const _DuelCenterClash({
    required this.height,
    required this.flash,
  });

  final double height;
  final double flash;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: height + 4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 1,
            height: height + 2,
            color: Colors.white.withValues(alpha: 0.14),
          ),
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75 + flash * 0.15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.15 + flash * 0.2),
                    blurRadius: 6 + flash * 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DuelBarClipper extends CustomClipper<Path> {
  const _DuelBarClipper({required this.isHome});

  final bool isHome;

  @override
  Path getClip(Size size) {
    final path = Path();
    const cut = 3.0;

    if (isHome) {
      path.moveTo(cut, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width - cut, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _DuelBarClipper oldClipper) =>
      oldClipper.isHome != isHome;
}
