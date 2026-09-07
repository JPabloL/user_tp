import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/match_detail_route.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';
import '../services/toast_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_pill.dart';
import '../config/theme.dart';
import '../utils/match_helpers.dart';
import '../utils/navigation_helpers.dart';
import '../utils/selectivo_helpers.dart';
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
    this.initialTab,
    this.viewOnly = false,
    this.playerRelation,
    this.canManage = false,
  });

  static const String route = '/jugador';

  final ApiService api;
  final StorageService storage;
  final SocketService socketService;
  final String playerId;
  final String playerName;
  final bool autoOpenRequests;
  final String? initialTab;
  final bool viewOnly;
  final String? playerRelation;
  final bool canManage;

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
  String userUid = '';
  String selectedTab = 'data';
  int activeCarouselIndex = 0;

  Map<String, dynamic>? playerData;
  Map<String, dynamic>? statsSummary;
  Map<String, dynamic>? teamStats;
  List<dynamic>? statsHistory;
  List<dynamic> playerRequests = [];
  List<Map<String, dynamic>> _selectivoRequests = [];
  int _selectivosPendingConsent = 0;
  int _summaryPendingConsent = 0;
  List<dynamic> currentTeams = [];
  List<dynamic> oldTeams = [];
  int pendingRequestsCount = 0;

  StreamSubscription<dynamic>? socketSub;
  StreamSubscription<dynamic>? _profileSocketSub;
  StreamSubscription<dynamic>? _userContextSub;

  // ── Editable fields state ────────────────────────────────────────────────
  final _aliasCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _userNameCtrl = TextEditingController();
  List<String> _editablePositions = [];
  Map<String, dynamic>? _originalPlayerData;
  bool _hasChanges = false;
  bool _pinVisible = false;
  static const _allPositions = ['QB', 'WR', 'C', 'DB', 'CB', 'LB', 'FS', 'R'];
  static const _positionNames = {
    'QB': 'Quarterback',
    'WR': 'Receptor',
    'C':  'Centro',
    'DB': 'Defensivo General',
    'CB': 'Corner',
    'LB': 'Line Backer',
    'FS': 'Free safety',
    'R':  'Rusher',
  };

  static const _brandAqua = AppTheme.brandTeal;
  static const _appBg = AppTheme.navyPrimary;

  List<dynamic> get carouselOptions {
    final general = {
      'type': 'general',
      'name': 'Resumen',
      'logo': 'https://cuerposallimite.net/nlff/resources/images/logo_tochito_pro.png',
    };
    final allTeams = [...currentTeams, ...oldTeams];
    final teamOptions = allTeams.map((t) {
      final map = Map<String, dynamic>.from(t as Map);
      map['type'] = 'team';
      map['logo'] = map['logo'] ?? map['team']?['logo'] ?? map['academy']?['logo'] ?? '';
      map['isPast'] = oldTeams.contains(t);
      return map;
    }).toList();
    return [general, ...teamOptions];
  }

  Map<String, dynamic> get activeStats {
    final selected = carouselOptions[activeCarouselIndex];
    if (selected['type'] == 'general') return statsSummary ?? _defaultStats();
    return teamStats ?? _defaultStats();
  }

  /// Safely converts a dynamic value (String, int, double) to int.
  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }


  String get displayNumberString {
    final selected = carouselOptions[activeCarouselIndex];
    String? n;
    
    if (selected['type'] != 'general') {
      n = selected['num']?.toString();
    }
    if (n == null || n.trim().isEmpty || n.toLowerCase() == 'null') {
      n = playerData?['number']?.toString();
    }
    if (n == null || n.trim().isEmpty || n.toLowerCase() == 'null') {
      return '';
    }
    return n;
  }

  List<String> get displayPositions {
    final selected = carouselOptions[activeCarouselIndex];
    List<dynamic> raw;
    if (selected['type'] == 'general') {
      raw = (playerData?['positions'] as List<dynamic>?) ?? [];
    } else {
      raw = (selected['positions'] as List<dynamic>?) ?? (playerData?['positions'] as List<dynamic>?) ?? [];
    }
    
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty && e.toLowerCase() != 'null')
        .toList();
  }

  String get activeLogo {
    final options = carouselOptions;
    if (activeCarouselIndex >= options.length) return '';
    return options[activeCarouselIndex]['logo']?.toString() ?? '';
  }

  bool _isViewOnlyMode() {
    return widget.viewOnly || widget.playerRelation == 'followed';
  }

  bool _hasManagementAccess() => !_isViewOnlyMode();

  @override
  void initState() {
    super.initState();
    autoOpenRequests = widget.viewOnly ? false : widget.autoOpenRequests;
    final tab = widget.initialTab?.trim();
    if (widget.viewOnly) {
      selectedTab = 'stats';
    } else if (tab != null && tab.isNotEmpty) {
      selectedTab = tab;
    }
    _setupWebsockets();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadUser();
    await _loadDashboardData();
  }


  @override
  void dispose() {
    socketSub?.cancel();
    _profileSocketSub?.cancel();
    _userContextSub?.cancel();
    _aliasCtrl.dispose();
    _numberCtrl.dispose();
    _userNameCtrl.dispose();
    super.dispose();
  }


  Future<void> _loadUser() async {
    final session = await widget.storage.getJson(AppConfig.sessionKey);
    if (session == null) return;
    userId = session['id']?.toString() ?? '';
    userUid = session['uid']?.toString() ?? '';
  }

  void _setupWebsockets() {
    widget.socketService.joinPlayer(widget.playerId);
    if (userId.isNotEmpty) {
      widget.socketService.joinUser(userId);
    }
    _joinTeamRoomsFromCurrentData();

    socketSub = widget.socketService.requestUpdatesStream.listen((data) async {
      if (data != null && data['actingUserId'] == userId) return;

      await _loadPlayerRequests();
      if (!isModalOpen && mounted) {
        final academyName = data?['academy']?['name'] ?? 'Una academia';
        _toast('$academyName actualizó tu solicitud.');
      }
    });

    _profileSocketSub = widget.socketService.profileUpdatesStream.listen((data) async {
      final eventPlayerId = SocketService.eventPlayerId(data);
      if (eventPlayerId != null && eventPlayerId != widget.playerId) return;

      if (isModalOpen) {
        await _loadPlayerRequests();
      } else {
        await _loadDashboardData();
      }
      if (!mounted) return;

      if (SocketService.isTeamAssignmentEvent(data)) {
        _toast('¡Te integraron a un nuevo equipo!');
      }
    });

    _userContextSub = widget.socketService.userContextStream.listen((_) async {
      await _loadPlayerRequests();
    });
  }

  void _joinTeamRoomsFromCurrentData() {
    for (final team in currentTeams) {
      if (team is! Map) continue;
      final teamId = (team['id'] ?? team['_id'] ?? '').toString();
      if (teamId.isNotEmpty) {
        widget.socketService.joinTeam(teamId);
      }
    }
  }

  int _countPendingAttention(List<dynamic> requests) {
    return requests.where((r) {
      if (r is! Map) return false;
      if (r['type'] == 'co_tutor') return false;
      if (SelectivoHelpers.isSelectivoRequest(r)) {
        return SelectivoHelpers.needsConsentResponse(r);
      }
      final m = r['mood'];
      final moodInt = m is int ? m : int.tryParse(m?.toString() ?? '') ?? 0;
      return moodInt == 0;
    }).length;
  }

  List<dynamic> _formattedCoTutorRequests() {
    final coTutorReqs = (playerData?['co_tutor_requests'] as List<dynamic>?) ?? [];
    return coTutorReqs.map((req) {
      final r = Map<String, dynamic>.from(req as Map);
      r['type'] = 'co_tutor';
      r['origin'] = 'co_tutor';
      if (r['status'] == 'pending') {
        r['mood'] = 0;
      } else if (r['status'] == 'approved' || r['status'] == 'accepted') {
        r['mood'] = 1;
      } else {
        r['mood'] = 2;
      }
      r['_id'] = r['requestId'] ?? 'co_tutor_${r['requesterId']}';
      return r;
    }).toList();
  }

  void _applyCombinedRequests(List<dynamic> otherRequests) {
    playerRequests = [..._selectivoRequests, ...otherRequests];
    pendingRequestsCount = _countPendingAttention(playerRequests);
  }

  Future<void> _refreshSelectivoRequests() async {
    if (_isViewOnlyMode()) {
      _selectivoRequests = [];
      return;
    }
    if (userUid.isEmpty) {
      final session = await widget.storage.getJson(AppConfig.sessionKey);
      userUid = session?['uid']?.toString() ?? '';
      userId = (session?['id'] ?? userId).toString();
    }
    if (userUid.isEmpty) return;
    try {
      final res = await widget.api.getUserContextV2(userUid);
      if (res['status'] != 'ok') return;
      _selectivoRequests = SelectivoHelpers.asPendingRequests(
        dashboard: res['dashboard'],
        playerId: widget.playerId,
      );
      final dash = SelectivoHelpers.asMap(res['dashboard']);
      final selectivos = SelectivoHelpers.selectivosFrom(dash);
      final pending = selectivos?['pendingConsent'];
      _selectivosPendingConsent = pending is int
          ? pending
          : int.tryParse(pending?.toString() ?? '') ?? 0;
      final summaryPending =
          SelectivoHelpers.asMap(dash?['summary'])?['selectionPendingConsentCount'];
      _summaryPendingConsent = summaryPending is int
          ? summaryPending
          : int.tryParse(summaryPending?.toString() ?? '') ?? 0;
    } catch (_) {
      // El dashboard de equipo sigue disponible aunque falle el contexto.
    }
  }

  void _onSelectivoConsentSuccess(bool wasAbleToRespond) {
    if (!wasAbleToRespond) return;
    if (_selectivosPendingConsent > 0) _selectivosPendingConsent--;
    if (_summaryPendingConsent > 0) _summaryPendingConsent--;
  }

  void _onSelectivoConsentResetSuccess(bool couldRespondBefore) {
    if (couldRespondBefore) return;
    _selectivosPendingConsent++;
    _summaryPendingConsent++;
  }

  Future<void> _loadDashboardData() async {
    if (widget.playerId.trim().isEmpty) {
      _scheduleNavigation(() {
        Navigator.of(context).pushNamedAndRemoveUntil(HomePage.route, (_) => false);
      });
      return;
    }

    if (!isLoading) {
      _scheduleSetState(() => isLoading = true);
    }
    final shouldOpenRequests = autoOpenRequests && !_isViewOnlyMode();
    var didLoad = false;
    try {
      final dashboardFuture = widget.api.loadPlayerDashboardData(widget.playerId);
      final selectivosFuture = _refreshSelectivoRequests();
      final response = await dashboardFuture;
      await selectivosFuture;
      playerData = response['playerData'] as Map<String, dynamic>?;
      statsSummary = response['statsSummary'] as Map<String, dynamic>?;
      final rawRequests = (response['requests'] as List<dynamic>?) ?? [];

      _applyCombinedRequests([..._formattedCoTutorRequests(), ...rawRequests]);
      _processTeams((playerData?['teams'] as List<dynamic>?) ?? []);
      _joinTeamRoomsFromCurrentData();
      final session = await widget.storage.getJson(AppConfig.sessionKey);
      if (session != null) {
        userId = session['id']?.toString() ?? '';
        userUid = session['uid']?.toString() ?? userUid;
      }
      _initEditableFields();
      if (!_isViewOnlyMode()) {
        await _checkAndGenerateVinculacionPin();
      } else if (selectedTab == 'data') {
        selectedTab = 'stats';
      }
      if (shouldOpenRequests) {
        autoOpenRequests = false;
        selectedTab = 'teams';
      }
      didLoad = true;
    } catch (_) {
      _toast('No se pudieron cargar los datos', isError: true);
      _scheduleNavigation(() {
        Navigator.of(context).pushNamedAndRemoveUntil(HomePage.route, (_) => false);
      });
    } finally {
      _scheduleSetState(() => isLoading = false);
      if (shouldOpenRequests && didLoad) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openRequestsModal();
        });
      }
    }
  }

  void _initEditableFields() {
    if (playerData == null) return;
    _aliasCtrl.text = playerData?['alias']?.toString() ?? '';
    _numberCtrl.text = playerData?['number']?.toString() ?? '';
    _userNameCtrl.text = playerData?['userName']?.toString() ?? '';
    _editablePositions = ((playerData?['positions'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();
    _originalPlayerData = Map<String, dynamic>.from(playerData!);
    _hasChanges = false;
  }

  Future<void> _checkAndGenerateVinculacionPin() async {
    if (playerData == null) return;
    final tutorId = playerData?['tutor']?['id']?.toString() ?? playerData?['parentId']?.toString() ?? '';
    final currentPin = playerData?['nip_vinculacion']?.toString() ?? '';
    if (tutorId.isNotEmpty && tutorId == userId && currentPin.isEmpty) {
      final random = math.Random();
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final pin = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
      final payload = {
        '_id': playerData?['id'] ?? playerData?['_id'],
        'nip_vinculacion': pin,
      };
      try {
        final resp = await widget.api.updateDoc(payload);
        if (resp['ok'] == true || resp['status'] != 'error') {
          _scheduleSetState(() {
            playerData?['nip_vinculacion'] = pin;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _removeCoTutor() async {
    if (playerData == null) return;
    final childId = playerData?['id']?.toString() ?? playerData?['_id']?.toString() ?? '';
    if (childId.isEmpty) return;

    final coTutorId = playerData?['co_tutor']?['id']?.toString() ?? '';

    // Marcar requests aprobadas como rechazadas
    final existingRequests = (playerData?['co_tutor_requests'] as List<dynamic>?) ?? [];
    final updatedRequests = List<Map<String, dynamic>>.from(
      existingRequests.map((e) => Map<String, dynamic>.from(e as Map))
    );
    for (final req in updatedRequests) {
      if (req['status'] == 'approved') req['status'] = 'rejected';
    }

    try {
      final resp = await widget.api.updateDoc({
        '_id': childId,
        'co_tutor': null,
        'co_tutor_requests': updatedRequests,
      });
      if (resp['ok'] == true || resp['status'] != 'error') {
        if (mounted) {
          setState(() {
            playerData?['co_tutor'] = null;
            playerData?['co_tutor_requests'] = updatedRequests;
          });
          _toast('Co-tutor eliminado correctamente');
        }
        // Actualizar el documento del co-tutor removido
        if (coTutorId.isNotEmpty) {
          try {
            final requesterRes = await widget.api.getUserContext(coTutorId);
            final requesterDoc = requesterRes['user'] as Map<String, dynamic>?;
            if (requesterDoc != null) {
              final coManaged = (requesterDoc['co_managed_children'] as List<dynamic>?) ?? [];
              final updatedCoManaged = List<Map<String, dynamic>>.from(
                coManaged.map((e) => Map<String, dynamic>.from(e as Map))
              );
              for (final item in updatedCoManaged) {
                final matchChildId = item['childId']?.toString() == childId.toString();
                final matchPlayerId = item['playerId']?.toString() == childId.toString();
                final matchId = item['id']?.toString() == childId.toString();
                
                if (matchChildId || matchPlayerId || matchId) {
                  item['status'] = 'rejected';
                }
              }
              await widget.api.updateDoc({
                '_id': requesterDoc['_id'],
                'co_managed_children': updatedCoManaged,
              });
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) _toast('Error al eliminar co-tutor', isError: true);
    }
  }
  
  final Set<String> _loadingCoTutorIds = {};

  Future<void> _acceptCoTutorRequestMain(Map<String, dynamic> r) async {
    final reqId = (r['_id'] ?? r['requestId'] ?? r['requesterId']).toString();
    setState(() => _loadingCoTutorIds.add(reqId));
    try {
      final resp = await widget.api.updateCoTutorshipRequestStatus(
        uid: userId,
        requestId: r['requestId']?.toString() ?? '',
        playerId: widget.playerId,
        status: 'accepted',
      );

      if (resp['ok'] == true || resp['status'] != 'error') {
        if (mounted) {
          _toast('Co-Tutoría aprobada');
          _updateLocalCoTutorRequestState(reqId, 1, 'accepted');
        }
      } else {
        if (mounted) _toast(resp['message']?.toString() ?? 'Error al aceptar Co-Tutoría', isError: true);
      }
    } catch (e) {
      if (mounted) _toast('Error al aceptar Co-Tutoría', isError: true);
    } finally {
      if (mounted) setState(() => _loadingCoTutorIds.remove(reqId));
    }
  }

  Future<void> _rejectCoTutorRequestMain(Map<String, dynamic> r) async {
    final reqId = (r['_id'] ?? r['requestId'] ?? r['requesterId']).toString();
    setState(() => _loadingCoTutorIds.add(reqId));
    try {
      final resp = await widget.api.updateCoTutorshipRequestStatus(
        uid: userId,
        requestId: r['requestId']?.toString() ?? '',
        playerId: widget.playerId,
        status: 'rejected',
      );

      if (resp['ok'] == true || resp['status'] != 'error') {
        if (mounted) {
          _toast('Co-Tutoría rechazada');
          _updateLocalCoTutorRequestState(reqId, 2, 'rejected');
        }
      } else {
        if (mounted) _toast(resp['message']?.toString() ?? 'Error al rechazar Co-Tutoría', isError: true);
      }
    } catch (e) {
      if (mounted) _toast('Error al rechazar Co-Tutoría', isError: true);
    } finally {
      if (mounted) setState(() => _loadingCoTutorIds.remove(reqId));
    }
  }

  Future<void> _resumeCoTutorRequestMain(Map<String, dynamic> r) async {
    final reqId = (r['_id'] ?? r['requestId'] ?? r['requesterId']).toString();
    setState(() => _loadingCoTutorIds.add(reqId));
    try {
      final resp = await widget.api.updateCoTutorshipRequestStatus(
        uid: userId,
        requestId: r['requestId']?.toString() ?? '',
        playerId: widget.playerId,
        status: 'pending',
      );

      if (resp['ok'] == true || resp['status'] != 'error') {
        if (mounted) {
          _toast('Solicitud de Co-Tutoría reactivada');
          _updateLocalCoTutorRequestState(reqId, 0, 'pending');
        }
      } else {
        if (mounted) _toast(resp['message']?.toString() ?? 'Error al reactivar Co-Tutoría', isError: true);
      }
    } catch (e) {
      print('Error en _resumeCoTutorRequestMain: $e');
      if (mounted) _toast('Error al reactivar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loadingCoTutorIds.remove(reqId));
    }
  }

  void _updateLocalCoTutorRequestState(String reqId, int newMood, String newStatus) {
    setState(() {
      for (var r in playerRequests) {
        if (r['type'] == 'co_tutor' && 
            (r['_id'] == reqId || r['requestId'] == reqId || r['requesterId'] == reqId)) {
          r['mood'] = newMood;
          r['status'] = newStatus;
        }
      }
      if (playerData != null && playerData!['co_tutor_requests'] != null) {
        final reqs = playerData!['co_tutor_requests'] as List;
        for (var req in reqs) {
          if (req is Map && (req['requestId'] == reqId || req['requesterId'] == reqId)) {
            req['status'] = newStatus;
            req['mood'] = newMood;
          }
        }
      }
    });
  }

  void _markChanged() {
    final alias = _aliasCtrl.text.trim();
    final number = _numberCtrl.text.trim();
    final userName = _userNameCtrl.text.trim();
    final origAlias = _originalPlayerData?['alias']?.toString() ?? '';
    final origNumber = _originalPlayerData?['number']?.toString() ?? '';
    final origUserName = _originalPlayerData?['userName']?.toString() ?? '';
    final origPositions = (((_originalPlayerData?['positions']) as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList()
      ..sort();
    final currPositions = [..._editablePositions]..sort();
    setState(() {
      _hasChanges = alias != origAlias ||
          number != origNumber ||
          userName != origUserName ||
          currPositions.join(',') != origPositions.join(',');
    });
  }

  Future<void> _saveEditableData() async {
    if (_isViewOnlyMode()) return;
    if (!_hasChanges) return;
    
    // Preparar payload mínimo: Como el backend hace un "merge", solo 
    // necesitamos enviar el _id y los datos que realmente queremos cambiar.
    final payload = {
      '_id': playerData?['id'] ?? playerData?['_id'], // El backend espera _id
      'alias': _aliasCtrl.text.trim(),
      'number': _numberCtrl.text.trim(),
      'userName': _userNameCtrl.text.trim(),
      'positions': [..._editablePositions],
    };

    try {
      final resp = await widget.api.updateDoc(payload);
      
      // CouchDB devuelve { "ok": true, "id": "...", "rev": "..." } en éxito
      if (resp['ok'] == true || resp['status'] != 'error') {
        _toast('Perfil actualizado exitosamente');
        setState(() {
          // Actualizamos el estado visual con los nuevos valores
          playerData?['alias'] = payload['alias'];
          playerData?['number'] = payload['number'];
          playerData?['userName'] = payload['userName'];
          playerData?['positions'] = payload['positions'];
          
          if (resp['rev'] != null) {
            playerData?['_rev'] = resp['rev'];
          }
          
          _originalPlayerData = Map<String, dynamic>.from(playerData!);
          _hasChanges = false;
        });
      } else {
        _toast('Error: ${resp['message'] ?? 'No se pudo guardar'}');
      }
    } catch (e) {
      _toast('Error de conexión al guardar');
    }
  }


  Future<void> _loadPlayerRequests() async {
    try {
      final requestsFuture = widget.api.getMyRequests(widget.playerId);
      await _refreshSelectivoRequests();
      final requests = await requestsFuture;
      if (!mounted) return;

      _scheduleSetState(() {
        _applyCombinedRequests([..._formattedCoTutorRequests(), ...requests]);
      });
    } catch (_) {}
  }

  /// Refresca solo las solicitudes sin mostrar spinner ni recargar toda la página.
  Future<void> _refreshRequestsOnly() async {
    await _loadPlayerRequests();
  }

  void _syncTeamRequestsFromSheet(List<Map<String, dynamic>> teamRequests) {
    final coTutorReqs = playerRequests
        .where((r) => r['type'] == 'co_tutor')
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    final fromSheetSelectivos = teamRequests
        .where(SelectivoHelpers.isSelectivoRequest)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final teamOnly = teamRequests
        .where((r) => !SelectivoHelpers.isSelectivoRequest(r))
        .toList();
    _scheduleSetState(() {
      if (fromSheetSelectivos.isNotEmpty) {
        _selectivoRequests = fromSheetSelectivos;
      }
      _applyCombinedRequests([...coTutorReqs, ...teamOnly]);
    });
  }

  Future<void> _loadStatsHistory() async {
    if (statsHistory != null) return;
    setState(() => isLoadingStats = true);
    try {
      final response = await widget.api.getPlayerStatsHistory(widget.playerId);
      statsHistory = response['history'] as List<dynamic>?;
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
    if (_isViewOnlyMode()) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200, maxHeight: 1200);
    if (file == null) return;
    try {
      final res = await widget.api.updatePlayerPublicPhoto(
        playerId: widget.playerId,
        bytes: await file.readAsBytes(),
      );
      if (res['status'] == 'ok') {
        setState(() {
          playerData?['publicPhoto'] = res['newPhotoUrl'] ?? playerData?['publicPhoto'];
        });
        _toast('Foto actualizada');
      }
    } catch (_) {
      _toast('No se pudo actualizar foto', isError: true);
    }
  }

  Future<void> _openRequestsModal() async {
    if (_isViewOnlyMode()) return;
    if (isLoading || playerData == null) return;
    isModalOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TeamRequestsSheet(
        api: widget.api,
        playerId: widget.playerId,
        userId: userId,
        userUid: userUid,
        playerData: playerData!,
        initialRequests: playerRequests.where((r) => r['type'] != 'co_tutor').toList(),
        requestUpdatesStream: widget.socketService.requestUpdatesStream,
        onDismissed: _refreshRequestsOnly,
        onRequestsChanged: _syncTeamRequestsFromSheet,
        onSelectivoConsentSuccess: _onSelectivoConsentSuccess,
        onSelectivoConsentResetSuccess: _onSelectivoConsentResetSuccess,
      ),
    );
    isModalOpen = false;
    await _refreshRequestsOnly();
  }

  // ==========================================================================
  // ENVIAR SOLICITUD A EQUIPO (botón + del tab Equipos)
  // ==========================================================================
  Future<void> _openSendRequestSheet() async {
    if (_isViewOnlyMode()) return;
    if (playerData == null) return;
    // Abre el modal de solicitudes con la pestaña de búsqueda activa directamente
    isModalOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TeamRequestsSheet(
        api: widget.api,
        playerId: widget.playerId,
        userId: userId,
        userUid: userUid,
        playerData: playerData!,
        initialRequests: playerRequests.where((r) => r['type'] != 'co_tutor').toList(),
        requestUpdatesStream: widget.socketService.requestUpdatesStream,
        startOnSearch: true,
        onDismissed: _refreshRequestsOnly,
        onRequestsChanged: _syncTeamRequestsFromSheet,
        onSelectivoConsentSuccess: _onSelectivoConsentSuccess,
        onSelectivoConsentResetSuccess: _onSelectivoConsentResetSuccess,
      ),
    );
    isModalOpen = false;
    await _refreshRequestsOnly();
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
    ToastService.show(msg, isError: isError);
  }

  void _scheduleSetState(VoidCallback fn) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(fn);
    });
  }

  void _scheduleNavigation(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = activeStats;

    return Scaffold(
      backgroundColor: _appBg,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Transparent AppBar ──────────────────────────────────────
                SliverAppBar(
                  backgroundColor: _appBg,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
                    onPressed: () => popOrGoHome(context),
                  ),
                  title: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Tochito',
                          style: GoogleFonts.oswald(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.8,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: 'Pro',
                          style: GoogleFonts.oswald(
                            fontWeight: FontWeight.w400,
                            fontSize: 24,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.8,
                            color: AppTheme.brandTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    if (!_isViewOnlyMode())
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Badge(
                          label: Text('$pendingRequestsCount'),
                          isLabelVisible: pendingRequestsCount > 0,
                          backgroundColor: _brandAqua,
                          textColor: AppTheme.navyPrimary,
                          child: IconButton(
                            onPressed: _openRequestsModal,
                            icon: const Icon(Icons.notifications_active_outlined, color: AppTheme.textPrimary),
                          ),
                        ),
                      ),
                  ],
                ),

                // ── Body ────────────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Hero Card
                      _buildHeroCard(),
                      const SizedBox(height: 16),

                      // Segment tabs
                      _buildTabBar(),
                      const SizedBox(height: 16),

                      // Tab content
                      AnimatedSwitcher(
                        duration: _animDuration,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: selectedTab == 'stats'
                            ? _buildStatsHistoryCard()
                            : selectedTab == 'teams'
                                ? _buildTeamsListCard()
                                : _isViewOnlyMode()
                                    ? _buildStatsHistoryCard()
                                    : _buildDataTab(),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  // ==========================================================================
  // HERO CARD CINEMÁTICA
  // ==========================================================================
  Widget _buildHeroCard() {
    // Resolver Alias evitando texto "null"
    String alias = playerData?['alias']?.toString() ?? '';
    if (alias.trim().isEmpty || alias.toLowerCase() == 'null') {
      alias = playerData?['name']?.toString() ?? '';
    }
    if (alias.toLowerCase() == 'null') alias = '';

    final String publicPhotoStr = playerData?['publicPhoto']?.toString() ?? '';
    final String photoStr = playerData?['photo']?.toString() ?? '';
    final photo = publicPhotoStr.isNotEmpty ? publicPhotoStr : photoStr;
    final numStr = displayNumberString;
    final positions = displayPositions;

    return Container(
        height: 340,
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(36),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 40,
              offset: Offset(0, 20),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 1. Background photo ────────────────────────────────────────
            if (photo.isNotEmpty)
              ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  // Slight desaturate + contrast
                  0.85, 0.10, 0.05, 0, 0,
                  0.05, 0.85, 0.10, 0, 0,
                  0.05, 0.10, 0.85, 0, 0,
                  0,    0,    0,    1, 0,
                ]),
                child: Image.network(
                  photo,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.3),
                  errorBuilder: (context, error, stack) => Container(color: Colors.grey.shade900),
                ),
              )
            else
              Container(
                color: Colors.grey.shade900,
                child: const Center(
                  child: Icon(Icons.person, color: Colors.white24, size: 80),
                ),
              ),

            // ── 2. Bottom gradient ─────────────────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                    colors: [
                      Colors.black.withAlpha(26),   // 10%
                      Colors.transparent,
                      Colors.black.withAlpha(242),  // 95%
                    ],
                  ),
                ),
              ),
            ),

            // ── 3. Watermark number ────────────────────────────────────────
            if (numStr.isNotEmpty)
              Positioned(
                top: -20,
                right: -4,
                child: Text(
                  numStr,
                  style: GoogleFonts.oswald(
                    fontSize: 150,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withAlpha(76), // ~30%
                    height: 1,
                  ),
                ),
              ),

            // ── 4. TochitoPro watermark (bottom-right) ─────────────────────
            Positioned(
              bottom: 10,
              right: 18,
              child: Opacity(
                opacity: 0.7,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Tochito',
                        style: GoogleFonts.oswald(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextSpan(
                        text: 'Pro',
                        style: GoogleFonts.oswald(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.brandTeal,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 4b. Username (bottom-left, below positions) ───────────────
            if ((playerData?['userName'] ?? '').toString().isNotEmpty)
              Positioned(
                bottom: 10,
                left: 24,
                child: Text(
                  '@${playerData?['userName']}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

            // ── 5. Camera tap hint ─────────────────────────────────────────
            if (!_isViewOnlyMode())
              Positioned(
                top: 14,
                right: 14,
                child: GestureDetector(
                  onTap: _changePublicPhoto,
                  child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(40)),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 18),
                ),
              ),
            ),

            // ── 6. Bottom content: alias + meta ────────────────────────────
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Alias
                    Text(
                      alias.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.oswald(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 0.9,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Positions
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (int i = 0; i < positions.length; i++)
                          _buildPositionPill(positions[i], isPrimary: i < 2),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildPositionPill(String position, {required bool isPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary ? AppTheme.brandTeal.withAlpha(20) : AppTheme.navyElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPrimary ? AppTheme.brandTeal : AppTheme.navyElevated,
          width: 1,
        ),
      ),
      child: Text(
        position.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isPrimary ? AppTheme.brandTeal : AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = _isViewOnlyMode()
        ? [
            ('stats', 'Estadísticas'),
            ('teams', 'Equipos'),
          ]
        : [
            ('data', 'Perfil'),
            ('stats', 'Estadísticas'),
            ('teams', 'Equipos'),
          ];

    int tabIndex = tabs.indexWhere((t) => t.$1 == selectedTab);
    if (tabIndex == -1) tabIndex = 0;
    
    // Calcular alineación de -1.0 a 1.0 para N elementos
    double alignmentX = -1.0 + (tabIndex * (2.0 / (tabs.length - 1)));

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandTeal.withAlpha(25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          // Animated Pill
          AnimatedAlign(
            duration: _animDuration,
            curve: Curves.easeOutCubic,
            alignment: Alignment(alignmentX, 0),
            child: FractionallySizedBox(
              widthFactor: 1.0 / tabs.length,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.brandTeal,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          // Botones superpuestos
          Row(
            children: tabs.map((tab) {
              final isActive = selectedTab == tab.$1;
              final hasPending = tab.$1 == 'teams' && pendingRequestsCount > 0;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    setState(() => selectedTab = tab.$1);
                    if (tab.$1 == 'stats') await _loadStatsHistory();
                  },
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: _animDuration,
                          curve: Curves.easeOut,
                          style: TextStyle(
                            fontFamily: GoogleFonts.inter().fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: isActive ? AppTheme.navyPrimary : AppTheme.textSecondary,
                          ),
                          child: Text(tab.$2.toUpperCase()),
                        ),
                        if (hasPending) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }


  // ==========================================================================
  // TAB: DATOS
  // ==========================================================================
  Widget _buildDataTab() {
    final data = playerData ?? {};
    final tutorId = data['tutor']?['id']?.toString() ?? data['parentId']?.toString() ?? '';
    final isPrimaryTutor = _hasManagementAccess() &&
        (widget.playerRelation == 'self' ||
            tutorId.isEmpty ||
            tutorId == userId);
    final name = (data['name'] ?? '').toString().toUpperCase();
    final apellidoPa = (data['apellidoPa'] ?? '').toString();
    final apellidoMa = (data['apellidoMa'] ?? '').toString();
    final curp = (data['curp'] ?? '').toString().toUpperCase();
    final thumb = (data['thumb'] ?? data['photo'] ?? '').toString();
    final bd = data['bd']?.toString();
    final expires = data['verification_expires_at']?.toString();

    final age = _calcAge(bd);
    final birthYear = _birthYear(bd);
    final expiresFormatted = _formatDate(expires);

    return Column(
      key: const ValueKey('data-tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // \u2500\u2500 Section title \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
        Text(
          'DATOS',
          style: GoogleFonts.oswald(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: AppTheme.textPrimary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 16),

        // \u2500\u2500 BLACK WALLET PASS \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.navyElevated, AppTheme.navyPrimary],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withAlpha(25)),
            boxShadow: const [
              BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 15)),
            ],
          ),
          child: Stack(
            children: [
              // Holographic accent (top-right glow)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      colors: [_brandAqua.withAlpha(50), Colors.transparent],
                      radius: 0.8,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [


                    // Photo + Name
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: thumb.isNotEmpty
                              ? Image.network(
                                  thumb,
                                  width: 72, height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, st) => _photoPlaceholder(),
                                )
                              : _photoPlaceholder(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$name\n$apellidoPa $apellidoMa',
                                style: GoogleFonts.oswald(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // CURP
                    Center(
                      child: Text(
                        curp,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brandTeal,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Info row: Edad / Año / Vence
                    Container(
                      padding: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.white.withAlpha(25))),
                      ),
                      child: Row(
                        children: [
                          _walletInfoCell('Edad', age > 0 ? '$age años' : '-', isYellow: false),
                          const SizedBox(width: 28),
                          _walletInfoCell('Año Nac.', birthYear ?? '-', isYellow: true),
                          const SizedBox(width: 28),
                          _walletInfoCell('Vence', expiresFormatted ?? '-', isYellow: false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── EDITABLE FIELDS CARD ──────────────────────────────────────────────
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Alias
              _editableRow(
                label: 'Alias',
                child: Expanded(
                  child: TextField(
                    controller: _aliasCtrl,
                    textAlign: TextAlign.right,
                    onChanged: (_) => _markChanged(),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.brandTeal),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Sin alias',
                      hintStyle: TextStyle(color: Color(0xFFD4D4D8)),
                    ),
                  ),
                ),
                hasDivider: true,
              ),
              // Número
              _editableRow(
                label: 'Número',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.navyElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox(
                    width: 52,
                    child: TextField(
                      controller: _numberCtrl,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _markChanged(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.brandTeal,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                hasDivider: true,
              ),
              // Posiciones
              _editableRow(
                label: 'Posiciones',
                child: const SizedBox.shrink(),
                hasDivider: false,
              ),
              // Chips de posiciones
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _allPositions.map((pos) {
                        final selected = _editablePositions.contains(pos);
                        
                        // Compute index based only on visible selected items so hidden items don't take up primary slots
                        final visibleSelected = _editablePositions.where((p) => _allPositions.contains(p)).toList();
                        final visibleIndex = visibleSelected.indexOf(pos);
                        final isPrimary = visibleIndex >= 0 && visibleIndex < 2;

                        Color bgColor = AppTheme.navySurface;
                        Color borderColor = AppTheme.navySurface;
                        Color textColor = const Color(0xFF6B7280); // Muted grey
                        FontWeight weight = FontWeight.w500;

                        if (selected) {
                          if (isPrimary) {
                            bgColor = AppTheme.brandTeal;
                            borderColor = AppTheme.brandTeal;
                            textColor = AppTheme.navyPrimary;
                            weight = FontWeight.w900;
                          } else {
                            bgColor = AppTheme.brandTeal.withAlpha(20);
                            borderColor = AppTheme.brandTeal;
                            textColor = AppTheme.brandTeal;
                            weight = FontWeight.w800;
                          }
                        }

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _editablePositions.remove(pos);
                              } else {
                                _editablePositions.add(pos);
                              }
                            });
                            _markChanged();
                          },
                          child: AnimatedContainer(
                            duration: _animDuration,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              pos,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: weight,
                                color: textColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    // Indicador de selección
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.brandTeal.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.brandTeal.withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppTheme.brandTeal, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Las primeras 2 posiciones seleccionadas serán las Principales.',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppTheme.brandTeal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Leyenda de posiciones
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.navyElevated.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.navyElevated),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: _allPositions.map((p) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: AppTheme.textPrimary)),
                              const Text(' = ', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                              Text(_positionNames[p] ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF71717A))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── SAVE BUTTON ─────────────────────────────────────────────────────────
        AnimatedOpacity(
          duration: _animDuration,
          opacity: _hasChanges ? 1.0 : 0.4,
          child: IgnorePointer(
            ignoring: !_hasChanges,
            child: PrimaryButton(
              text: 'GUARDAR',
              onPressed: _saveEditableData,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (isPrimaryTutor) ...[
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.textSecondary.withAlpha(100)),
                      ),
                      child: const Icon(Icons.people_outline_rounded, color: AppTheme.textSecondary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'CO-TUTORÍA',
                      style: GoogleFonts.oswald(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),

                // ── Co-tutor activo ────────────────────────────────────
                Builder(builder: (_) {
                  final coTutor = data['co_tutor'] as Map<String, dynamic>?;
                  if (coTutor != null && (coTutor['id']?.toString() ?? '').isNotEmpty) {
                    final coTutorName = coTutor['name']?.toString() ?? 'Co-tutor activo';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.navySurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.brandTeal.withAlpha(80)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.brandTeal.withAlpha(40),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified_user_outlined, color: Color(0xFF0D9488), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Co-tutor activo',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.brandTeal,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      coTutorName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Botón de eliminar
                              GestureDetector(
                                onTap: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: Text(
                                        'Eliminar co-tutor',
                                        style: GoogleFonts.oswald(fontWeight: FontWeight.w800),
                                      ),
                                      content: Text(
                                        '¿Estás seguro de que deseas eliminar a "$coTutorName" como co-tutor de este jugador? Ya no podrá ver ni administrar su perfil.',
                                        style: GoogleFonts.outfit(fontSize: 14),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: Text('Cancelar', style: GoogleFonts.outfit()),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFEF4444),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: () => Navigator.pop(context, true),
                                          child: Text('Eliminar', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) await _removeCoTutor();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.person_remove_outlined, color: Color(0xFFEF4444), size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFFF0F0F0)),
                        const SizedBox(height: 14),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }),

                // ── Descripción ────────────────────────────────────────
                const Text(
                  'Comparte la administración de este perfil con otro tutor (ej. cónyuge). Entrega el PIN al otro tutor para que pueda solicitar acceso.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF71717A),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // ── PIN con toggle de visibilidad ─────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.navyElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.navyElevated),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: _pinVisible
                              ? SelectableText(
                                  data['nip_vinculacion']?.toString() ?? '——',
                                  style: GoogleFonts.oswald(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 6,
                                    color: AppTheme.textPrimary,
                                  ),
                                )
                              : Text(
                                  '● ● ● ● ● ●',
                                  style: GoogleFonts.oswald(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4,
                                    color: const Color(0xFFBBBBBB),
                                  ),
                                ),
                        ),
                      ),
                      // Botón ojo
                      GestureDetector(
                        onTap: () => setState(() => _pinVisible = !_pinVisible),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              _pinVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              key: ValueKey(_pinVisible),
                              size: 22,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _pinVisible ? 'Toca 👁 para ocultar el PIN' : 'Toca 👁 para revelar el PIN',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                
                // ── Módulo de solicitudes de co-tutoría ──
                Builder(builder: (_) {
                  final allCoTutorReqs = playerRequests.where((r) => r['type'] == 'co_tutor').toList();

                  if (allCoTutorReqs.isEmpty) return const SizedBox.shrink();

                  final pendingReqs = allCoTutorReqs.where((r) {
                    final m = r['mood'];
                    final moodInt = m is int ? m : int.tryParse(m?.toString() ?? '') ?? 0;
                    return moodInt == 0;
                  }).toList();

                  final historyReqs = allCoTutorReqs.where((r) {
                    final m = r['mood'];
                    final moodInt = m is int ? m : int.tryParse(m?.toString() ?? '') ?? 0;
                    return moodInt > 0;
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const Divider(height: 1, color: Color(0xFFF0F0F0)),
                      const SizedBox(height: 16),
                      if (pendingReqs.isNotEmpty) ...[
                        Text(
                          'SOLICITUDES PENDIENTES (${pendingReqs.length})',
                          style: GoogleFonts.oswald(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...pendingReqs.map((req) {
                          final reqId = (req['_id'] ?? req['requestId'] ?? req['requesterId']).toString();
                          final isLoading = _loadingCoTutorIds.contains(reqId);
                          final name = req['requesterName'] ?? 'Tutor secundario';
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.navyElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.brandTeal.withAlpha(40)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.navySurface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.brandTeal, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isLoading)
                                  Container(
                                    width: 100,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.navySurface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        LinearProgressIndicator(color: AppTheme.brandTeal, backgroundColor: Colors.white10, minHeight: 4),
                                        SizedBox(height: 4),
                                        Text('Procesando...', style: TextStyle(color: AppTheme.brandTeal, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  )
                                else ...[
                                  GestureDetector(
                                    onTap: () => _rejectCoTutorRequestMain(req),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error.withAlpha(40),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Rechazar',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.error,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _acceptCoTutorRequestMain(req),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.navySurface,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Aceptar',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.brandTeal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                      if (historyReqs.isNotEmpty) ...[
                        if (pendingReqs.isNotEmpty) const SizedBox(height: 16),
                        Text(
                          'HISTORIAL (${historyReqs.length})',
                          style: GoogleFonts.oswald(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...historyReqs.map((req) {
                          final reqId = (req['_id'] ?? req['requestId'] ?? req['requesterId']).toString();
                          final isLoading = _loadingCoTutorIds.contains(reqId);
                          final name = req['requesterName'] ?? 'Tutor secundario';
                          final m = req['mood'];
                          final moodInt = m is int ? m : int.tryParse(m?.toString() ?? '') ?? 0;
                          
                          String statusText = 'Desconocido';
                          Color bgStatus = const Color(0xFFF3F4F6);
                          Color fgStatus = const Color(0xFF6B7280);
                          
                          if (moodInt == 1) {
                            statusText = 'Aprobada';
                            bgStatus = AppTheme.success.withAlpha(40);
                            fgStatus = AppTheme.success;
                          } else if (moodInt == 2) {
                            statusText = 'Rechazada';
                            bgStatus = AppTheme.error.withAlpha(40);
                            fgStatus = AppTheme.error;
                          } else if (moodInt >= 3) {
                            statusText = 'Cancelada';
                            bgStatus = AppTheme.warning.withAlpha(40);
                            fgStatus = AppTheme.warning;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.navyElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.brandTeal.withAlpha(40)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.navySurface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.history_rounded, color: AppTheme.textSecondary, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isLoading)
                                  Container(
                                    width: 100,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.navySurface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        LinearProgressIndicator(color: AppTheme.brandTeal, backgroundColor: Colors.white10, minHeight: 4),
                                        SizedBox(height: 4),
                                        Text('Procesando...', style: TextStyle(color: AppTheme.brandTeal, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  )
                                else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: bgStatus,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: fgStatus,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      if (moodInt == 2) ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _resumeCoTutorRequestMain(req),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.brandTeal.withAlpha(20),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.refresh_rounded, size: 12, color: AppTheme.brandTeal),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Reactivar',
                                                  style: TextStyle(
                                                    color: AppTheme.brandTeal,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  // \u2500\u2500 Helper: wallet info cell
  Widget _walletInfoCell(String label, String value, {required bool isYellow}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isYellow ? _brandAqua : Colors.white,
          ),
        ),
      ],
    );
  }

  // \u2500\u2500 Helper: photo placeholder widget for wallet pass
  Widget _photoPlaceholder() {
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.person, color: Colors.white38, size: 36),
    );
  }

  // \u2500\u2500 Helper: editable row divider
  Widget _editableRow({
    required String label,
    required Widget child,
    required bool hasDivider,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: hasDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF4F4F5))),
            )
          : null,
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          child,
        ],
      ),
    );
  }

  // \u2500\u2500 Date helpers \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

  int _calcAge(String? bd) {
    if (bd == null) return 0;
    final dob = DateTime.tryParse(bd);
    if (dob == null) return 0;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }

  String? _birthYear(String? bd) {
    if (bd == null) return null;
    return DateTime.tryParse(bd)?.year.toString();
  }

  String? _formatDate(String? dateStr) {
    if (dateStr == null) return null;
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // ==========================================================================
  // TAB: EQUIPOS
  // ==========================================================================
  Widget _buildTeamsListCard() {
    final selectivoProcesses = _activeSelectivoProcesses;
    return Column(
      key: const ValueKey('teams-tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ─────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'EQUIPOS',
              style: GoogleFonts.oswald(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: AppTheme.textPrimary,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (!_isViewOnlyMode()) ...[
          // ── Solicitudes premium card ───────────────────────────────────────
          GestureDetector(
            onTap: _openRequestsModal,
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: pendingRequestsCount > 0
                  ? const LinearGradient(
                      colors: [Color(0xFF1F1A00), Color(0xFF2E2600)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [AppTheme.navyElevated, AppTheme.navyPrimary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              boxShadow: [
                BoxShadow(
                  color: pendingRequestsCount > 0
                      ? const Color(0xFFFFD600).withAlpha(60)
                      : AppTheme.brandTeal.withAlpha(20),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: pendingRequestsCount > 0
                    ? const Color(0xFFFFD600).withAlpha(80)
                    : AppTheme.brandTeal.withAlpha(40),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Icono / Contador
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: pendingRequestsCount > 0
                        ? const Color(0xFFFFD600).withAlpha(30)
                        : AppTheme.brandTeal.withAlpha(15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: pendingRequestsCount > 0
                          ? const Color(0xFFFFD600).withAlpha(100)
                          : AppTheme.brandTeal.withAlpha(30),
                    ),
                  ),
                  child: pendingRequestsCount > 0
                      ? Center(
                          child: Text(
                            '$pendingRequestsCount',
                            style: GoogleFonts.oswald(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFFFD600),
                            ),
                          ),
                        )
                      : const Icon(Icons.group_add_rounded, color: AppTheme.brandTeal, size: 24),
                ),
                const SizedBox(width: 16),

                // Texto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            pendingRequestsCount > 0
                                ? 'ATENCIÓN REQUERIDA'
                                : 'MIS SOLICITUDES',
                            style: GoogleFonts.oswald(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: pendingRequestsCount > 0
                                  ? const Color(0xFFFFD600)
                                  : Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (pendingRequestsCount > 0) ...[ 
                            const SizedBox(width: 8),
                            _PulseDot(active: true, color: const Color(0xFFFFD600)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pendingRequestsCount > 0
                            ? '$pendingRequestsCount ${pendingRequestsCount == 1 ? 'solicitud pendiente de respuesta' : 'solicitudes pendientes de respuesta'}'
                            : 'Administrar o iniciar solicitud',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: pendingRequestsCount > 0
                              ? Colors.white.withAlpha(180)
                              : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: pendingRequestsCount > 0
                      ? const Color(0xFFFFD600).withAlpha(200)
                      : Colors.white70,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        ],

        const SizedBox(height: 24),

        // ── Proceso de Selectivo ───────────────────────────────────────────
        if (selectivoProcesses.isNotEmpty) ...[
          ...selectivoProcesses.map(_buildSelectivoProcessCard),
          if (currentTeams.isNotEmpty || oldTeams.isNotEmpty)
            const SizedBox(height: 20),
        ],

        // ── Equipos activos ────────────────────────────────────────────────
        if (currentTeams.isNotEmpty) ...[
          _sectionLabel('Activos'),
          const SizedBox(height: 10),
          ...currentTeams.map((t) => _buildTeamRow(t, isPast: false)),
          const SizedBox(height: 20),
        ],

        // ── Historial ──────────────────────────────────────────────────────
        if (oldTeams.isNotEmpty) ...[
          _sectionLabel('Historial'),
          const SizedBox(height: 10),
          ...oldTeams.map((t) => _buildTeamRow(t, isPast: true)),
        ],

        // ── Empty state ────────────────────────────────────────────────────
        if (currentTeams.isEmpty &&
            oldTeams.isEmpty &&
            selectivoProcesses.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.shield_outlined, size: 48, color: Color(0xFFD4D4D8)),
                  const SizedBox(height: 12),
                  Text('Sin equipos asignados',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Map<String, dynamic>> get _activeSelectivoProcesses {
    if (_isViewOnlyMode()) return const [];
    final wanted = widget.playerId.trim();
    final profileId = (playerData?['id'] ?? wanted).toString().trim();
    final seen = <String>{};
    final list = <Map<String, dynamic>>[];
    for (final r in _selectivoRequests) {
      final candidate = SelectivoHelpers.asMap(r['candidate']);
      if (candidate == null) continue;
      final pid = SelectivoHelpers.playerIdOf(candidate);
      if (pid != wanted && pid != profileId) continue;
      if (!SelectivoHelpers.isActiveProcess(candidate)) continue;
      final cid = (candidate['id'] ?? '').toString();
      if (cid.isNotEmpty && !seen.add(cid)) continue;
      list.add(candidate);
    }
    return list;
  }

  void _openSelectivoProcessDetails(Map<String, dynamic> candidate) {
    if (_isViewOnlyMode()) return;
    if (isLoading || playerData == null) return;
    isModalOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TeamRequestsSheet(
        api: widget.api,
        playerId: widget.playerId,
        userId: userId,
        userUid: userUid,
        playerData: playerData!,
        initialRequests: playerRequests.where((r) => r['type'] != 'co_tutor').toList(),
        requestUpdatesStream: widget.socketService.requestUpdatesStream,
        onDismissed: _refreshRequestsOnly,
        onRequestsChanged: _syncTeamRequestsFromSheet,
        onSelectivoConsentSuccess: _onSelectivoConsentSuccess,
        onSelectivoConsentResetSuccess: _onSelectivoConsentResetSuccess,
        initialSelectivoCandidate: candidate,
      ),
    ).whenComplete(() {
      isModalOpen = false;
    });
  }

  Widget _buildSelectivoProcessCard(Map<String, dynamic> candidate) {
    String textOf(dynamic value) {
      final s = value?.toString().trim() ?? '';
      if (s.isEmpty || s.toLowerCase() == 'null') return '';
      return s;
    }

    final league = SelectivoHelpers.asMap(candidate['league']) ?? <String, dynamic>{};
    final call = SelectivoHelpers.asMap(candidate['selectionCall']) ?? <String, dynamic>{};
    final team = SelectivoHelpers.asMap(candidate['team']) ?? <String, dynamic>{};
    final category = SelectivoHelpers.asMap(candidate['category']) ??
        SelectivoHelpers.asMap(team['category']) ??
        <String, dynamic>{};
    final academy = SelectivoHelpers.asMap(candidate['academy']) ?? <String, dynamic>{};

    final leagueName = textOf(league['name']);
    final leagueLogo = textOf(league['logo']).isNotEmpty
        ? textOf(league['logo'])
        : textOf(league['thumb']);
    final callName = textOf(call['name']);
    final teamName = textOf(team['name']);
    final categoryName = textOf(category['name']);
    final academyName = textOf(academy['name']);
    final status = textOf(candidate['status']);
    final statusLabel = SelectivoHelpers.processStatusLabel(status);
    final teamLine = [categoryName, teamName].where((p) => p.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSelectivoProcessDetails(candidate),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF122A36),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.brandTeal.withAlpha(90)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandTeal.withAlpha(18),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROCESO DE SELECTIVO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.brandTeal,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ClipOval(
                      child: leagueLogo.isNotEmpty
                          ? Image.network(
                              leagueLogo,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => _selectivoProcessLogoPlaceholder(),
                            )
                          : _selectivoProcessLogoPlaceholder(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        leagueName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (callName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    callName,
                    style: GoogleFonts.oswald(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (teamLine.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    teamLine,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                _buildSelectivoProcessStages(status),
                if (statusLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
                if (academyName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Propuesto por $academyName',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white38,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectivoProcessLogoPlaceholder() {
    return Container(
      width: 36,
      height: 36,
      color: const Color(0xFF1C1C1C),
      alignment: Alignment.center,
      child: const Icon(Icons.shield_outlined, color: Colors.white38, size: 18),
    );
  }

  Widget _buildSelectivoProcessStages(String status) {
    final current = SelectivoHelpers.processStageIndex(status);
    const labels = ['Consentimiento', 'Aprobación', 'Selección'];
    const shortLabels = ['Consent.', 'Aprob.', 'Selecc.'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final names = constraints.maxWidth < 340 ? shortLabels : labels;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      width: 10,
                      height: 1,
                      color: Colors.white24,
                    ),
                  ),
                _selectivoProcessStageMark(
                  names[i],
                  done: current >= 3 || i < current,
                  current: current < 3 && i == current,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _selectivoProcessStageMark(String label, {required bool done, required bool current}) {
    final Color color;
    final Widget mark;
    if (done) {
      color = AppTheme.brandTeal;
      mark = const Icon(Icons.check, size: 12, color: AppTheme.brandTeal);
    } else if (current) {
      color = Colors.white;
      mark = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.brandTeal, width: 1.4),
        ),
      );
    } else {
      color = Colors.white38;
      mark = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38, width: 1.2),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamRow(dynamic t, {required bool isPast}) {
    final name = (t['name'] ?? 'Equipo').toString();
    final num = _toInt(t['num']);
    final tournamentName = (t['tournament']?['name'] ?? '').toString();
    final categoryName = (t['category']?['name'] ?? '').toString();
    final logo = (t['logo'] ?? t['team']?['logo'] ?? t['academy']?['logo'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPast ? Colors.transparent : AppTheme.navySurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isPast ? Colors.white.withAlpha(20) : AppTheme.brandTeal.withAlpha(50)),
          boxShadow: [
            if (!isPast)
              BoxShadow(
                color: AppTheme.brandTeal.withAlpha(15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Opacity(
          opacity: isPast ? 0.6 : 1.0,
          child: Row(
            children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColorFiltered(
                  colorFilter: isPast
                      ? const ColorFilter.matrix([
                          0.33, 0.33, 0.33, 0, 0,
                          0.33, 0.33, 0.33, 0, 0,
                          0.33, 0.33, 0.33, 0, 0,
                          0,    0,    0,    1, 0,
                        ])
                      : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                  child: logo.isNotEmpty
                      ? Image.network(logo, width: 52, height: 52, fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => _logoPlaceholder(isPast))
                      : _logoPlaceholder(isPast),
                ),
              ),
              const SizedBox(width: 14),

              // Name + tournament
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: GoogleFonts.oswald(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tournamentName.isNotEmpty || categoryName.isNotEmpty)
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            if (categoryName.isNotEmpty)
                              TextSpan(
                                text: categoryName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: isPast ? Colors.white70 : AppTheme.brandTeal,
                                ),
                              ),
                            if (categoryName.isNotEmpty && tournamentName.isNotEmpty)
                              const TextSpan(
                                text: ' • ',
                                style: TextStyle(fontSize: 11, color: Colors.white38),
                              ),
                            if (tournamentName.isNotEmpty)
                              TextSpan(
                                text: tournamentName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white54,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Number badge
              if (num > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '#',
                          style: GoogleFonts.oswald(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                            color: isPast ? Colors.white.withAlpha(40) : Colors.white.withAlpha(100),
                          ),
                        ),
                        TextSpan(
                          text: '$num',
                          style: GoogleFonts.oswald(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -1,
                            color: isPast ? Colors.white.withAlpha(60) : Colors.white.withAlpha(160),
                            shadows: isPast 
                                ? null 
                                : [Shadow(color: AppTheme.brandTeal.withAlpha(40), blurRadius: 8)],
                          ),
                        ),
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

  Widget _logoPlaceholder(bool isPast) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: isPast ? const Color(0xFFF4F4F5) : const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.shield_outlined,
        color: isPast ? const Color(0xFFD4D4D8) : Colors.white38,
        size: 24,
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: Color(0xFF9CA3AF), letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildStatsHistoryCard() {
    // 1. Calculate Aggregate Radar Data using `activeStats`
    final stats = activeStats;
    double maxStat = 1.0;
    
    double pts = double.tryParse((stats['totalPoints'] ?? stats['points'] ?? 0).toString()) ?? 0;
    double pass = double.tryParse((stats['passingTD'] ?? stats['pass'] ?? 0).toString()) ?? 0;
    double rec = double.tryParse((stats['totalRecepciones'] ?? stats['catch'] ?? 0).toString()) ?? 0;
    double run = double.tryParse((stats['totalCarreras'] ?? stats['run'] ?? 0).toString()) ?? 0;
    
    final sck = double.tryParse((stats['sacks'] ?? stats['sack'] ?? 0).toString()) ?? 0;
    final intc = double.tryParse((stats['interceptions'] ?? stats['inter'] ?? 0).toString()) ?? 0;
    
    maxStat = [pass, rec, sck, run, intc].reduce((a, b) => a > b ? a : b);
    if (maxStat < 10) maxStat = 10; // Normalized minimum ceiling

    String archetype = 'NOVATO';
    if (pass > rec && pass > sck && pass > run && pass > intc) archetype = 'FRANCOTIRADOR';
    else if (rec > pass && rec > sck && rec > run && rec > intc) archetype = 'RECEPTOR LETAL';
    else if ((sck + intc) > pass && (sck + intc) > rec && (sck + intc) > run) archetype = 'CAZADOR';
    else if (run > pass && run > rec && run > sck && run > intc) archetype = 'SPEEDSTER';
    else if (pass > 0 || rec > 0 || sck > 0) archetype = 'TODOTERRENO';

    return Column(
      key: const ValueKey('stats-card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── PREMIUM STATS CARD ──
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // ── Carousel Header ──
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      iconSize: 32,
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        final len = carouselOptions.length;
                        if (len <= 1) return;
                        setState(() => activeCarouselIndex = (activeCarouselIndex - 1 + len) % len);
                        await _updateActiveStats();
                      },
                      icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.brandTeal),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (carouselOptions[activeCarouselIndex]['name'] ?? 'Resumen').toString().toUpperCase(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.oswald(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: Colors.white,
                              shadows: [Shadow(color: AppTheme.brandTeal.withAlpha(80), blurRadius: 8)],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (carouselOptions[activeCarouselIndex]['type'] == 'team')
                            Builder(builder: (context) {
                              final t = carouselOptions[activeCarouselIndex];
                              final cat = (t['category']?['name'] ?? '').toString();
                              final tour = (t['tournament']?['name'] ?? '').toString();
                              final subtitle = [cat, tour].where((s) => s.isNotEmpty).join(' • ');
                              if (subtitle.isEmpty) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white60,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    IconButton(
                      iconSize: 32,
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        final len = carouselOptions.length;
                        if (len <= 1) return;
                        setState(() => activeCarouselIndex = (activeCarouselIndex + 1) % len);
                        await _updateActiveStats();
                      },
                      icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.brandTeal),
                    ),
                  ],
                ),
              ),
              
              Divider(color: Colors.white.withAlpha(20), height: 1, thickness: 1),

              if (isLoadingTeamStats) const LinearProgressIndicator(color: AppTheme.brandTeal),
              
              // ── Totales (Grid) ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(child: _statChip('PTS', stats['totalPoints'] ?? stats['points'] ?? 0)),
                          VerticalDivider(color: Colors.white.withAlpha(20), thickness: 1, width: 1),
                          Expanded(child: _statChip('PAS', stats['passingTD'] ?? stats['pass'] ?? 0)),
                          VerticalDivider(color: Colors.white.withAlpha(20), thickness: 1, width: 1),
                          Expanded(child: _statChip('REC', stats['totalRecepciones'] ?? stats['catch'] ?? 0)),
                        ],
                      ),
                    ),
                    Divider(color: Colors.white.withAlpha(20), thickness: 1, height: 1),
                    IntrinsicHeight(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(child: _statChip('RUN', stats['totalCarreras'] ?? stats['run'] ?? 0)),
                          VerticalDivider(color: Colors.white.withAlpha(20), thickness: 1, width: 1),
                          Expanded(child: _statChip('SCK', stats['sacks'] ?? stats['sack'] ?? 0)),
                          VerticalDivider(color: Colors.white.withAlpha(20), thickness: 1, width: 1),
                          Expanded(child: _statChip('INT', stats['interceptions'] ?? stats['inter'] ?? 0)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // \u2500\u2500 Radar Chart HUD \u2500\u2500
        RadarChartHUD(
          pass: pass / maxStat,
          rec: rec / maxStat,
          sck: sck / maxStat,
          run: run / maxStat,
          intc: intc / maxStat,
          archetype: archetype,
        ),
        const SizedBox(height: 24),

        // Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'HISTORIAL DE PARTIDOS',
              style: GoogleFonts.oswald(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (isLoadingStats)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: Colors.black)),
          )
        else if (statsHistory == null || statsHistory!.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.history_toggle_off, size: 48, color: Color(0xFFD4D4D8)),
                  const SizedBox(height: 12),
                  Text('Aún no tienes historial de estadísticas',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF))),
                ],
              ),
            ),
          )
        else ...[

          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: statsHistory!.map((torneoItem) {
                final torneo = torneoItem as Map<String, dynamic>;
                return _TournamentHistoryAccordion(
                  torneo: torneo,
                  buildLogItem: _buildMatchLogItem,
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  String _formatMatchDate(String rawDate) {
    if (rawDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      const days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
      const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
      final dayStr = days[dt.weekday - 1];
      final monthStr = months[dt.month - 1];
      final hr = dt.hour.toString().padLeft(2, '0');
      final mn = dt.minute.toString().padLeft(2, '0');
      return '$dayStr ${dt.day} $monthStr $hr:$mn hrs';
    } catch (_) {
      return rawDate;
    }
  }

  String _mapActionName(String raw) {
    final key = raw.toLowerCase();
    if (key.contains('pass') || key.contains('pase')) return 'PAS';
    if (key.contains('recep') || key.contains('catch')) return 'REC';
    if (key.contains('run') || key.contains('carrera')) return 'RUN';
    if (key.contains('sack') || key.contains('captura')) return 'SCK';
    if (key.contains('intercep') || key.contains('int')) return 'INT';
    if (key.length <= 3) return raw.toUpperCase();
    return raw.substring(0, 3).toUpperCase();
  }

  void _openHistoryMatchDetail(Map<String, dynamic> matchItem) {
    final matchId = MatchHelpers.matchId(matchItem);
    if (matchId.isEmpty) {
      _toast('No se pudo abrir el partido', isError: true);
      return;
    }
    Navigator.of(context).pushNamed(
      MatchDetailRoute.routeFor(matchId),
      arguments: MatchDetailRouteArgs(matchId: matchId),
    );
  }

  Widget _buildMatchLogItem(dynamic matchMap, {required bool isLast}) {
    final m = matchMap as Map<String, dynamic>;
    final result = (m['resultado'] ?? '').toString();
    final rival = (m['rivalName'] ?? 'Rival').toString();
    final logo = (m['rivalLogo'] ?? '').toString();
    final date = _formatMatchDate(m['fecha']?.toString() ?? '');
    String journey = (m['journey'] ?? '').toString();
    if (int.tryParse(journey) != null) journey = 'J$journey';
    final actions = m['actions'] as List<dynamic>? ?? [];

    // Parse Result Pill (G/P/E)
    final rParts = result.split(' ');
    final wL = rParts.isNotEmpty ? rParts[0] : '';
    final cleanScore = rParts.length > 1 ? rParts.sublist(1).join('') : result;
    Color pillColor = Colors.grey;
    Color pillTextColor = Colors.white;
    if (wL == 'G') {
      pillColor = const Color(0xFF3BD0AE);
    } else if (wL == 'P') {
      pillColor = const Color(0xFFFF3366);
    } else if (wL == 'E') {
      pillColor = Colors.grey.shade500;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Line & Dot
          SizedBox(
            width: 30,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!isLast)
                  Positioned(
                    top: 24, bottom: 0,
                    child: Container(width: 2, color: pillColor.withAlpha(80)),
                  ),
                Positioned(
                  top: 24,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: pillColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F172A), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openHistoryMatchDetail(m),
                child: Container(
              padding: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : Colors.white10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TEAM NAME & RESULT
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if ((m['myTeamName'] ?? '').toString().isNotEmpty)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              m['myTeamName'].toString().toUpperCase(),
                              style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                              maxLines: 1, 
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      if (wL == 'G' || wL == 'P' || wL == 'E')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, left: 8),
                          child: Text(
                            wL == 'G' ? 'VICTORIA' : (wL == 'P' ? 'DERROTA' : 'EMPATE'),
                            style: GoogleFonts.oswald(
                              color: pillColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      // VS Text
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Text(
                          'VS', 
                          style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                      ),
                      // Logo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: logo.isNotEmpty
                            ? Image.network(logo, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _matchLogoPlace())
                            : _matchLogoPlace(),
                      ),
                      const SizedBox(width: 12),
                      // Nombres
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rival.toUpperCase(),
                              style: GoogleFonts.oswald(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              [journey, date].where((s) => s.isNotEmpty).join(' • '),
                              style: GoogleFonts.robotoMono(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      // Marcador (Solo Texto)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          cleanScore.replaceAll(RegExp(r'\s*-\s*'), ' : '),
                          style: GoogleFonts.robotoMono(
                            color: wL == 'G' ? const Color(0xFF3BD0AE) : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: wL == 'G' ? 18 : 14,
                            letterSpacing: 1,
                            shadows: [
                              if (wL == 'G' || wL == 'P')
                                Shadow(color: pillColor.withAlpha(150), blurRadius: wL == 'G' ? 12 : 8)
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Actions log
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        // Aggregate actions by mapped key
                        final agg = <String, Map<String, int>>{};
                        for (var a in actions) {
                          final act = a as Map<String, dynamic>;
                          final mappedKey = _mapActionName((act['clave'] ?? '').toString());
                          final pts = int.tryParse((act['puntos'] ?? 0).toString()) ?? 0;

                          if (!agg.containsKey(mappedKey)) {
                            agg[mappedKey] = {'count': 0, 'points': 0};
                          }
                          agg[mappedKey]!['count'] = agg[mappedKey]!['count']! + 1;
                          agg[mappedKey]!['points'] = agg[mappedKey]!['points']! + pts;
                        }

                        // Sort to keep consistent order (optional, but nice)
                        final sortedEntries = agg.entries.toList()..sort((a, b) => b.value['points']!.compareTo(a.value['points']!));

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: sortedEntries.map((e) {
                            final keyName = e.key;
                            final count = e.value['count']!;
                            final points = e.value['points']!;
                            
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    count > 1 ? '$count $keyName' : keyName,
                                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                  if (points > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '$points ptos',
                                      style: const TextStyle(color: AppTheme.brandTeal, fontSize: 11, fontWeight: FontWeight.w900),
                                    ),
                                  ]
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      }
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Sin registro de jugadas',
                      style: TextStyle(color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic),
                    )
                  ]
                ],
              ),
            ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchLogoPlace() {
    return Container(
      width: 36, height: 36,
      color: Colors.white12,
      child: const Icon(Icons.shield, color: Colors.white38, size: 18),
    );
  }

  Widget _statChip(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value', 
            style: GoogleFonts.oswald(
              fontSize: 32, 
              fontWeight: FontWeight.w900, 
              fontStyle: FontStyle.italic,
              color: Colors.white,
              letterSpacing: -1,
              shadows: [
                Shadow(color: AppTheme.brandTeal.withAlpha(150), blurRadius: 10),
              ]
            )
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(), 
            style: GoogleFonts.inter(
              fontSize: 10, 
              fontWeight: FontWeight.w700, 
              color: Colors.white54,
              letterSpacing: 2,
            )
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _TeamRequestsSheet — gestión completa de solicitudes (equivalente Ionic modal)
// =============================================================================
class _TeamRequestsSheet extends StatefulWidget {
  const _TeamRequestsSheet({
    required this.api,
    required this.playerId,
    required this.userId,
    required this.userUid,
    required this.playerData,
    required this.initialRequests,
    required this.requestUpdatesStream,
    required this.onDismissed,
    this.onRequestsChanged,
    this.onSelectivoConsentSuccess,
    this.onSelectivoConsentResetSuccess,
    this.startOnSearch = false,
    this.initialSelectivoCandidate,
  });

  final ApiService api;
  final String playerId;
  final String userId;
  final String userUid;
  final Map<String, dynamic> playerData;
  final List<dynamic> initialRequests;
  final Stream<dynamic> requestUpdatesStream;
  final Future<void> Function() onDismissed;
  final void Function(List<Map<String, dynamic>> teamRequests)? onRequestsChanged;
  final void Function(bool wasAbleToRespond)? onSelectivoConsentSuccess;
  final void Function(bool couldRespondBefore)? onSelectivoConsentResetSuccess;
  final bool startOnSearch;
  final Map<String, dynamic>? initialSelectivoCandidate;

  @override
  State<_TeamRequestsSheet> createState() => _TeamRequestsSheetState();
}

class _TeamRequestsSheetState extends State<_TeamRequestsSheet> {
  static const _brandAqua = AppTheme.brandTeal;
  static const _appBg = AppTheme.navyPrimary;

  static const _moodNames = ['Pendiente', 'Aceptado', 'Rechazado', 'Cancelado'];
  static const _moodColors = [
    Color(0xFFEAB308),
    Color(0xFF22C55E),
    Color(0xFFEF4444),
    Color(0xFF71717A),
  ];
  static const _moodIcons = [
    Icons.hourglass_top_rounded,
    Icons.check_circle_rounded,
    Icons.cancel_rounded,
    Icons.remove_circle_rounded,
  ];

  // ── State ──
  late List<Map<String, dynamic>> _requests;
  List<dynamic> _pending = [];
  List<dynamic> _history = [];
  int _segment = 0; // 0: pendiente, 1: historial
  bool _showSearch = false;

  // Per-request loading sets
  final Set<String> _loadingIds = {};
  bool _selectivoConsentInFlight = false;
  bool _selectivoResetInFlight = false;

  // Search state
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchType = 'name';
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  String _searchError = '';
  Timer? _debounce;
  String? _sendingAcademyId;

  // Socket
  StreamSubscription<dynamic>? _socketSub;

  @override
  void initState() {
    super.initState();
    _requests = widget.initialRequests
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    _processRequests();
    if (widget.startOnSearch) _showSearch = true;

    if (widget.startOnSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }

    final initialSelectivo = widget.initialSelectivoCandidate;
    if (initialSelectivo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSelectivoDetails(initialSelectivo);
      });
    }

    // Escuchar socket para actualizar en tiempo real mientras el Sheet está abierto
    _socketSub = widget.requestUpdatesStream.listen((data) {
      if (!mounted || data == null) return;
      // Ignorar si el cambio lo hicimos nosotros (ya se actualizó localmente de forma optimista)
      if (data['actingUserId'] == widget.userId) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          final incoming = Map<String, dynamic>.from(data as Map);
          final reqId = incoming['_id'] ?? incoming['id'];

          final idx = _requests.indexWhere((r) => _reqId(r) == reqId);
          if (idx != -1) {
            _requests[idx] = incoming;
          } else {
            _requests.insert(0, incoming);
          }
          _processRequests();
        });
      });
    });
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _processRequests() {
    _pending = _requests.where((r) {
      if (SelectivoHelpers.isSelectivoRequest(r)) {
        return SelectivoHelpers.needsConsentResponse(r);
      }
      return _toMood(r['mood']) == 0;
    }).toList();
    _history = _requests.where((r) {
      if (SelectivoHelpers.isSelectivoRequest(r)) {
        return !SelectivoHelpers.needsConsentResponse(r);
      }
      return _toMood(r['mood']) >= 1;
    }).toList()
      ..sort((a, b) => _toMood(a['mood']).compareTo(_toMood(b['mood'])));
    widget.onRequestsChanged?.call(List<Map<String, dynamic>>.from(_requests));
  }

  Future<void> _showPendingRequestsAfterSend() async {
    widget.onRequestsChanged?.call(List<Map<String, dynamic>>.from(_requests));
    await widget.onDismissed();
    if (!mounted) return;
    setState(() {
      _showSearch = false;
      _segment = 0;
      _searchCtrl.clear();
      _searchResults = [];
      _searchError = '';
      _searchType = 'name';
    });
  }

  int _toMood(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _reqId(Map<String, dynamic> r) =>
      (r['_id'] ?? r['id'] ?? '').toString();

  void _setLoading(Map<String, dynamic> r, bool val) {
    setState(() {
      if (val) {
        _loadingIds.add(_reqId(r));
      } else {
        _loadingIds.remove(_reqId(r));
      }
    });
  }

  bool _isLoading(Map<String, dynamic> r) => _loadingIds.contains(_reqId(r));

  Future<void> _updateMood(Map<String, dynamic> r, int mood, {String? newOrigin}) async {
    if (SelectivoHelpers.isSelectivoRequest(r)) return;
    final originalMood = r['mood'];
    final originalOrigin = r['origin'];
    
    setState(() {
      r['mood'] = mood;
      if (newOrigin != null) r['origin'] = newOrigin;
    });
    _setLoading(r, true);
    
    try {
      final updated = Map<String, dynamic>.from(r);
      // Ensure local state changes are present in updated object
      updated['mood'] = mood;
      if (newOrigin != null) updated['origin'] = newOrigin;
      
      final resp = await widget.api.updateRequest(request: updated, userId: widget.userId);
      if (resp['ok'] == true || resp['rev'] != null) {
        r['_rev'] = resp['rev'];
        _processRequests();
        if (mounted) setState(() {});
      }
    } catch (e) {
      print('Error en _updateMood: $e'); // Debugging
      if (!mounted) return;
      setState(() {
        r['mood'] = originalMood;
        if (newOrigin != null) r['origin'] = originalOrigin;
      });
      _showToast('Error: $e', isError: true);
    } finally {
      if (mounted) _setLoading(r, false);
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> r) async {
    await _updateMood(r, 1);
    if (mounted) {
      _showToast('¡Invitación aceptada!');
      await widget.onDismissed();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> r) async {
    await _updateMood(r, 2);
    if (mounted) _showToast('Invitación rechazada.');
  }

  Future<void> _acceptCoTutorRequest(Map<String, dynamic> r) async {
    _setLoading(r, true);
    try {
      final childId = widget.playerId;
      final existingRequests = (widget.playerData['co_tutor_requests'] as List<dynamic>?) ?? [];
      final updatedRequests = List<Map<String, dynamic>>.from(
        existingRequests.map((e) => Map<String, dynamic>.from(e as Map))
      );
      
      for (final req in updatedRequests) {
        final reqIdMatch = req['requestId'] != null && r['requestId'] != null && req['requestId'].toString() == r['requestId'].toString();
        final requesterMatch = req['requesterId'] != null && r['requesterId'] != null && req['requesterId'].toString() == r['requesterId'].toString();
        // Fallback for null equality
        final nullMatch = req['requestId'] == null && r['requestId'] == null && req['requesterId'] == r['requesterId'];
        
        if (reqIdMatch || requesterMatch || nullMatch) {
          req['status'] = 'approved';
        }
      }
      
      final coTutorData = {
        'id': r['requesterId'],
        'name': r['requesterName']
      };

      final resp = await widget.api.updateDoc({
        '_id': childId,
        'co_tutor': coTutorData,
        'co_tutor_requests': updatedRequests,
      });

      if (resp['ok'] == true || resp['status'] != 'error') {
        widget.playerData['co_tutor'] = coTutorData;
        widget.playerData['co_tutor_requests'] = updatedRequests;
        
        final requesterId = r['requesterId'];
        if (requesterId != null) {
          try {
            final requesterRes = await widget.api.getUserContext(requesterId);
            final requesterDoc = requesterRes['user'] as Map<String, dynamic>?;
            if (requesterDoc != null) {
              final coManaged = (requesterDoc['co_managed_children'] as List<dynamic>?) ?? [];
              final updatedCoManaged = List<Map<String, dynamic>>.from(
                coManaged.map((e) => Map<String, dynamic>.from(e as Map))
              );
              for (final item in updatedCoManaged) {
                final matchChildId = item['childId']?.toString() == childId.toString();
                final matchPlayerId = item['playerId']?.toString() == childId.toString();
                final matchId = item['id']?.toString() == childId.toString();
                
                if (matchChildId || matchPlayerId || matchId) {
                  item['status'] = 'approved';
                }
              }
              await widget.api.updateDoc({
                '_id': requesterDoc['_id'],
                'co_managed_children': updatedCoManaged,
              });
            }
          } catch (_) {}
        }
        
        if (mounted) {
          setState(() {
            r['mood'] = 1;
            r['status'] = 'approved';
          });
          _processRequests();
          _showToast('Co-Tutoría aprobada');
          await widget.onDismissed();
          if (mounted) Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) _showToast('Error al aceptar Co-Tutoría', isError: true);
    } finally {
      if (mounted) _setLoading(r, false);
    }
  }

  Future<void> _rejectCoTutorRequest(Map<String, dynamic> r) async {
    _setLoading(r, true);
    try {
      final childId = widget.playerId;
      final existingRequests = (widget.playerData['co_tutor_requests'] as List<dynamic>?) ?? [];
      final updatedRequests = List<Map<String, dynamic>>.from(
        existingRequests.map((e) => Map<String, dynamic>.from(e as Map))
      );
      
      for (final req in updatedRequests) {
        final reqIdMatch = req['requestId'] != null && r['requestId'] != null && req['requestId'].toString() == r['requestId'].toString();
        final requesterMatch = req['requesterId'] != null && r['requesterId'] != null && req['requesterId'].toString() == r['requesterId'].toString();
        // Fallback for null equality
        final nullMatch = req['requestId'] == null && r['requestId'] == null && req['requesterId'] == r['requesterId'];
        
        if (reqIdMatch || requesterMatch || nullMatch) {
          req['status'] = 'rejected';
        }
      }

      final resp = await widget.api.updateDoc({
        '_id': childId,
        'co_tutor_requests': updatedRequests,
      });

      if (resp['ok'] == true || resp['status'] != 'error') {
        widget.playerData['co_tutor_requests'] = updatedRequests;
        
        final requesterId = r['requesterId'];
        if (requesterId != null) {
          try {
            final requesterRes = await widget.api.getUserContext(requesterId);
            final requesterDoc = requesterRes['user'] as Map<String, dynamic>?;
            if (requesterDoc != null) {
              final coManaged = (requesterDoc['co_managed_children'] as List<dynamic>?) ?? [];
              final updatedCoManaged = List<Map<String, dynamic>>.from(
                coManaged.map((e) => Map<String, dynamic>.from(e as Map))
              );
              for (final item in updatedCoManaged) {
                final matchChildId = item['childId']?.toString() == childId.toString();
                final matchPlayerId = item['playerId']?.toString() == childId.toString();
                final matchId = item['id']?.toString() == childId.toString();
                
                if (matchChildId || matchPlayerId || matchId) {
                  item['status'] = 'rejected';
                }
              }
              await widget.api.updateDoc({
                '_id': requesterDoc['_id'],
                'co_managed_children': updatedCoManaged,
              });
            }
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            r['mood'] = 2;
            r['status'] = 'rejected';
          });
          _processRequests();
          _showToast('Co-Tutoría rechazada');
        }
      }
    } catch (e) {
      if (mounted) _showToast('Error al rechazar Co-Tutoría', isError: true);
    } finally {
      if (mounted) _setLoading(r, false);
    }
  }

  Future<void> _resumeCoTutorRequest(Map<String, dynamic> r) async {
    _setLoading(r, true);
    try {
      final childId = widget.playerId;
      final existingRequests = (widget.playerData['co_tutor_requests'] as List<dynamic>?) ?? [];
      final updatedRequests = List<Map<String, dynamic>>.from(
        existingRequests.map((e) => Map<String, dynamic>.from(e as Map))
      );
      
      for (final req in updatedRequests) {
        final reqIdMatch = req['requestId'] != null && r['requestId'] != null && req['requestId'].toString() == r['requestId'].toString();
        final requesterMatch = req['requesterId'] != null && r['requesterId'] != null && req['requesterId'].toString() == r['requesterId'].toString();
        final nullMatch = req['requestId'] == null && r['requestId'] == null && req['requesterId'] == r['requesterId'];
        
        if (reqIdMatch || requesterMatch || nullMatch) {
          req['status'] = 'pending';
        }
      }

      final resp = await widget.api.updateDoc({
        '_id': childId,
        'co_tutor_requests': updatedRequests,
      });

      if (resp['ok'] == true || resp['status'] != 'error') {
        widget.playerData['co_tutor_requests'] = updatedRequests;
        
        final requesterId = r['requesterId'];
        if (requesterId != null) {
          try {
            final requesterRes = await widget.api.getUserContext(requesterId);
            final requesterDoc = requesterRes['user'] as Map<String, dynamic>?;
            if (requesterDoc != null) {
              final coManaged = (requesterDoc['co_managed_children'] as List<dynamic>?) ?? [];
              final updatedCoManaged = List<Map<String, dynamic>>.from(
                coManaged.map((e) => Map<String, dynamic>.from(e as Map))
              );
              for (final item in updatedCoManaged) {
                final matchChildId = item['childId']?.toString() == childId.toString();
                final matchPlayerId = item['playerId']?.toString() == childId.toString();
                final matchId = item['id']?.toString() == childId.toString();
                
                if (matchChildId || matchPlayerId || matchId) {
                  item['status'] = 'pending';
                }
              }
              await widget.api.updateDoc({
                '_id': requesterDoc['_id'],
                'co_managed_children': updatedCoManaged,
              });
            }
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            r['mood'] = 0;
            r['status'] = 'pending';
          });
          _processRequests();
          _showToast('Solicitud de Co-Tutoría reactivada');
        }
      }
    } catch (e) {
      if (mounted) _showToast('Error al reactivar Co-Tutoría', isError: true);
    } finally {
      if (mounted) _setLoading(r, false);
    }
  }

  Future<void> _confirmCancelAccepted(Map<String, dynamic> r) async {
    final academy = (r['academy']?['name'] ?? 'este equipo').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Cancelar inscripción?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Estás a punto de cancelar tu lugar en $academy.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Mantener lugar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Sí, cancelar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _updateMood(r, 3);
      if (mounted) {
        _showToast('Inscripción cancelada.');
        await widget.onDismissed();
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  Future<void> _resendRequest(Map<String, dynamic> r) async {
    await _updateMood(r, 0, newOrigin: 'player');
    if (mounted) _showToast('Solicitud reactivada.');
  }

  Future<void> _deleteRequestPlayer(Map<String, dynamic> r) async {
    if (SelectivoHelpers.isSelectivoRequest(r)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar solicitud',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('¿Estás seguro de que deseas eliminar esta solicitud definitivamente? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Sí, eliminar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    _setLoading(r, true);
    try {
      final reqId = _reqId(r);
      final resp = await widget.api.deleteRequestPlayer(reqId);

      if (resp['status'] == 'ok') {
        setState(() {
          _requests.removeWhere((req) => _reqId(req) == reqId);
          _processRequests();
        });
        _showToast('Solicitud eliminada definitivamente.');
      } else {
        _showToast(resp['message']?.toString() ?? 'Error al eliminar', isError: true);
      }
    } catch (e) {
      if (mounted) _showToast('Error de conexión al eliminar.', isError: true);
    } finally {
      if (mounted) _setLoading(r, false);
    }
  }

  // ── Search / Send ──────────────────────────────────────────────────────────

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() { _searchResults = []; _searchError = ''; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _runSearch(q.trim()));
  }

  Future<void> _runSearch(String q) async {
    setState(() { _isSearching = true; _searchError = ''; });
    try {
      final results = await widget.api.searchAcademies(q, _searchType);
      if (!mounted) return;
      // Marca si ya existe una solicitud para cada academia
      final enriched = results.map((a) {
        final map = Map<String, dynamic>.from(a as Map);
        map['existingRequest'] = _requests.firstWhere(
          (r) => (r['academy']?['id'] ?? r['academy']?['_id']) == (a['id'] ?? a['_id']),
          orElse: () => <String, dynamic>{},
        );
        return map;
      }).toList();
      setState(() => _searchResults = enriched);
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchError = 'Error de conexión. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendRequest(dynamic academy) async {
    final playerName = _playerDisplayName();
    final academyName = (academy['name'] ?? 'la academia').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirmar solicitud',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Enviarás una solicitud para que $playerName se integre a $academyName.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.brandTeal),
            child: const Text(
              'Enviar solicitud',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final academyId = (academy['id'] ?? academy['_id'] ?? '').toString();
    setState(() {
      _isSearching = true;
      _sendingAcademyId = academyId.isNotEmpty ? academyId : null;
    });
    try {
      final pd = widget.playerData;
      final requestDoc = <String, dynamic>{
        'type': 'requestPlayer',
        'mood': 0,
        'origin': 'player',
        'player': {
          'id': pd['_id'],
          'name': pd['name'],
          'userName': pd['userName'],
          'bd': pd['bd'],
          'alias': pd['alias'],
          'gender': pd['gender'],
          'thumb': pd['thumb'],
        },
        'academy': {
          'id': academy['id'] ?? academy['_id'],
          'name': academy['name'],
          'thumb': academy['logo_url'] ?? academy['logo'],
          if (_academyPublicKey(academy).isNotEmpty) 'public_key': _academyPublicKey(academy),
        },
        'date': DateTime.now().toIso8601String(),
      };

      final resp = await widget.api.updateRequest(
        request: requestDoc,
        userId: widget.userId,
      );
      if (resp['ok'] == true || resp['rev'] != null) {
        requestDoc['_id'] = resp['id'];
        requestDoc['_rev'] = resp['rev'];
        final targetId = (academy['id'] ?? academy['_id'] ?? '').toString();
        setState(() {
          _requests.insert(0, requestDoc);
          _processRequests();
          _searchResults = _searchResults.map((a) {
            final map = Map<String, dynamic>.from(a as Map);
            final id = (map['id'] ?? map['_id'] ?? '').toString();
            if (id.isNotEmpty && id == targetId) {
              map['existingRequest'] = requestDoc;
            }
            return map;
          }).toList();
        });
        _showToast('¡Solicitud enviada con éxito!');
        await _showPendingRequestsAfterSend();
      }
    } catch (e) {
      if (!mounted) return;
      _showToast('Ya existe una solicitud o hubo un error.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _sendingAcademyId = null;
        });
      }
    }
  }

  Future<void> _resendExisting(dynamic existingRequest) async {
    final r = Map<String, dynamic>.from(existingRequest as Map);
    _requests.removeWhere((req) => _reqId(req) == _reqId(r));
    _requests.insert(0, r);
    await _resendRequest(r);
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ToastService.show(
      msg,
      isError: isError,
      backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _appBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            // ── Drag handle ──────────────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D4D8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (_showSearch) ...[
                    GestureDetector(
                      onTap: () => setState(() {
                        _showSearch = false;
                        _searchCtrl.clear();
                        _searchResults = [];
                        _searchError = '';
                      }),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      _showSearch ? 'SOLICITAR INGRESO' : 'SOLICITUDES',
                      style: GoogleFonts.oswald(
                        fontSize: 26, fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textPrimary, letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (!_showSearch) ...[
                    if (_pending.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _brandAqua,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_pending.length} pendientes',
                          style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: () => setState(() => _showSearch = true),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.brandTeal.withAlpha(20), 
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.brandTeal.withAlpha(100)),
                        ),
                        child: const Icon(Icons.add_rounded, color: AppTheme.brandTeal, size: 22),
                      ),
                    ),
                  ] else
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            if (_showSearch) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildPlayerRequestContext(),
              ),
            ],
            const SizedBox(height: 16),

            // ── Content ───────────────────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: _showSearch
                    ? _buildSearchView(scrollCtrl)
                    : _buildRequestsView(scrollCtrl),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Requests view (segment Pendiente / Historial) ──────────────────────────

  Widget _buildRequestsView(ScrollController scrollCtrl) {
    final list = _segment == 0 ? _pending : _history;

    return Column(
      key: const ValueKey('requests-view'),
      children: [
        // Segment
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(60),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _segmentBtn('Pendiente (${_pending.length})', 0),
                _segmentBtn('Historial (${_history.length})', 1),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // List
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFD4D4D8)),
                      const SizedBox(height: 12),
                      Text(
                        _segment == 0 ? 'Sin solicitudes pendientes' : 'Sin historial',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                )
              : (_segment == 0
                  ? ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: list.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) =>
                          _buildRequestCard(list[i] as Map<String, dynamic>),
                    )
                  : _buildHistoryListView(scrollCtrl)),
        ),
      ],
    );
  }

  Widget _buildHistoryListView(ScrollController scrollCtrl) {
    final selectivos = _history
        .where(SelectivoHelpers.isSelectivoRequest)
        .toList();
    final actives = _history
        .where((r) =>
            !SelectivoHelpers.isSelectivoRequest(r) && _toMood(r['mood']) == 1)
        .toList();
    final inactives = _history
        .where((r) =>
            !SelectivoHelpers.isSelectivoRequest(r) && _toMood(r['mood']) > 1)
        .toList();

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        if (selectivos.isNotEmpty) ...[
          ...selectivos.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildRequestCard(r as Map<String, dynamic>),
          )),
        ],
        if (selectivos.isNotEmpty && actives.isNotEmpty)
          const SizedBox(height: 14),
        if (actives.isNotEmpty) ...[
          _buildGroupHeader(
            'Activas',
            'Estos equipos pueden agregar al jugador a su roster en cualquier momento.',
          ),
          const SizedBox(height: 16),
          ...actives.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildRequestCard(r as Map<String, dynamic>),
          )),
        ],
        if (actives.isNotEmpty && inactives.isNotEmpty) 
          const SizedBox(height: 24),
        if (inactives.isNotEmpty) ...[
          _buildGroupHeader(
            'Inactivas',
            'Los equipos relacionados a estas solicitudes no pueden agregarte más a sus roster, puedes reactivar una solicitud que tú mismo hayas cancelado.',
          ),
          const SizedBox(height: 16),
          ...inactives.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildRequestCard(r as Map<String, dynamic>),
          )),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.oswald(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white54,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _segmentBtn(String label, int idx) {
    final active = _segment == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _segment = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppTheme.navySurface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppTheme.brandTeal.withAlpha(50) : Colors.transparent,
            ),
            boxShadow: active
                ? [BoxShadow(color: AppTheme.brandTeal.withAlpha(20), blurRadius: 8)]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800,
              color: active ? AppTheme.brandTeal : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectivoRequestCard(Map<String, dynamic> r) {
    String textOf(dynamic value) {
      final s = value?.toString().trim() ?? '';
      if (s.isEmpty || s.toLowerCase() == 'null') return '';
      return s;
    }

    Widget circleLogo(String url, {double size = 40}) {
      return ClipOval(
        child: url.isNotEmpty
            ? Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _logoPlaceholder44(),
              )
            : _logoPlaceholder44(),
      );
    }

    final candidate = SelectivoHelpers.asMap(r['candidate']) ?? r;
    final call = SelectivoHelpers.asMap(candidate['selectionCall']) ??
        SelectivoHelpers.asMap(r['selectionCall']) ??
        <String, dynamic>{};
    final league = SelectivoHelpers.asMap(candidate['league']) ?? <String, dynamic>{};
    final academy = SelectivoHelpers.asMap(candidate['academy']) ??
        SelectivoHelpers.asMap(r['academy']) ??
        <String, dynamic>{};
    final team = SelectivoHelpers.asMap(candidate['team']) ??
        SelectivoHelpers.asMap(r['team']) ??
        <String, dynamic>{};
    final player = SelectivoHelpers.asMap(candidate['player']) ??
        SelectivoHelpers.asMap(r['player']) ??
        <String, dynamic>{};
    final permissions = SelectivoHelpers.asMap(candidate['permissions']) ??
        SelectivoHelpers.asMap(r['permissions']) ??
        <String, dynamic>{};

    final leagueName = textOf(league['name']);
    final leagueLogo = textOf(league['logo']).isNotEmpty
        ? textOf(league['logo'])
        : textOf(league['thumb']);
    final callName = textOf(call['name']);
    final playerName = textOf(player['name']).isNotEmpty
        ? textOf(player['name'])
        : 'Este jugador';
    final teamName = textOf(team['name']);
    final academyName = textOf(academy['name']);
    final canRespond = permissions['canRespondConsent'] == true;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canRespond
              ? const Color(0xFFFFD600).withAlpha(70)
              : AppTheme.brandTeal.withAlpha(40),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              circleLogo(leagueLogo, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leagueName.isNotEmpty)
                      Text(
                        leagueName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (callName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        callName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$playerName fue propuesto como aspirante para este selectivo.',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
              letterSpacing: -0.2,
            ),
          ),
          if (teamName.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Equipo asignado',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white38,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              teamName,
              style: GoogleFonts.oswald(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.brandTeal,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (academyName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Propuesto por $academyName',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white38,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _openSelectivoDetails(candidate),
            child: Container(
              width: double.infinity,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withAlpha(28)),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Ver detalles y responder',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSelectivoDetails(Map<String, dynamic> candidate) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(180),
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
          child: SizedBox(
            width: math.min(size.width * 0.95, 430),
            height: size.height * 0.92,
            child: _buildSelectivoDetailsModal(candidate, ctx),
          ),
        );
      },
    );
  }

  void _mergeSelectivoCandidateData(
    Map<String, dynamic> candidate,
    Map<String, dynamic> data,
  ) {
    const knownKeys = {
      'status',
      'consent',
      'adminApproval',
      'rosterDecision',
      'statusHistory',
      'teamHistory',
      'updatedAt',
      'cycle',
    };
    data.forEach((key, value) {
      if (value == null) return;
      if (knownKeys.contains(key) || candidate.containsKey(key)) {
        candidate[key] = value;
      }
    });
  }

  void _applySelectivoConsentLocally(Map<String, dynamic> candidate) {
    final perms = Map<String, dynamic>.from(
      SelectivoHelpers.asMap(candidate['permissions']) ?? {},
    );
    perms['canRespondConsent'] = false;
    perms['canTrack'] = true;
    candidate['permissions'] = perms;

    final cid = candidate['id']?.toString();
    final idx = _requests.indexWhere((req) {
      final c = SelectivoHelpers.asMap(req['candidate']);
      return (c?['id'] ?? req['id'])?.toString() == cid;
    });
    if (idx != -1) {
      _requests[idx]['candidate'] = candidate;
      _requests[idx]['permissions'] = perms;
      if (candidate.containsKey('status')) {
        _requests[idx]['status'] = candidate['status'];
      }
      if (candidate.containsKey('consent')) {
        _requests[idx]['consent'] = candidate['consent'];
      }
    }
  }

  void _applySelectivoConsentResetLocally(Map<String, dynamic> candidate) {
    final perms = Map<String, dynamic>.from(
      SelectivoHelpers.asMap(candidate['permissions']) ?? {},
    );
    perms['canRespondConsent'] = true;
    perms['canTrack'] = true;
    candidate['permissions'] = perms;

    final cid = candidate['id']?.toString();
    final idx = _requests.indexWhere((req) {
      final c = SelectivoHelpers.asMap(req['candidate']);
      return (c?['id'] ?? req['id'])?.toString() == cid;
    });
    if (idx != -1) {
      _requests[idx]['candidate'] = candidate;
      _requests[idx]['permissions'] = perms;
      if (candidate.containsKey('status')) {
        _requests[idx]['status'] = candidate['status'];
      }
      if (candidate.containsKey('consent')) {
        _requests[idx]['consent'] = candidate['consent'];
      }
    }
  }

  Future<void> _resetSelectivoConsent({
    required Map<String, dynamic> candidate,
    required BuildContext confirmContext,
    required BuildContext detailsContext,
    required void Function(void Function()) setConfirmState,
    required void Function(bool value) setSubmitting,
  }) async {
    if (_selectivoResetInFlight) return;
    _selectivoResetInFlight = true;
    setConfirmState(() => setSubmitting(true));

    final couldRespondBefore =
        SelectivoHelpers.asMap(candidate['permissions'])?['canRespondConsent'] == true;

    try {
      final resp = await widget.api.resetSelectionCandidateConsent(
        uid: widget.userUid,
        selectionCandidateId: candidate['id']?.toString() ?? '',
      );

      if (!mounted) {
        _selectivoResetInFlight = false;
        return;
      }

      if (resp['status']?.toString() != 'success') {
        _selectivoResetInFlight = false;
        setConfirmState(() => setSubmitting(false));
        _showToast(
          resp['message']?.toString() ?? 'No se pudo cambiar la respuesta',
          isError: true,
        );
        return;
      }

      final data = SelectivoHelpers.asMap(resp['data']);
      if (data != null) {
        _mergeSelectivoCandidateData(candidate, data);
      }
      _applySelectivoConsentResetLocally(candidate);
      widget.onSelectivoConsentResetSuccess?.call(couldRespondBefore);

      if (mounted) {
        setState(() {
          _processRequests();
          _segment = 0;
        });
      }

      if (confirmContext.mounted) {
        Navigator.of(confirmContext).pop();
      }
      if (detailsContext.mounted) {
        Navigator.of(detailsContext).pop();
      }

      _selectivoResetInFlight = false;
      _showToast('Puedes responder nuevamente');
    } catch (e) {
      _selectivoResetInFlight = false;
      if (!mounted) return;
      setConfirmState(() => setSubmitting(false));
      var msg = e.toString();
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring('Exception: '.length);
      }
      _showToast(msg.isNotEmpty ? msg : 'Error de conexión', isError: true);
    }
  }

  void _openSelectivoResetConsent(
    Map<String, dynamic> candidate,
    BuildContext detailsContext,
  ) {
    showDialog<void>(
      context: context,
      builder: (confirmCtx) {
        var submitting = false;
        return StatefulBuilder(
          builder: (ctx, setConfirmState) {
            return PopScope(
              canPop: !submitting,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text(
                  'Cambiar respuesta',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                content: submitting
                    ? const SizedBox(
                        height: 72,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppTheme.brandTeal,
                            ),
                          ),
                        ),
                      )
                    : const Text(
                        'El consentimiento volverá a quedar pendiente para que puedas responder nuevamente.',
                      ),
                actions: submitting
                    ? const <Widget>[]
                    : [
                        TextButton(
                          onPressed: () => Navigator.of(confirmCtx).pop(),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (submitting) return;
                            await _resetSelectivoConsent(
                              candidate: candidate,
                              confirmContext: confirmCtx,
                              detailsContext: detailsContext,
                              setConfirmState: setConfirmState,
                              setSubmitting: (v) => submitting = v,
                            );
                          },
                          child: const Text(
                            'Cambiar respuesta',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _respondSelectivoConsent({
    required Map<String, dynamic> candidate,
    required String decision,
    required BuildContext consentContext,
    required BuildContext detailsContext,
    required void Function(void Function()) setConsentState,
    required void Function(bool value) setSubmitting,
  }) async {
    if (_selectivoConsentInFlight) return;
    _selectivoConsentInFlight = true;
    setConsentState(() => setSubmitting(true));

    final wasAbleToRespond =
        SelectivoHelpers.asMap(candidate['permissions'])?['canRespondConsent'] == true;

    try {
      final resp = await widget.api.respondSelectionCandidateConsent(
        uid: widget.userUid,
        selectionCandidateId: candidate['id']?.toString() ?? '',
        decision: decision,
      );

      if (!mounted) {
        _selectivoConsentInFlight = false;
        return;
      }

      if (resp['status']?.toString() != 'success') {
        _selectivoConsentInFlight = false;
        setConsentState(() => setSubmitting(false));
        _showToast(
          resp['message']?.toString() ?? 'No se pudo responder',
          isError: true,
        );
        return;
      }

      final data = SelectivoHelpers.asMap(resp['data']);
      if (data != null) {
        _mergeSelectivoCandidateData(candidate, data);
      }
      _applySelectivoConsentLocally(candidate);
      widget.onSelectivoConsentSuccess?.call(wasAbleToRespond);

      if (mounted) {
        setState(_processRequests);
      }

      if (consentContext.mounted) {
        Navigator.of(consentContext).pop();
      }
      if (detailsContext.mounted) {
        Navigator.of(detailsContext).pop();
      }

      _selectivoConsentInFlight = false;
      _showToast(
        decision == 'accepted' ? 'Participación autorizada' : 'Propuesta rechazada',
      );
    } catch (e) {
      _selectivoConsentInFlight = false;
      if (!mounted) return;
      setConsentState(() => setSubmitting(false));
      var msg = e.toString();
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring('Exception: '.length);
      }
      _showToast(msg.isNotEmpty ? msg : 'Error de conexión', isError: true);
    }
  }

  Future<bool> _confirmRejectSelectivoConsent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Rechazar esta propuesta?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'El jugador no continuará en este proceso de selección.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text(
              'Rechazar propuesta',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _openSelectivoConsent(
    Map<String, dynamic> candidate,
    BuildContext detailsContext,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(140),
      builder: (consentCtx) {
        var submitting = false;
        return StatefulBuilder(
          builder: (ctx, setConsentState) {
            return PopScope(
              canPop: !submitting,
              child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  color: AppTheme.navySurface,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4, right: 8),
                                child: Text(
                                  'Consentimiento de participación',
                                  style: GoogleFonts.oswald(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: submitting
                                  ? null
                                  : () => Navigator.of(consentCtx).pop(),
                              child: const SizedBox(
                                width: 32,
                                height: 32,
                                child: Icon(
                                  Icons.close,
                                  size: 20,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '¿Autorizas que el jugador continúe en este proceso de selección?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 42,
                          child: submitting
                              ? const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: AppTheme.brandTeal,
                                    ),
                                  ),
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () async {
                                          if (submitting) return;
                                          final ok =
                                              await _confirmRejectSelectivoConsent();
                                          if (!ok ||
                                              !mounted ||
                                              !consentCtx.mounted ||
                                              !detailsContext.mounted) {
                                            return;
                                          }
                                          await _respondSelectivoConsent(
                                            candidate: candidate,
                                            decision: 'rejected',
                                            consentContext: consentCtx,
                                            detailsContext: detailsContext,
                                            setConsentState: setConsentState,
                                            setSubmitting: (v) => submitting = v,
                                          );
                                        },
                                        child: Container(
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withAlpha(10),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color(0xFFEF4444).withAlpha(80),
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'Rechazar',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFEF4444),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () async {
                                          if (submitting) return;
                                          await _respondSelectivoConsent(
                                            candidate: candidate,
                                            decision: 'accepted',
                                            consentContext: consentCtx,
                                            detailsContext: detailsContext,
                                            setConsentState: setConsentState,
                                            setSubmitting: (v) => submitting = v,
                                          );
                                        },
                                        child: Container(
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: AppTheme.brandTeal,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'Autorizar',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.navyPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectivoDetailsModal(
    Map<String, dynamic> candidate,
    BuildContext dialogContext,
  ) {
    String textOf(dynamic value) {
      final s = value?.toString().trim() ?? '';
      if (s.isEmpty || s.toLowerCase() == 'null') return '';
      return s;
    }

    String joinParts(Iterable<String> parts, String sep) =>
        parts.where((p) => p.isNotEmpty).join(sep);

    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];

    String monthAbbr(int month) =>
        (month >= 1 && month <= 12) ? months[month - 1] : '';

    String friendlyDate(dynamic raw) {
      final dt = DateTime.tryParse(textOf(raw));
      if (dt == null) return '';
      return '${dt.day} ${monthAbbr(dt.month)} ${dt.year}';
    }

    String dateRange(dynamic startRaw, dynamic endRaw) {
      final start = DateTime.tryParse(textOf(startRaw));
      final end = DateTime.tryParse(textOf(endRaw));
      if (start == null && end == null) return '';
      if (start == null) return friendlyDate(endRaw);
      if (end == null) return friendlyDate(startRaw);
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        return friendlyDate(startRaw);
      }
      if (start.year == end.year) {
        return '${start.day} ${monthAbbr(start.month)} - ${end.day} ${monthAbbr(end.month)} ${end.year}';
      }
      return '${friendlyDate(startRaw)} - ${friendlyDate(endRaw)}';
    }

    String genderLabel(String gender) {
      switch (gender.toLowerCase()) {
        case 'mixta':
        case 'mixed':
          return 'MIXTA';
        case 'masculino':
        case 'male':
          return 'MASCULINO';
        case 'femenino':
        case 'female':
          return 'FEMENINO';
        default:
          return gender.toUpperCase();
      }
    }

    Widget remoteLogo(String url, {double size = 44}) {
      return ClipOval(
        child: url.isNotEmpty
            ? Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _logoPlaceholder44(),
              )
            : _logoPlaceholder44(),
      );
    }

    Widget factRow(IconData icon, String label, String value) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white38,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget darkCard({required Widget child}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2233),
          borderRadius: BorderRadius.circular(22),
        ),
        child: child,
      );
    }

    final call = SelectivoHelpers.asMap(candidate['selectionCall']) ?? <String, dynamic>{};
    final competition = SelectivoHelpers.asMap(call['targetCompetition']) ?? <String, dynamic>{};
    final league = SelectivoHelpers.asMap(candidate['league']) ?? <String, dynamic>{};
    final academy = SelectivoHelpers.asMap(candidate['academy']) ?? <String, dynamic>{};
    final team = SelectivoHelpers.asMap(candidate['team']) ?? <String, dynamic>{};
    final category = SelectivoHelpers.asMap(team['category']) ?? <String, dynamic>{};
    final ageCriteria = SelectivoHelpers.asMap(call['ageCriteria']) ?? <String, dynamic>{};
    final permissions = SelectivoHelpers.asMap(candidate['permissions']) ?? <String, dynamic>{};
    final candidateStatus = (candidate['status'] ?? '').toString();
    final canRespond = permissions['canRespondConsent'] == true;
    final canResetConsent =
        candidateStatus == 'pending_admin' || candidateStatus == 'rejected_consent';

    final cover = textOf(call['cover']);
    final callName = textOf(call['name']);
    final leagueName = textOf(league['name']);
    final leagueLogo = textOf(league['logo']).isNotEmpty
        ? textOf(league['logo'])
        : textOf(league['thumb']);
    final location = joinParts([
      textOf(competition['city']),
      textOf(competition['state']),
    ], ', ');
    final dates = dateRange(competition['start'], competition['end']);
    final cutoffDate = friendlyDate(ageCriteria['cutoffDate']);
    final teamName = textOf(team['name']);
    final categoryName = textOf(category['name']);
    final gender = genderLabel(textOf(category['gender']));
    final categoryLine = joinParts([
      if (categoryName.isNotEmpty) categoryName.toUpperCase(),
      if (gender.isNotEmpty) gender,
    ], ' ');
    final academyName = textOf(academy['name']);
    final academyLogo = textOf(academy['logo']).isNotEmpty
        ? textOf(academy['logo'])
        : textOf(academy['thumb']);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Material(
        color: const Color(0xFF121621),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Detalle de solicitud',
                      style: GoogleFonts.oswald(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: Colors.white38),
                  SizedBox(width: 8),
                  Text(
                    'PENDIENTE DE CONSENTIMIENTO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white38,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: 168,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (cover.isNotEmpty)
                              ImageFiltered(
                                imageFilter: ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
                                child: Image.network(
                                  cover,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) =>
                                      Container(color: AppTheme.navyElevated),
                                ),
                              )
                            else
                              Container(color: AppTheme.navyElevated),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x66000000),
                                    Color(0xCC121621),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (leagueName.isNotEmpty || leagueLogo.isNotEmpty)
                                    Row(
                                      children: [
                                        remoteLogo(leagueLogo, size: 22),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            leagueName.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF9BE7FF),
                                              letterSpacing: 1.3,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (callName.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      callName,
                                      style: GoogleFonts.oswald(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        height: 1.05,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (location.isNotEmpty || dates.isNotEmpty || cutoffDate.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      darkCard(
                        child: Column(
                          children: [
                            if (location.isNotEmpty)
                              factRow(Icons.location_on_outlined, 'Sede', location),
                            if (location.isNotEmpty && (dates.isNotEmpty || cutoffDate.isNotEmpty))
                              const SizedBox(height: 16),
                            if (dates.isNotEmpty)
                              factRow(Icons.calendar_today_outlined, 'Fechas', dates),
                            if (dates.isNotEmpty && cutoffDate.isNotEmpty)
                              const SizedBox(height: 16),
                            if (cutoffDate.isNotEmpty)
                              factRow(Icons.person_outline_rounded, 'Edad de corte', cutoffDate),
                          ],
                        ),
                      ),
                    ],
                    if (teamName.isNotEmpty || categoryLine.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D4AFF),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -6,
                              bottom: -18,
                              child: Icon(
                                Icons.sports_football_rounded,
                                size: 86,
                                color: Colors.white.withAlpha(40),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (categoryLine.isNotEmpty)
                                  Text(
                                    'CATEGORÍA: $categoryLine',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white70,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                if (teamName.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    teamName.toUpperCase(),
                                    style: GoogleFonts.oswald(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.05,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (academyName.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      darkCard(
                        child: Row(
                          children: [
                            remoteLogo(academyLogo, size: 44),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ACADEMIA ORIGEN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white38,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    academyName.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFE8A07C)),
                        SizedBox(width: 8),
                        Text(
                          'INFORMACIÓN IMPORTANTE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE8A07C),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'La academia propuso al jugador como aspirante a este equipo selectivo. Tu autorización permite que continúe en el proceso, pero no garantiza un lugar definitivo. El jugador deberá cumplir los requisitos de la convocatoria, ser aprobado por los organizadores y completar el proceso de selección.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        height: 1.45,
                      ),
                    ),
                    if (canRespond) ...[
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () => _openSelectivoConsent(candidate, dialogContext),
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.brandTeal,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Responder',
                            style: GoogleFonts.oswald(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.navyPrimary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (canResetConsent) ...[
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () => _openSelectivoResetConsent(candidate, dialogContext),
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(10),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withAlpha(28)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Cambiar mi respuesta',
                            style: GoogleFonts.oswald(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> r) {
    if (SelectivoHelpers.isSelectivoRequest(r)) {
      return _buildSelectivoRequestCard(r);
    }
    final mood = _toMood(r['mood']);
    final idx = mood.clamp(0, _moodNames.length - 1);
    final academyName = (r['academy']?['name'] ?? 'Academia').toString();
    final academyLogo = (r['academy']?['thumb'] ?? r['academy']?['logo'] ?? '').toString();
    final teamName = (r['team']?['name'] ?? r['teamName'] ?? '').toString();
    final origin = (r['origin'] ?? '').toString();
    final dateRaw = (r['date'] ?? '').toString();
    final isLoading = _isLoading(r);

    // Ya no se usan los colores de status porque se elimina el badge


    String dateLabel = '';
    if (dateRaw.isNotEmpty) {
      try {
        final dt = DateTime.parse(dateRaw).toLocal();
        const months = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
        dateLabel = '${dt.day} ${months[dt.month - 1]}, ${dt.year}';
      } catch (_) { dateLabel = dateRaw; }
    }

    // mood = 2 (Rechazado por destino)
    // mood = 3 (Cancelado por origen)
    final bool isAcademyRejection = (origin == 'player' && mood == 2) || (origin == 'academy' && mood == 3);
    final bool isPlayerRejection  = (origin == 'player' && mood == 3) || (origin == 'academy' && mood == 2);

    final bool isInactive = mood > 1;

    Widget cardContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isInactive ? Colors.transparent : AppTheme.navySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(isInactive ? 30 : 15), width: 1.5),
        boxShadow: isInactive ? [] : const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row principal: Logo + Info + Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(20), width: 1.5),
                ),
                child: ClipOval(
                  child: isInactive 
                      ? ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0,      0,      0,      1, 0,
                          ]),
                          child: academyLogo.isNotEmpty
                              ? Image.network(academyLogo, width: 44, height: 44, fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => _logoPlaceholder44())
                              : _logoPlaceholder44(),
                        )
                      : (academyLogo.isNotEmpty
                          ? Image.network(academyLogo, width: 44, height: 44, fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => _logoPlaceholder44())
                          : _logoPlaceholder44()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['type'] == 'co_tutor' ? (r['requesterName'] ?? 'Tutor secundario') : academyName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isInactive ? Colors.white54 : Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r['type'] == 'co_tutor' 
                                ? 'Co-Tutor' 
                                : (teamName.isNotEmpty ? teamName : (origin == 'player' ? 'Enviada por ti' : 'Invitación')),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (dateLabel.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text('•', style: TextStyle(color: Colors.white24, fontSize: 10)),
                          ),
                          Text(
                            dateLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (!isLoading) ...[
            const SizedBox(height: 14),
            if (mood == 0) ...[
              if (r['type'] == 'co_tutor') ...[
                // Co-Tutor Request pending
                _infoBox(
                  icon: Icons.person_add_alt_1_rounded,
                  text: 'Solicitud de co-tutoría. Quiere gestionar el perfil.',
                  color: const Color(0xFF3B82F6),
                  bg: const Color(0xFF3B82F6).withAlpha(20),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _appleBtn('Aceptar', AppTheme.brandTeal, AppTheme.navyPrimary, () => _acceptCoTutorRequest(r)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _appleBtnOutline('Rechazar', const Color(0xFFEF4444), () => _rejectCoTutorRequest(r)),
                    ),
                  ],
                ),
              ] else if (origin == 'player') ...[
                // Solicitud en espera
                Row(
                  children: [
                    Expanded(
                      child: _infoBox(
                        icon: Icons.hourglass_top_rounded,
                        text: 'En espera de resolución.',
                        color: const Color(0xFFFFD600),
                        bg: const Color(0xFFFFD600).withAlpha(20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () => _updateMood(r, 3),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _deleteRequestPlayer(r),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Eliminar',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                // Invita la academia
                Row(
                  children: [
                    Expanded(
                      child: _appleBtn('Aceptar', AppTheme.brandTeal, AppTheme.navyPrimary, () => _acceptRequest(r)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _appleBtnOutline('Rechazar', const Color(0xFFEF4444), () => _rejectRequest(r)),
                    ),
                  ],
                ),
              ],
            ] else if (mood == 1) ...[
              // Aceptado
              Row(
                children: [
                  Expanded(
                    child: _infoBox(
                      icon: Icons.check_circle_rounded,
                      text: r['type'] == 'co_tutor' ? 'Co-Tutoría aprobada.' : 'Eres parte del equipo.',
                      color: AppTheme.brandTeal,
                      bg: AppTheme.brandTeal.withAlpha(20),
                    ),
                  ),
                  if (r['type'] != 'co_tutor') ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _confirmCancelAccepted(r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.w700, 
                            color: const Color(0xFFEF4444).withOpacity(0.9),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ] else if (r['type'] == 'co_tutor') ...[
              // Rechazado Co-Tutor
              Row(
                children: [
                  Expanded(
                    child: _infoBox(
                      icon: Icons.block_flipped,
                      text: 'Co-Tutoría rechazada',
                      color: Colors.white54,
                      bg: Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _resumeCoTutorRequest(r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Reactivar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (isAcademyRejection) ...[
              // Rechazado o cancelado por la academia
              Row(
                children: [
                  Expanded(
                    child: _infoBox(
                      icon: Icons.block_flipped,
                      text: mood == 2 ? 'Solicitud declinada' : 'Invitación cancelada',
                      color: Colors.white54,
                      bg: Colors.transparent,
                    ),
                  ),
                  if (origin == 'player') ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deleteRequestPlayer(r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 12, color: Color(0xFFEF4444)),
                            SizedBox(width: 4),
                            Text(
                              'Eliminar',
                              style: TextStyle(
                                fontSize: 11, 
                                fontWeight: FontWeight.w700, 
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ] else if (isPlayerRejection) ...[
              // Rechazado o cancelado por el jugador
              Row(
                children: [
                  Expanded(
                    child: _infoBox(
                      icon: Icons.close_rounded,
                      text: mood == 3 ? 'Cancelada.' : 'Declinada.',
                      color: Colors.white54,
                      bg: Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (origin == 'player') ...[
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () => _resendRequest(r),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Reactivar',
                                  style: TextStyle(
                                    fontSize: 10, 
                                    fontWeight: FontWeight.w700, 
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _deleteRequestPlayer(r),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 12, color: Color(0xFFEF4444)),
                                SizedBox(width: 4),
                                Text(
                                  'Eliminar',
                                  style: TextStyle(
                                    fontSize: 10, 
                                    fontWeight: FontWeight.w700, 
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    GestureDetector(
                      onTap: () => _resendRequest(r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Reactivar',
                              style: TextStyle(
                                fontSize: 11, 
                                fontWeight: FontWeight.w700, 
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ] else ...[
            const SizedBox(height: 20),
            const Center(
              child: SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF71717A))),
            ),
          ],
        ],
      ),
    );

    return cardContent;
  }

  Widget _infoBox({required IconData icon, required String text, String? desc, required Color color, required Color bg}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(20)),
      ),
      child: Row(
        crossAxisAlignment: desc != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (desc != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white54,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appleBtn(String label, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _appleBtnOutline(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80), width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoPlaceholder44() {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15), shape: BoxShape.circle,
      ),
      child: const Icon(Icons.shield_outlined, color: Colors.white38, size: 20),
    );
  }
  Widget _logoPlaceholder({double size = 56}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.navyElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.shield_outlined, color: Colors.white24, size: size * 0.45),
    );
  }

  String _playerDisplayName() {
    final pd = widget.playerData;
    final parts = [
      pd['name'],
      pd['apellidoPa'],
      pd['apellidoMa'],
    ].map((v) => v?.toString().trim() ?? '').where((s) => s.isNotEmpty);
    final full = parts.join(' ');
    if (full.isNotEmpty) return full;
    final fallback = (pd['userName'] ?? pd['alias'] ?? 'Jugador').toString().trim();
    return fallback.isNotEmpty ? fallback : 'Jugador';
  }

  int _playerAge() {
    final bd = widget.playerData['bd']?.toString();
    if (bd == null || bd.isEmpty) return 0;
    final dob = DateTime.tryParse(bd);
    if (dob == null) return 0;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age > 0 ? age : 0;
  }

  Widget _buildPlayerRequestContext() {
    final pd = widget.playerData;
    final thumb = (pd['thumb'] ?? pd['photo'] ?? '').toString();
    final name = _playerDisplayName();
    final age = _playerAge();
    final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Solicitud para',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white38,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: thumb.isNotEmpty
                    ? Image.network(
                        thumb,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => _playerAvatarFallback(initial),
                      )
                    : _playerAvatarFallback(initial),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (age > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$age años',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _playerAvatarFallback(String initial) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.navyElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.brandTeal.withAlpha(40)),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.oswald(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppTheme.brandTeal,
        ),
      ),
    );
  }

  // ── Search view ────────────────────────────────────────────────────────────

  Widget _buildSearchView(ScrollController scrollCtrl) {
    return Column(
      key: const ValueKey('search-view'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSearchTypeSelector(),
        ),
        const SizedBox(height: 12),

        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.navySurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(15)),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white),
              decoration: InputDecoration(
                hintText: _searchType == 'name'
                    ? 'Buscar academia por nombre'
                    : 'Ingresa la clave de la academia',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandTeal),
                        ),
                      )
                    : const Icon(Icons.search_rounded, color: Colors.white54),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white54),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() { _searchResults = []; _searchError = ''; });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Error
        if (_searchError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _searchError,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Empty hint
        if (_searchResults.isEmpty && !_isSearching && _searchCtrl.text.length < 3)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_rounded, size: 40, color: Colors.white24),
                  const SizedBox(height: 8),
                  Text(
                    'Escribe al menos 3 caracteres',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Sin resultados
        if (_searchResults.isEmpty &&
            !_isSearching &&
            _searchCtrl.text.length >= 3 &&
            _searchError.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school_outlined, size: 40, color: Colors.white24),
                  const SizedBox(height: 8),
                  Text(
                    'Sin resultados para "${_searchCtrl.text}"',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white38,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

        // Results
        if (_searchResults.isNotEmpty)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(
                    _searchResults.length == 1
                        ? '1 academia encontrada'
                        : '${_searchResults.length} academias encontradas',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      24 + MediaQuery.of(context).padding.bottom,
                    ),
                    itemCount: _searchResults.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _buildAcademyCard(_searchResults[i]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSearchTypeSelector() {
    const types = [('Por nombre', 'name'), ('Por clave', 'clave')];
    final activeIndex = _searchType == 'name' ? 0 : 1;
    final alignmentX = activeIndex == 0 ? -1.0 : 1.0;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment(alignmentX, 0),
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.brandTeal,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brandTeal.withAlpha(60),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: types.map((entry) {
              final isActive = _searchType == entry.$2;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _searchType = entry.$2;
                      _searchResults = [];
                      _searchCtrl.clear();
                    });
                  },
                  child: Center(
                    child: Text(
                      entry.$1,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isActive ? AppTheme.navyPrimary : Colors.white54,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _academyPublicKey(dynamic academy) {
    if (academy is! Map) return '';
    final map = Map<String, dynamic>.from(academy);
    return (map['public_key'] ?? map['clave'] ?? '').toString().trim();
  }

  String _academyAdministratorName(dynamic academy) {
    if (academy is! Map) return '';
    final map = Map<String, dynamic>.from(academy);
    return (map['administrator_name'] ?? map['administratorName'] ?? '').toString().trim();
  }

  List<String> _academyCategoryLabels(dynamic academy) {
    if (academy is! Map) return [];
    final raw = academy['categories'];
    if (raw == null) return [];

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return [];
      return trimmed.split(RegExp(r'[,;|]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }

    if (raw is List) {
      return raw
          .map((c) {
            if (c is Map) {
              return (c['name'] ?? c['label'] ?? c['title'] ?? '').toString().trim();
            }
            return c.toString().trim();
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final asString = raw.toString().trim();
    return asString.isEmpty ? [] : [asString];
  }

  Widget _buildAcademyCard(dynamic academy) {
    const logoSize = 56.0;
    final academyId = (academy['id'] ?? academy['_id'] ?? '').toString();
    final name = (academy['name'] ?? 'Academia').toString().trim();
    final logo = (academy['logo_url'] ?? academy['logo'] ?? '').toString().trim();
    final location = (academy['location'] ?? '').toString().trim();
    final publicKey = _academyPublicKey(academy);
    final administratorName = _academyAdministratorName(academy);
    final categoryLabels = _academyCategoryLabels(academy);
    final existing = academy['existingRequest'] as Map<String, dynamic>?;
    final hasAnyRequest = existing != null && existing.isNotEmpty;
    final mood = hasAnyRequest ? _toMood(existing!['mood']) : -1;
    final hasPending = hasAnyRequest && mood == 0;
    final isAccepted = hasAnyRequest && mood == 1;
    final isRejected = hasAnyRequest && (mood == 2 || mood == 3);
    final isSending = _sendingAcademyId != null && _sendingAcademyId == academyId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(15), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: logo.isNotEmpty
                    ? Image.network(
                        logo,
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => _logoPlaceholder(size: logoSize),
                      )
                    : _logoPlaceholder(size: logoSize),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (administratorName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        administratorName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white38,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (categoryLabels.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: categoryLabels.map((label) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withAlpha(20)),
                            ),
                            child: Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white60,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (publicKey.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Clave: $publicKey',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white38,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasPending)
            _buildAcademySentState()
          else if (isAccepted)
            _academyStatusChip(
              label: 'Ya eres parte de esta academia',
              icon: Icons.check_circle_rounded,
              color: AppTheme.brandTeal,
            )
          else if (isRejected)
            GestureDetector(
              onTap: isSending ? null : () => _resendExisting(existing!),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(30)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Reenviar solicitud',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (!hasAnyRequest)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: isSending ? null : () => _sendRequest(academy),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSending
                          ? AppTheme.brandTeal.withAlpha(140)
                          : AppTheme.brandTeal,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSending
                          ? null
                          : [
                              BoxShadow(
                                color: AppTheme.brandTeal.withAlpha(80),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSending)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.navyPrimary,
                            ),
                          )
                        else ...[
                          Icon(Icons.send_rounded, size: 16, color: AppTheme.navyPrimary),
                          const SizedBox(width: 8),
                          Text(
                            'Solicitar ingreso',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navyPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'La academia deberá revisar y aprobar la solicitud.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAcademySentState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD600).withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD600).withAlpha(45)),
      ),
      child: Column(
        children: [
          Text(
            'Solicitud enviada',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFFD600),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Esperando respuesta de la academia.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _academyStatusChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _PulseDot — animated yellow dot for pending requests
// =============================================================================
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.active, this.color = AppTheme.brandTeal});
  final bool active;
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.75, end: 1.25).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
        width: 10, height: 10,
        decoration: const BoxDecoration(color: Color(0xFF3F3F46), shape: BoxShape.circle),
      );
    }
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color.withAlpha(100), blurRadius: 8, spreadRadius: 2)],
        ),
      ),
    );
  }
}

// =============================================================================
// _SendRequestSheet — bottom sheet para enviar solicitud a un equipo
// =============================================================================
class _SendRequestSheet extends StatefulWidget {
  const _SendRequestSheet({
    required this.api,
    required this.playerId,
    required this.userId,
    required this.onSent,
  });

  final ApiService api;
  final String playerId;
  final String userId;
  final Future<void> Function() onSent;

  @override
  State<_SendRequestSheet> createState() => _SendRequestSheetState();
}

class _SendRequestSheetState extends State<_SendRequestSheet> {
  static const _brandAqua = AppTheme.brandTeal;
  static const _appBg = AppTheme.navyPrimary;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  List<dynamic> _results = [];
  bool _isSearching = false;
  bool _isSending = false;
  String _error = '';
  dynamic _selected; // equipo seleccionado pendiente de confirmar

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() { _results = []; _error = ''; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _runSearch(query.trim()));
  }

  Future<void> _runSearch(String query) async {
    setState(() { _isSearching = true; _error = ''; });
    try {
      final results = await widget.api.searchTeams(query);
      if (!mounted) return;
      setState(() { _results = results; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'No se pudo buscar. Intenta de nuevo.'; });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _send() async {
    if (_selected == null) return;
    final teamId = (_selected['_id'] ?? _selected['id'] ?? '').toString();
    if (teamId.isEmpty) return;

    setState(() { _isSending = true; _error = ''; });
    try {
      await widget.api.sendTeamRequest(
        playerId: widget.playerId,
        teamId: teamId,
        userId: widget.userId,
      );
      if (!mounted) return;
      await widget.onSent();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isSending = false;
        _selected = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _appBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'UNIRME A EQUIPO',
                    style: GoogleFonts.oswald(
                      fontSize: 26, fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textPrimary, letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Buscar academia o equipo...',
                    hintStyle: const TextStyle(color: Color(0xFFD4D4D8), fontWeight: FontWeight.w500),
                    prefixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF71717A)),
                            ),
                          )
                        : const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF9CA3AF)),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() { _results = []; _error = ''; _selected = null; });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Error message
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444).withAlpha(50)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                      ),
                    ],
                  ),
                ),
              ),

            // Empty hint
            if (_results.isEmpty && !_isSearching && _searchCtrl.text.length < 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const Icon(Icons.search_rounded, size: 40, color: Color(0xFFD4D4D8)),
                    const SizedBox(height: 8),
                    Text('Escribe el nombre del equipo o academia',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

            // No results
            if (_results.isEmpty && !_isSearching && _searchCtrl.text.length >= 2 && _error.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const Icon(Icons.shield_outlined, size: 40, color: Color(0xFFD4D4D8)),
                    const SizedBox(height: 8),
                    Text('Sin resultados para "${_searchCtrl.text}"',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

            // Results list
            if (_results.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.38,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _results.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final team = _results[i];
                    final name = (team['name'] ?? 'Equipo').toString();
                    final academyName = (team['academy']?['name'] ?? team['academyName'] ?? '').toString();
                    final logo = (team['logo'] ?? team['academy']?['logo'] ?? '').toString();
                    final isSelected = _selected == team;

                    return GestureDetector(
                      onTap: () => setState(() => _selected = isSelected ? null : team),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? Colors.black : const Color(0xFFF4F4F5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? const Color(0x33000000)
                                  : const Color(0x08000000),
                              blurRadius: 12, offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Logo
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: logo.isNotEmpty
                                  ? Image.network(logo, width: 44, height: 44, fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => _searchLogoPlaceholder(isSelected))
                                  : _searchLogoPlaceholder(isSelected),
                            ),
                            const SizedBox(width: 12),

                            // Name + academy
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.toUpperCase(),
                                    style: GoogleFonts.oswald(
                                      fontSize: 16, fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : Colors.black,
                                    ),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                  if (academyName.isNotEmpty)
                                    Text(
                                      academyName,
                                      style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white.withAlpha(160)
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Check indicator
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isSelected ? 1.0 : 0.0,
                              child: Container(
                                width: 26, height: 26,
                                decoration: const BoxDecoration(
                                  color: _brandAqua, shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded, size: 14, color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Send button (visible only when a team is selected)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _selected != null
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: GestureDetector(
                  onTap: _isSending ? null : _send,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      color: _brandAqua,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Color(0x44FFDE00), blurRadius: 20, offset: Offset(0, 8)),
                      ],
                    ),
                    child: _isSending
                        ? const Center(
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                            ),
                          )
                        : Text(
                            'ENVIAR SOLICITUD',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.2,
                              color: AppTheme.navyPrimary,
                            ),
                          ),
                  ),
                ),
              ),
              secondChild: const SizedBox(width: double.infinity, height: 0),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _searchLogoPlaceholder(bool dark) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: dark ? Colors.white.withAlpha(20) : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.shield_outlined,
          size: 20,
          color: dark ? Colors.white30 : const Color(0xFFD4D4D8)),
    );
  }

}

// ============================================================================
// HUD RADAR CHART
// ============================================================================

class RadarChartHUD extends StatefulWidget {
  const RadarChartHUD({
    super.key,
    required this.pass,
    required this.rec,
    required this.sck,
    required this.run,
    required this.intc,
    required this.archetype,
  });

  final double pass;
  final double rec;
  final double sck;
  final double run;
  final double intc;
  final String archetype;

  @override
  State<RadarChartHUD> createState() => _RadarChartHUDState();
}

class _RadarChartHUDState extends State<RadarChartHUD> with TickerProviderStateMixin {
  late AnimationController _buildCtrl;
  late Animation<double> _buildAnim;
  late AnimationController _scanCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const _aqua = Color(0xFF3BD0AE);

  IconData _archetypeIcon(String arch) {
    switch (arch) {
      case 'FRANCOTIRADOR': return Icons.gps_fixed;
      case 'RECEPTOR LETAL': return Icons.offline_bolt;
      case 'CAZADOR': return Icons.security;
      case 'SPEEDSTER': return Icons.bolt;
      case 'TODOTERRENO': return Icons.dashboard_customize;
      default: return Icons.sports_football;
    }
  }

  @override
  void initState() {
    super.initState();

    _buildCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _buildAnim = CurvedAnimation(parent: _buildCtrl, curve: Curves.easeOutCubic);
    _buildCtrl.forward();

    _scanCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _scanCtrl.repeat();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _pulseCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _buildCtrl.dispose();
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vals = {
      'PAS': widget.pass,
      'REC': widget.rec,
      'SCK': widget.sck,
      'RUN': widget.run,
      'INT': widget.intc,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _aqua.withAlpha(45)),
        boxShadow: [
          BoxShadow(color: _aqua.withAlpha(18), blurRadius: 30, spreadRadius: -4),
          const BoxShadow(color: Color(0xAA000000), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Título superior ──
          Row(
            children: [
              Expanded(child: Divider(color: _aqua.withAlpha(55), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '[ ANÁLISIS DE COMBATE ]',
                  style: GoogleFonts.oswald(
                    color: _aqua.withAlpha(170),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Expanded(child: Divider(color: _aqua.withAlpha(55), thickness: 1)),
            ],
          ),
          const SizedBox(height: 14),

          // ── Arquetipo + Live indicator ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _aqua.withAlpha(22),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _aqua.withAlpha(80)),
                    ),
                    child: Icon(_archetypeIcon(widget.archetype), color: _aqua, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ARQUETIPO',
                        style: TextStyle(
                          color: Colors.white.withAlpha(60),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                      Text(
                        widget.archetype,
                        style: GoogleFonts.oswald(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: _aqua,
                          letterSpacing: 0.5,
                          shadows: [Shadow(color: _aqua.withAlpha(120), blurRadius: 8)],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Indicador LIVE SCAN
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _aqua.withAlpha((120 + 135 * _pulseAnim.value).toInt()),
                        boxShadow: [BoxShadow(color: _aqua.withAlpha(110), blurRadius: 6 + 4 * _pulseAnim.value)],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE SCAN',
                      style: TextStyle(
                        color: _aqua.withAlpha(170),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Radar ──
          SizedBox(
            height: 240,
            child: AnimatedBuilder(
              animation: Listenable.merge([_buildAnim, _scanCtrl, _pulseAnim]),
              builder: (ctx, child) {
                return CustomPaint(
                  painter: _RadarPainter(
                    pass: widget.pass * _buildAnim.value,
                    rec: widget.rec * _buildAnim.value,
                    sck: widget.sck * _buildAnim.value,
                    run: widget.run * _buildAnim.value,
                    intc: widget.intc * _buildAnim.value,
                    scanProgress: _scanCtrl.value,
                    pulseValue: _pulseAnim.value,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // ── Mini stat bars ──
          AnimatedBuilder(
            animation: _buildAnim,
            builder: (_, __) {
              return Column(
                children: vals.entries.map((e) {
                  final pct = e.value.clamp(0.0, 1.0);
                  final Color barColor = pct >= 0.6
                      ? _aqua
                      : pct >= 0.3
                          ? const Color(0xFFFFB547)
                          : const Color(0xFFFF3366);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            e.key,
                            style: TextStyle(
                              color: Colors.white.withAlpha(120),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(12),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: (pct * _buildAnim.value).clamp(0.0, 1.0),
                                child: Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    gradient: LinearGradient(
                                      colors: [barColor.withAlpha(160), barColor],
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: barColor.withAlpha(110), blurRadius: 6),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '${(pct * 100).toInt()}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: barColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 14),

          // ── Footer divider ──
          Row(
            children: [
              Expanded(child: Divider(color: _aqua.withAlpha(38), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('◆', style: TextStyle(color: _aqua.withAlpha(90), fontSize: 8)),
              ),
              Expanded(child: Divider(color: _aqua.withAlpha(38), thickness: 1)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ACORDEON DE TORNEO CON TABS DE CATEGORIA
// ============================================================================
class _TournamentHistoryAccordion extends StatefulWidget {
  const _TournamentHistoryAccordion({Key? key, required this.torneo, required this.buildLogItem}) : super(key: key);

  final Map<String, dynamic> torneo;
  final Widget Function(dynamic matchMap, {required bool isLast}) buildLogItem;

  @override
  State<_TournamentHistoryAccordion> createState() => _TournamentHistoryAccordionState();
}

class _TournamentHistoryAccordionState extends State<_TournamentHistoryAccordion> {
  String? activeCategory;

  @override
  Widget build(BuildContext context) {
    final items = widget.torneo['matches'] as List<dynamic>? ?? [];
    
    // Extract unique categories
    final categories = <String>{};
    for (var item in items) {
       final cat = (item['categoryName'] ?? '').toString();
       if (cat.isNotEmpty) categories.add(cat);
    }
    final sortedCats = categories.toList()..sort();
    
    if (activeCategory == null && sortedCats.isNotEmpty) {
      activeCategory = sortedCats.first;
    }
    
    // Filter items
    final filteredItems = sortedCats.isEmpty 
        ? items 
        : items.where((m) => (m['categoryName'] ?? '').toString() == activeCategory).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1320),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.brandTeal.withAlpha(50)),
          boxShadow: [
            BoxShadow(color: AppTheme.brandTeal.withAlpha(15), blurRadius: 16, offset: const Offset(0, 8))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ExpansionTile(
            iconColor: AppTheme.brandTeal,
            collapsedIconColor: Colors.white54,
            title: Text(
              (widget.torneo['tournamentName'] ?? 'Torneo').toString().toUpperCase(),
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            subtitle: Text(
              '${items.length} PARTIDOS TOTALES',
              style: const TextStyle(
                color: AppTheme.brandTeal,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            children: [
              Container(
                color: const Color(0xFF0F172A),
                width: double.infinity,
                child: Column(
                  children: [
                    if (sortedCats.length > 1) 
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: CupertinoSlidingSegmentedControl<String>(
                            backgroundColor: const Color(0xFF0B1320),
                            thumbColor: const Color(0xFF3BD0AE).withAlpha(40),
                            groupValue: activeCategory,
                            onValueChanged: (val) {
                              if (val != null) setState(() => activeCategory = val);
                            },
                            children: {
                              for (var c in sortedCats) 
                                 c: Padding(
                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                   child: Text(
                                     c.toUpperCase(), 
                                     style: TextStyle(
                                       color: activeCategory == c ? const Color(0xFF3BD0AE) : Colors.white54, 
                                       fontSize: 11, 
                                       fontWeight: FontWeight.bold
                                     ),
                                   ),
                                 )
                            },
                          ),
                        ),
                      ),
                    if (filteredItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text("No hay cruces en esta categoría.", style: TextStyle(color: Colors.white54)),
                      )
                    else
                      ...filteredItems.asMap().entries.map((e) => widget.buildLogItem(e.value, isLast: e.key == filteredItems.length - 1)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.pass,
    required this.rec,
    required this.sck,
    required this.run,
    required this.intc,
    required this.scanProgress,
    required this.pulseValue,
  });

  final double pass;
  final double rec;
  final double sck;
  final double run;
  final double intc;
  final double scanProgress;
  final double pulseValue;

  static const _aqua = Color(0xFF3BD0AE);
  static const _pi = math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width < size.height ? size.width : size.height) / 2 - 26;
    const int sides = 5;
    final double angleStep = (2 * _pi) / sides;
    const double rotOff = -_pi / 2;

    // ── 1. Dot grid background ──────────────────────────────────
    final dotPaint = Paint()..color = _aqua.withAlpha(14);
    const dotSpacing = 14.0;
    for (double dx = 0; dx < size.width; dx += dotSpacing) {
      for (double dy = 0; dy < size.height; dy += dotSpacing) {
        canvas.drawCircle(Offset(dx, dy), 0.9, dotPaint);
      }
    }

    // ── 2. Grid rings (dashed pentagons) ────────────────────────
    for (int step = 1; step <= 4; step++) {
      final stepRadius = radius * step / 4;
      final color = step == 4
          ? _aqua.withAlpha(55)
          : Colors.white.withAlpha(14);
      _drawDashedPentagon(canvas, center, stepRadius, sides, angleStep, rotOff, color, step == 4 ? 1.2 : 0.8);
    }

    // ── 3. Axes ─────────────────────────────────────────────────
    final axisPaint = Paint()
      ..color = _aqua.withAlpha(22)
      ..strokeWidth = 1;
    for (int i = 0; i < sides; i++) {
      final x = center.dx + radius * math.cos(angleStep * i + rotOff);
      final y = center.dy + radius * math.sin(angleStep * i + rotOff);
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }

    // ── 4. Scan sweep ───────────────────────────────────────────
    final scanAngle = rotOff + (2 * _pi * scanProgress);
    const sweepArc = 0.7;
    final scanRect = Rect.fromCircle(center: center, radius: radius);
    final scanPaint = Paint()
      ..shader = SweepGradient(
        startAngle: scanAngle - sweepArc,
        endAngle: scanAngle,
        colors: [Colors.transparent, _aqua.withAlpha(35)],
        tileMode: TileMode.clamp,
      ).createShader(scanRect)
      ..style = PaintingStyle.fill;
    final scanPath = Path()..moveTo(center.dx, center.dy);
    const steps = 24;
    for (int i = 0; i <= steps; i++) {
      final a = (scanAngle - sweepArc) + sweepArc * i / steps;
      scanPath.lineTo(center.dx + radius * math.cos(a), center.dy + radius * math.sin(a));
    }
    scanPath.close();
    canvas.drawPath(scanPath, scanPaint);
    // Scan line edge
    canvas.drawLine(
      center,
      Offset(center.dx + radius * math.cos(scanAngle), center.dy + radius * math.sin(scanAngle)),
      Paint()..color = _aqua.withAlpha(90)..strokeWidth = 1.2,
    );

    // ── 5. Data polygon ─────────────────────────────────────────
    final vals = [intc, rec, sck, run, pass];
    final dataPath = Path();
    final points = <Offset>[];
    for (int i = 0; i < sides; i++) {
      final v = vals[i].clamp(0.0, 1.0);
      final r = radius * v;
      final x = center.dx + r * math.cos(angleStep * i + rotOff);
      final y = center.dy + r * math.sin(angleStep * i + rotOff);
      points.add(Offset(x, y));
      if (i == 0) dataPath.moveTo(x, y); else dataPath.lineTo(x, y);
    }
    dataPath.close();

    // Radial gradient fill
    canvas.drawPath(
      dataPath,
      Paint()
        ..shader = RadialGradient(
          colors: [_aqua.withAlpha(110), _aqua.withAlpha(22)],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill,
    );

    // Glow strokes (outer → inner)
    for (final g in [
      (w: 10.0, a: 18),
      (w: 6.0, a: 40),
      (w: 3.5, a: 90),
      (w: 1.5, a: 230),
    ]) {
      canvas.drawPath(
        dataPath,
        Paint()
          ..color = _aqua.withAlpha(g.a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = g.w
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // ── 6. Vertex points ─────────────────────────────────────────
    for (final pt in points) {
      // Outer glow ring (pulsing)
      canvas.drawCircle(pt, 9 + 3 * pulseValue, Paint()..color = _aqua.withAlpha((18 * pulseValue).toInt()));
      canvas.drawCircle(pt, 5.5, Paint()..color = _aqua.withAlpha(55));
      canvas.drawCircle(pt, 3, Paint()..color = Colors.white);
      canvas.drawCircle(pt, 1.5, Paint()..color = _aqua);
    }

    // ── 7. Labels ────────────────────────────────────────────────
    final labels = ['INT', 'REC', 'SCK', 'RUN', 'PAS'];
    for (int i = 0; i < sides; i++) {
      final lx = center.dx + (radius + 22) * math.cos(angleStep * i + rotOff);
      final ly = center.dy + (radius + 22) * math.sin(angleStep * i + rotOff);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: GoogleFonts.oswald(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            shadows: [Shadow(color: _aqua.withAlpha(180), blurRadius: 7)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }

  void _drawDashedPentagon(
    Canvas canvas, Offset center, double radius, int sides,
    double angleStep, double rotOff, Color color, double strokeWidth,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (int i = 0; i < sides; i++) {
      final x1 = center.dx + radius * math.cos(angleStep * i + rotOff);
      final y1 = center.dy + radius * math.sin(angleStep * i + rotOff);
      final x2 = center.dx + radius * math.cos(angleStep * (i + 1) + rotOff);
      final y2 = center.dy + radius * math.sin(angleStep * (i + 1) + rotOff);
      _drawDashedLine(canvas, Offset(x1, y1), Offset(x2, y2), paint, 5.0, 3.5);
    }
  }

  void _drawDashedLine(
    Canvas canvas, Offset start, Offset end, Paint paint,
    double dashLen, double gapLen,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final nx = dx / len;
    final ny = dy / len;
    double traveled = 0;
    bool drawing = true;
    while (traveled < len) {
      final seg = drawing ? dashLen : gapLen;
      final next = (traveled + seg).clamp(0.0, len);
      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + nx * traveled, start.dy + ny * traveled),
          Offset(start.dx + nx * next, start.dy + ny * next),
          paint,
        );
      }
      traveled = next;
      drawing = !drawing;
      if (traveled >= len) break;
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}

