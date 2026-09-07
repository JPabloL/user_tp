import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../config/theme.dart';
import '../widgets/search_player_sheet.dart';


import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../services/player_dashboard_route.dart';
import '../services/match_detail_route.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';
import '../services/toast_service.dart';
import '../services/curp_service.dart';
import 'add_child_page.dart';
import 'login_page.dart';
import 'player_dashboard_page.dart';
import '../services/tournament_detail_route.dart';
import 'torneos_page.dart';
import '../services/user_matches_store.dart';
import '../utils/match_helpers.dart';
import '../utils/selectivo_helpers.dart';
import '../utils/user_players_debug_log.dart';
import '../widgets/dashboard/next_battle_carousel.dart';
import '../widgets/player_tournament_matches_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.storage,
    required this.pushService,
    required this.socketService,
    required this.curpService,
  });

  static const String route = '/home';

  final ApiService api;
  final StorageService storage;
  final PushNotificationService pushService;
  final SocketService socketService;
  final CurpService curpService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  String currentTab = 'general';
  int currentStep = 0;
  bool mostrarBotonPush = false;
  bool isLocked = false;
  DateTime? expirationDate;
  bool isLoading = true;
  bool showSecurityDetails = false;

  Map<String, dynamic> user = {'identity_docs': <String, dynamic>{}};
  Map<String, dynamic> roles = {'isPlayer': false, 'isTutor': false, 'isCoach': false};
  List<dynamic> myChildren = [];
  Map<String, dynamic> playerProfile = {'teams': [], 'positions': []};
  Map<String, dynamic>? dashboardData;
  int _dashboardEpoch = 0;
  int _currentBottomTab = 0;
  int _playersSubTab = 0;
  Map<String, int> _pendingRequestsByPlayer = {};
  Map<String, int> _pendingSelectivosByPlayer = {};

  StreamSubscription<dynamic>? _requestSub;
  StreamSubscription<dynamic>? _userContextSub;
  StreamSubscription<dynamic>? _matchSub;
  final UserMatchesStore _matchesStore = UserMatchesStore.instance;

  bool showPlayerForm = false;
  final numberCtrl = TextEditingController();
  final positionsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.pushService.setForegroundHandler(_onPushForeground);
    loadFullProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.pushService.handleLaunchNotification();
    });
  }

  @override
  void dispose() {
    widget.pushService.setForegroundHandler(null);
    _requestSub?.cancel();
    _userContextSub?.cancel();
    _matchSub?.cancel();
    numberCtrl.dispose();
    positionsCtrl.dispose();
    super.dispose();
  }

  Future<void> loadFullProfile() async {
    final session = await widget.storage.getJson(AppConfig.sessionKey);
    if (session == null || session['uid'] == null) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(LoginPage.route, (_) => false);
      return;
    }

    // Limpia caché antigua si quedó guardada en versiones previas
    await widget.storage.remove('cached_dashboard_v2');

    if (mounted && dashboardData == null) {
      setState(() => isLoading = true);
    }

    try {
      final res = await widget.api.getUserContextV2(session['uid'].toString());
      if (res['status'] == 'ok') {
        final hasToken = (res['user']?['fcm_token'] ?? '').toString().isNotEmpty;
        if (hasToken && (session['fcm_token'] == null || session['fcm_token'].toString().isEmpty)) {
          session['fcm_token'] = res['user']['fcm_token'];
          await widget.storage.setJson(AppConfig.sessionKey, session);
        }

        _applyUserContext(
          res,
          logSource: dashboardData == null ? 'home-load' : 'home-refresh',
        );
        await _persistSessionPlayerHints(res);
        await _syncPlayerProfileToUserIfNeeded();
        await _hydrateTournamentMedia();
        await _loadPendingRequestsForProfiles();
        if (!mounted) return;
        setState(() {
          isLoading = false;
          _dashboardEpoch++;
        });
        _ingestMatchesFromDashboard();
        _setupRealtimeSync();
        _setupMatchRealtime();
        await _initPushNotifications();
      } else if (mounted) {
        setState(() => isLoading = false);
        _toast('No se pudo actualizar el perfil', isError: true);
      }
    } catch (e, stackTrace) {
      if (mounted) setState(() => isLoading = false);
      _toast('Error: $e', isError: true);
    }
  }

  void _showModernLoader() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(200),
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              decoration: BoxDecoration(
                color: AppTheme.navySurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.brandTeal.withAlpha(100), width: 1.5),
                boxShadow: [
                  BoxShadow(color: AppTheme.brandTeal.withAlpha(40), blurRadius: 40, spreadRadius: 10),
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.brandTeal, strokeWidth: 3),
                  const SizedBox(height: 24),
                  Text('Sincronizando Radar...', style: GoogleFonts.oswald(fontSize: 18, color: AppTheme.brandTeal, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  const Text('Actualizando información', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  void _confirmUnfollowPlayer(dynamic fp) {
    final alias = (fp['alias']?.toString() ?? '').isNotEmpty ? fp['alias'] : fp['fullName'] ?? 'este jugador';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navySurface,
        title: const Text('Dejar de seguir', style: TextStyle(color: Colors.white)),
        content: Text('¿Estás seguro que deseas dejar de seguir a $alias? También dejarás de seguir automáticamente a sus equipos.', style: const TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(ctx).pop();
              _unfollowPlayer(fp['playerId']);
            },
            child: const Text('Dejar de seguir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _unfollowPlayer(String playerId) async {
    _showModernLoader();
    try {
      final res = await widget.api.post('/deleteFollowPlayer', {
        'userId': user['_id'],
        'playerId': playerId,
      });
      if (res['status'] == 'ok') {
        _toast('Dejaste de seguir al jugador');
        await loadFullProfile();
      } else {
        _toast(res['message'] ?? 'Error al dejar de seguir', isError: true);
      }
    } catch (e) {
      _toast('Error de conexión', isError: true);
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Quitar loader
    }
  }

  Future<void> _syncPlayerProfileToUserIfNeeded() async {
    if (roles['isPlayer'] == true && playerProfile.isNotEmpty) {
      bool needsSync = false;
      Map<String, dynamic> payload = {'_id': user['_id']};

      final fields = ['curp', 'name', 'apellidoPa', 'apellidoMa', 'bd', 'gender'];
      for (final field in fields) {
        if ((user[field] ?? '').toString().isEmpty && (playerProfile[field] ?? '').toString().isNotEmpty) {
          payload[field] = playerProfile[field];
          user[field] = playerProfile[field];
          needsSync = true;
        }
      }

      if ((user['avatar'] ?? '').toString().isEmpty && (playerProfile['photo'] ?? '').toString().isNotEmpty) {
        payload['avatar'] = playerProfile['photo'];
        user['avatar'] = playerProfile['photo'];
        needsSync = true;
      }

      if (needsSync) {
        try {
          await widget.api.updateDoc(payload);
        } catch (e) {
          // Sin log en consola: el perfil local sigue disponible.
        }
      }
    }
    
    // Ensure we skip selfie if avatar exists
    if (currentStep == 0 && (user['avatar'] ?? '').toString().isNotEmpty) {
      currentStep = 1;
    }
  }

  void _applyUserContext(Map<String, dynamic> res, {String logSource = 'home'}) {
    logUserPlayersContext(res, source: logSource);
    user = {...user, ...(res['user'] as Map<String, dynamic>? ?? {})};
    roles = (res['roles'] as Map<String, dynamic>?) ?? roles;
    final rawChildren = (res['children'] as List<dynamic>?) ?? [];
    myChildren = List<dynamic>.from(rawChildren);
    playerProfile = (res['myPlayerProfile'] as Map<String, dynamic>?) ?? playerProfile;

    final dash = res['dashboard'];
    if (dash is Map) {
      dashboardData = Map<String, dynamic>.from(dash);
      final tournaments = dashboardData!['activeTournaments'];
      if (tournaments is List) {
        dashboardData = {
          ...dashboardData!,
          'activeTournaments': tournaments
              .map(_normalizeTournament)
              .where((t) => t.isNotEmpty)
              .toList(),
        };
      }
    } else {
      dashboardData = null;
    }

    mostrarBotonPush = (res['user']?['fcm_token'] ?? '').toString().isEmpty;

    if (user['identity_status'] == 'verified') {
      currentStep = 2;
      if (user['verification_expires_at'] != null) {
        expirationDate = DateTime.tryParse(user['verification_expires_at'].toString());
        if (expirationDate != null) {
          isLocked = DateTime.now().isBefore(expirationDate!);
        }
      }
    } else {
      currentStep = int.tryParse((user['verification_step'] ?? '0').toString()) ?? 0;
      if ((user['avatar'] ?? '').toString().isEmpty) {
        currentStep = 0;
      } else if (currentStep == 0) {
        currentStep = 1;
      }
    }
  }

  Future<void> _persistSessionPlayerHints(Map<String, dynamic> res) async {
    final session = await widget.storage.getJson(AppConfig.sessionKey);
    if (session == null) return;

    if (res['roles'] is Map) {
      session['roles'] = res['roles'];
    }

    final myPlayer = res['myPlayerProfile'];
    if (myPlayer is Map) {
      final myPlayerId = (myPlayer['playerId'] ??
              myPlayer['id'] ??
              myPlayer['_id'] ??
              '')
          .toString();
      if (myPlayerId.isNotEmpty) {
        session['myPlayerId'] = myPlayerId;
      }
    }

    await widget.storage.setJson(AppConfig.sessionKey, session);
  }

  String _resolveMediaUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('/')) return 'https://cuerposallimite.net$value';
    return 'https://cuerposallimite.net/nlff/resources/images/$value';
  }

  /// Mapea el objeto de `cleanTournamentRef` del endpoint user-context-v2.
  Map<String, dynamic> _normalizeTournament(dynamic item) {
    if (item is! Map) return {};
    final map = Map<String, dynamic>.from(item);
    final id = (map['id'] ?? map['_id'] ?? map['tournamentId'] ?? '').toString();
    final clave = (map['clave'] ?? map['public_key'] ?? map['slug'] ?? '').toString().trim();
    return {
      ...map,
      'id': id,
      'clave': clave,
      'name': (map['name'] ?? 'Torneo').toString(),
      'subname': (map['subname'] ?? '').toString().trim(),
      'logo': _resolveMediaUrl((map['logo'] ?? '').toString()),
      'img': _resolveMediaUrl((map['img'] ?? '').toString()),
      'start': map['start']?.toString() ?? '',
      'end': map['end']?.toString() ?? '',
    };
  }

  String _resolveTournamentClave(Map<String, dynamic> tournament) {
    return (tournament['clave'] ??
            tournament['public_key'] ??
            tournament['slug'] ??
            '')
        .toString()
        .trim();
  }

  String _resolveTournamentId(Map<String, dynamic> tournament) {
    return (tournament['id'] ??
            tournament['_id'] ??
            tournament['tournamentId'] ??
            '')
        .toString()
        .trim();
  }

  Future<void> _openTournamentDetail(Map<String, dynamic> tournament) async {
    var clave = _resolveTournamentClave(tournament);
    final id = _resolveTournamentId(tournament);

    if (clave.isEmpty && id.isNotEmpty) {
      try {
        final full = await widget.api.getTournamentById(id);
        if (full != null) {
          clave = _resolveTournamentClave(full);
        }
      } catch (_) {
        // Si falla la consulta por id, intentamos abrir con el identificador disponible.
      }
    }

    final routeKey = clave.isNotEmpty ? clave : id;
    if (routeKey.isEmpty) {
      _toast('No se pudo abrir este torneo', isError: true);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushNamed(
      TournamentDetailRoute.routeFor(routeKey),
      arguments: {
        if (clave.isNotEmpty) 'clave': clave,
        if (id.isNotEmpty) 'id': id,
      },
    );
  }

  bool _tournamentNeedsHydration(Map<String, dynamic> t) {
    return _resolveTournamentClave(t).isEmpty ||
        (t['img'] ?? '').toString().isEmpty ||
        (t['logo'] ?? '').toString().isEmpty ||
        (t['subname'] ?? '').toString().isEmpty;
  }

  /// Si el snapshot embebido en equipos viene sin media, pide el doc completo del torneo.
  Future<void> _hydrateTournamentMedia() async {
    if (dashboardData == null) return;
    final raw = dashboardData!['activeTournaments'];
    if (raw is! List || raw.isEmpty) return;

    final updated = <Map<String, dynamic>>[];
    var changed = false;

    for (final item in raw) {
      var tournament = _normalizeTournament(item);
      final id = tournament['id'].toString();
      if (_tournamentNeedsHydration(tournament) && id.isNotEmpty) {
        try {
          final full = await widget.api.getTournamentById(id);
          if (full != null) {
            tournament = _normalizeTournament({...tournament, ...full});
            changed = true;
          }
        } catch (_) {
          // Sin bloquear el dashboard si falla un torneo.
        }
      }
      updated.add(tournament);
    }

    if (changed) {
      dashboardData = {
        ...dashboardData!,
        'activeTournaments': updated,
      };
    }
  }

  List<Map<String, dynamic>> get _activeTournaments {
    final raw = dashboardData?['activeTournaments'] as List<dynamic>? ?? [];
    return raw
        .map(_normalizeTournament)
        .where((t) => (t['id'] ?? '').toString().isNotEmpty)
        .toList();
  }

  int _countPendingRequests(List<dynamic> requests) {
    return requests.where((r) {
      if (r is! Map) return false;
      final mood = r['mood'];
      return mood == 0 || mood == '0';
    }).length;
  }

  int _pendingAttentionCount(String playerId) {
    return (_pendingRequestsByPlayer[playerId] ?? 0) +
        (_pendingSelectivosByPlayer[playerId] ?? 0);
  }

  Future<void> _loadPendingRequestsForProfiles() async {
    _pendingSelectivosByPlayer =
        SelectivoHelpers.pendingConsentCounts(dashboardData);

    final profiles = _managedProfiles();
    if (profiles.isEmpty) {
      _pendingRequestsByPlayer = {};
      return;
    }

    final results = await Future.wait(
      profiles.map((profile) async {
        final playerId = (profile['playerId'] ?? profile['id'] ?? '').toString();
        if (playerId.isEmpty) return MapEntry('', 0);
        try {
          final requests = await widget.api.getMyRequests(playerId);
          return MapEntry(playerId, _countPendingRequests(requests));
        } catch (_) {
          return MapEntry(playerId, 0);
        }
      }),
    );

    _pendingRequestsByPlayer = {
      for (final entry in results)
        if (entry.key.isNotEmpty) entry.key: entry.value,
    };
  }

  bool get _hasBrandLogo {
    final avatar = (user['avatar'] ?? user['thumb'] ?? '').toString();
    return avatar.isNotEmpty;
  }

  ({String? academyId, String academyName}) get _watchContext {
    final teams = dashboardData?['activeTeams'] as List<dynamic>? ?? [];
    for (final team in teams) {
      if (team is! Map) continue;
      final academy = team['academy'];
      if (academy is Map) {
        final id = (academy['id'] ?? academy['_id'] ?? '').toString();
        final name = (academy['name'] ?? '').toString();
        if (id.isNotEmpty || name.isNotEmpty) {
          return (
            academyId: id.isEmpty ? null : id,
            academyName: name.isEmpty ? 'Mi academia' : name,
          );
        }
      }
    }
    String rawName = (user['name'] ?? '').toString().trim();
    if (rawName.isEmpty || rawName.contains('\$USER')) {
      rawName = 'USUARIO';
    }
    final firstName = rawName.split(' ').first;
    return (academyId: null, academyName: firstName);
  }

  void _ingestMatchesFromDashboard() {
    _matchesStore.saveFromDashboard(dashboardData);
    _subscribeMatchRooms();
  }

  void _subscribeMatchRooms() {
    widget.socketService.connect();
    for (final match in _matchesStore.upcomingMatches) {
      final id = MatchHelpers.matchId(match);
      if (id.isNotEmpty) widget.socketService.joinMatch(id);
    }
    for (final match in _matchesStore.lastMatches) {
      if (!MatchHelpers.isLive(match)) continue;
      final id = MatchHelpers.matchId(match);
      if (id.isNotEmpty) widget.socketService.joinMatch(id);
    }
  }

  void _setupMatchRealtime() {
    _matchSub ??= widget.socketService.matchUpdates.listen((raw) {
      final envelope = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final data = envelope['data'] ?? envelope;
      if (_matchesStore.updateMatch(data)) {
        if (mounted) setState(() => _dashboardEpoch++);
      }
      _subscribeMatchRooms();
    });
  }

  void _openMatchDetail(Map<String, dynamic> match) {
    final id = MatchHelpers.matchId(match);
    if (id.isEmpty) return;
    Navigator.of(context).pushNamed(
      MatchDetailRoute.routeFor(id),
      arguments: MatchDetailRouteArgs(matchId: id, matchSnapshot: match),
    );
  }

  void _setupRealtimeSync() {
    final userId = (user['_id'] ?? user['id'] ?? '').toString();
    final playerIds = <String>{
      ..._managedProfiles().map((p) => (p['playerId'] ?? p['id'] ?? '').toString()),
      ..._followedProfiles().map((p) => (p['playerId'] ?? p['id'] ?? '').toString()),
    }.where((id) => id.isNotEmpty);

    widget.socketService.joinTutorSession(
      userId: userId,
      playerIds: playerIds,
    );

    _requestSub?.cancel();
    _requestSub = widget.socketService.requestUpdatesStream.listen((data) async {
      await _loadPendingRequestsForProfiles();
      if (!mounted) return;
      setState(() {});
    });

    _userContextSub?.cancel();
    _userContextSub = widget.socketService.userContextStream.listen((data) async {
      await loadFullProfile();
      if (!mounted) return;
      if (SocketService.isTeamAssignmentEvent(data)) {
        final name = SocketService.eventPlayerName(data) ?? 'Un jugador';
        _toast('$name integrado a un equipo');
      }
    });
  }

  Future<void> takeSelfieStep1() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1200, maxHeight: 1200);
    if (image == null) return;

    _setLoading(true);
    try {
      final res = await widget.api.uploadAvatar(
        uid: user['_id'].toString(),
        bytes: await image.readAsBytes(),
      );
      if (res['status'] == 'ok') {
        user['avatar'] = res['url'];
        currentStep = 1;
        await _updateLocalStorageAvatar(res['url']?.toString() ?? '');
        _toast('Foto guardada. Siguiente paso.');
      } else {
        _toast((res['message'] ?? 'No se pudo subir').toString(), isError: true);
      }
    } catch (_) {
      _toast('Error al subir', isError: true);
    }
    _setLoading(false);
    if (mounted) setState(() {});
  }

  Future<void> uploadIdStep2() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1200, maxHeight: 1200);
    if (image == null) return;

    _setLoading(true);
    try {
      final res = await widget.api.uploadIdentityDoc(
        uid: user['_id'].toString(),
        bytes: await image.readAsBytes(),
        side: 'front',
      );
      if (res['status'] == 'ok') {
        final docs = (user['identity_docs'] as Map<String, dynamic>?) ?? {};
        docs['front'] = res['url'];
        user['identity_docs'] = docs;

        final match = res['ocr']?['biometria']?['match'] == true;
        
        final myCurp = (playerProfile['curp'] ?? user['curp'] ?? '').toString().trim().toUpperCase();
        String ocrCurp = '';
        if (res['ocr'] is Map) {
          ocrCurp = _extractCurp(Map<String, dynamic>.from(res['ocr']));
        }

        if (match) {
          if (myCurp.isNotEmpty && ocrCurp.isNotEmpty && myCurp != ocrCurp) {
            _toast('Error: La identificación no pertenece al perfil registrado.', isError: true);
            _setLoading(false);
            return;
          }
          
          _toast('Identidad verificada');
          currentStep = 2;
          isLocked = true;
          if (res['actionTaken'] == 'PLAYER_UPDATED') {
            await _updateLocalSession('player');
          }
          await loadFullProfile();
        } else {
          final msg =
              (res['ocr']?['biometria']?['mensaje'] ?? 'Error: rostros no coinciden').toString();
          _toast(msg, isError: true);
        }
      } else {
        _toast((res['message'] ?? 'Error de validación').toString(), isError: true);
      }
    } catch (_) {
      _toast('Error de servidor', isError: true);
    }
    _setLoading(false);
  }

  String _extractCurp(Map<String, dynamic> data) {
    for (final key in data.keys) {
      final val = data[key];
      if (key.toLowerCase() == 'curp' && val is String) {
        return val.trim().toUpperCase();
      }
      if (val is Map<String, dynamic>) {
        final res = _extractCurp(val);
        if (res.isNotEmpty) return res;
      }
    }
    return '';
  }

  Future<void> _initPushNotifications() async {
    final result = await widget.pushService.ensureInitialized();
    if (!mounted) return;
    if (result.ok) {
      setState(() => mostrarBotonPush = false);
      return;
    }
    if (kDebugMode && result.error != null) {
      // ignore: avoid_print
      print('Push no listo: ${result.error}');
    }
    setState(() => mostrarBotonPush = true);
  }

  void _onPushForeground(PushNotificationAction action) {
    if (!mounted) return;

    if (action.openRequests) {
      _loadPendingRequestsForProfiles().then((_) {
        if (!mounted) return;
        setState(() {});
      });
      return;
    }

    if (action.openTeamsTab) {
      loadFullProfile();
      _toast('${action.playerName} fue asignado a un equipo');
    }
  }

  Future<void> activarAvisos() async {
    final result = await widget.pushService.ensureInitialized(force: true);
    if (!result.ok) {
      final detail = result.error ?? widget.pushService.lastSyncError ?? '';
      _toast(
        detail.isEmpty
            ? 'No se pudieron activar las notificaciones'
            : 'Push: $detail',
        isError: true,
      );
      return;
    }
    setState(() => mostrarBotonPush = false);
    _toast('Avisos activados correctamente');
  }

  Future<void> createPlayerProfile() async {
    if (numberCtrl.text.trim().isEmpty) {
      _toast('Selecciona tu número de jersey.', isError: true);
      return;
    }
    final positions = positionsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (positions.isEmpty) {
      _toast('Selecciona al menos una posición.', isError: true);
      return;
    }
    _setLoading(true);
    try {
      final res = await widget.api.createPlayerProfile({
        'userId': user['_id'],
        'number': int.tryParse(numberCtrl.text.trim()) ?? numberCtrl.text.trim(),
        'positions': positions,
        'isChild': false,
      });
      if (res['status'] == 'ok') {
        _toast('Perfil activado. Bienvenido a la cancha.');
        showPlayerForm = false;
        await _updateLocalSession('player');
        await loadFullProfile();
      } else {
        _toast((res['message'] ?? 'No se pudo activar').toString(), isError: true);
      }
    } catch (_) {
      _toast('Error al activar perfil', isError: true);
    }
    _setLoading(false);
    if (mounted) setState(() {});
  }

  Future<void> _updateLocalStorageAvatar(String newUrl) async {
    final session = await widget.storage.getJson(AppConfig.sessionKey);
    if (session == null) return;
    session['avatar'] = newUrl;
    await widget.storage.setJson(AppConfig.sessionKey, session);
  }

  Future<void> _updateLocalSession(String role) async {
    final session = await widget.storage.getJson(AppConfig.sessionKey);
    if (session == null) return;
    final rolesMap = (session['roles'] as Map<String, dynamic>?) ?? {};
    if (role == 'player') rolesMap['isPlayer'] = true;
    session['roles'] = rolesMap;
    await widget.storage.setJson(AppConfig.sessionKey, session);
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ToastService.show(msg, isError: isError);
  }

  void _setLoading(bool value) {
    if (mounted) setState(() => isLoading = value);
  }





  @override
  Widget build(BuildContext context) {
    if (isLoading && dashboardData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1629),
        body: Center(child: CircularProgressIndicator(color: AppTheme.brandTeal)),
      );
    }

    final isVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    final hasPlayerAccess = _hasPlayerHomeAccess();

    Widget bodyContent;
    if (!isVerified) {
      bodyContent = _buildValidationState();
    } else if (!hasPlayerAccess) {
      bodyContent = _buildAddPlayersState();
    } else {
      if (_currentBottomTab == 0) {
        bodyContent = _buildUserDashboardState();
      } else if (_currentBottomTab == 1) {
        bodyContent = _buildPlayersTab();
      } else if (_currentBottomTab == 2) {
        bodyContent = _buildCalendarTab();
      } else if (_currentBottomTab == 3) {
        bodyContent = _buildProfileTab();
      } else {
        bodyContent = const SizedBox.shrink();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070B14), // Fondo más oscuro
      body: Stack(
        children: [
          // Fondo de yardas muy sutil para dar textura Stealth
          Positioned.fill(
            child: Opacity(
              opacity: 0.25, // Muy sutil
              child: _FieldMarkings(isDesktop: false),
            ),
          ),
          RefreshIndicator(
            onRefresh: loadFullProfile,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 22),
              children: [
                _buildHeaderLogo(),
                const SizedBox(height: 24),
                bodyContent,
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: (isVerified && hasPlayerAccess)
          ? _buildBottomNav()
          : null,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1522).withAlpha(200), // Deep elegant dark
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(15), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(child: _buildNavItem(0, Icons.home_filled, Icons.home_outlined, 'Inicio')),
                Expanded(child: _buildNavItem(1, Icons.groups, Icons.groups_outlined, 'Jugadores')),
                Expanded(child: _buildNavItem(2, Icons.sports_football, Icons.sports_football_outlined, 'Partidos')),
                Expanded(
                  child: _buildNavItem(
                    null,
                    Icons.emoji_events,
                    Icons.emoji_events_outlined,
                    'Torneos',
                    onTap: () => Navigator.of(context).pushNamed(TorneosPage.route),
                  ),
                ),
                Expanded(child: _buildNavItem(3, Icons.person, Icons.person_outline, 'Perfil')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int? index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label, {
    VoidCallback? onTap,
  }) {
    final isActive = index != null && _currentBottomTab == index;
    return GestureDetector(
      onTap: onTap ?? () => setState(() => _currentBottomTab = index!),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Icon(
                isActive ? activeIcon : inactiveIcon,
                key: ValueKey<bool>(isActive),
                color: isActive ? AppTheme.brandTeal : Colors.white.withAlpha(100),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                color: isActive ? AppTheme.brandTeal : Colors.white.withAlpha(100),
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isActive ? 1.0 : 0.0,
              child: Container(
                height: 3,
                width: 16,
                decoration: BoxDecoration(
                  color: AppTheme.brandTeal,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brandTeal,
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderLogo() {
    String rawName = (user['name'] ?? '').toString().trim();
    if (rawName.isEmpty || rawName.contains('\$USER')) {
      rawName = 'USUARIO';
    }
    final firstName = rawName.split(' ').first.toUpperCase();
    final hour = DateTime.now().hour;
    
    final upcoming = _matchesStore.getCarouselMatches();
    bool isMatchTime = false;
    final now = DateTime.now();

    for (final match in upcoming) {
      if (MatchHelpers.isLive(match)) {
        isMatchTime = true;
        break;
      }
      final dateStr = (match['date'] ?? match['scheduledDate'])?.toString();
      if (dateStr != null && dateStr.isNotEmpty) {
        final matchDate = DateTime.tryParse(dateStr);
        if (matchDate != null) {
          final diff = matchDate.difference(now).inMinutes;
          if (diff >= -120 && diff <= 120) {
            isMatchTime = true;
            break;
          }
        }
      }
    }

    String greeting = '¡Buenas noches!';
    bool isMatchGreeting = false;
    if (isMatchTime) {
      isMatchGreeting = true;
      greeting = '¡Ya es hora de los partidos!';
    } else {
      if (hour < 12) {
        greeting = '¡Excelente día!';
      } else if (hour < 15) {
        greeting = '¡Buen provecho!';
      } else if (hour < 19) {
        greeting = '¡Buena tarde!';
      }
    }

    final greetingStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Colors.white.withOpacity(0.6),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo_icon.png',
              height: 36,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.bolt, color: AppTheme.brandTeal, size: 36),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HOLA, $firstName',
                  style: const TextStyle(
                    fontSize: 20,
                    letterSpacing: 2.1,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                if (isMatchGreeting)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(greeting, style: greetingStyle),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.sports_football,
                        size: 15,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ],
                  )
                else
                  Text(greeting, style: greetingStyle),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValidationState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Validación',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: (user['avatar'] ?? '').toString().isEmpty
                    ? null
                    : NetworkImage(user['avatar'].toString()),
                child: (user['avatar'] ?? '').toString().isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user['name'] ?? 'Sin nombre').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (user['mail'] ?? '').toString(),
                      style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Pendiente',
                  style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Para continuar usando la aplicacion y dar de alta perfiles de jugadores o recuperar perfiles existentes, primero debes verificar tu correo electrónico.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          text: 'ENVIAR CORREO DE VERIFICACIÓN',
          onPressed: () async {
            try {
              await FirebaseAuth.instance.currentUser?.sendEmailVerification();
              _toast('Correo enviado. Por favor, revisa tu bandeja de entrada o spam.');
            } catch (e) {
              _toast('Error al enviar el correo. Intenta de nuevo más tarde.', isError: true);
            }
          },
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          text: 'YA VERIFIQUÉ MI CORREO',
          onPressed: () async {
            await FirebaseAuth.instance.currentUser?.reload();
            if (mounted) setState(() {});
            if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) {
              _toast('¡Correo verificado con éxito!');
            } else {
              _toast('Tu correo aún no está verificado.', isError: true);
            }
          },
        ),
      ],
    );
  }

  Widget _buildAddPlayersState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mis Perfiles',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 48),
        Center(
          child: Column(
            children: [
              const Icon(Icons.people_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Aún no hay perfiles',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Agrega a tu primer jugador para ver su información en el dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: 'NUEVO PERFIL',
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AddChildPage.route,
                      arguments: {
                        'parentId': user['_id'],
                        'parentName': "${user['name'] ?? ''} ${user['apellidoPa'] ?? ''}".trim(),
                        'parentCurp': user['curp'],
                        'parentApPa': user['apellidoPa'],
                        'parentApMa': user['apellidoMa'],
                      },
                    ).then((_) => loadFullProfile());
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHomeAlertCard({
    required Color accent,
    required IconData icon,
    required String title,
    required String message,
    required VoidCallback onTap,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12),
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: margin,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accent.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withAlpha(80)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 16),
          ],
        ),
      ),
    );
  }

  String _teamPendingRequestsMessage(int totalPending, int playersAffected) {
    if (totalPending == 1) {
      return '1 solicitud de equipo o academia pendiente de respuesta.';
    }
    if (playersAffected == 1) {
      return '$totalPending solicitudes de equipo o academia pendientes en 1 jugador.';
    }
    return '$totalPending solicitudes de equipo o academia pendientes en $playersAffected jugador(es).';
  }

  String _pendingAttentionTitle({
    required int teamCount,
    required int selectivoCount,
  }) {
    if (teamCount > 0 && selectivoCount > 0) return 'SOLICITUDES PENDIENTES';
    if (selectivoCount > 0) return 'SELECTIVOS';
    return 'SOLICITUDES DE EQUIPO';
  }

  String _pendingAttentionMessage({
    required int teamCount,
    required int selectivoCount,
    required int playersAffected,
  }) {
    if (teamCount > 0 && selectivoCount > 0) {
      return 'Tienes solicitudes de equipo y convocatorias a selectivo pendientes.';
    }
    if (selectivoCount > 0) {
      if (selectivoCount == 1) {
        return '1 convocatoria a selectivo pendiente de tu consentimiento.';
      }
      if (playersAffected == 1) {
        return '$selectivoCount convocatorias a selectivo pendientes en 1 jugador.';
      }
      return '$selectivoCount convocatorias a selectivo pendientes en $playersAffected jugador(es).';
    }
    return _teamPendingRequestsMessage(teamCount, playersAffected);
  }

  String _pendingBadgeLabel({
    required int teamCount,
    required int selectivoCount,
  }) {
    final total = teamCount + selectivoCount;
    if (total <= 0) return '';
    if (teamCount > 0 && selectivoCount > 0) {
      return total == 1 ? '1 SOLICITUD' : '$total SOLICITUDES';
    }
    if (selectivoCount > 0) {
      return selectivoCount == 1 ? '1 SELECTIVO' : '$selectivoCount SELECTIVOS';
    }
    return teamCount == 1 ? '1 SOLICITUD EQUIPO' : '$teamCount SOLICITUDES EQUIPO';
  }

  Widget _buildUserDashboardState() {
    final managedProfiles = _managedProfiles();

    int playersNeedingValidation = 0;
    int totalTeamPendingRequests = 0;
    int totalSelectivoPending = 0;
    int playersWithPendingAttention = 0;
    for (final p in managedProfiles) {
      final identityStatus = p['identity_status']?.toString();
      if (identityStatus != 'verified' && identityStatus != 'manual_review') {
        playersNeedingValidation++;
      }
      final String pId = (p['playerId'] ?? p['id'] ?? '').toString();
      final pendingCount = _pendingRequestsByPlayer[pId] ?? 0;
      if (pendingCount > 0) {
        totalTeamPendingRequests += pendingCount;
      }
      final selectivoCount = _pendingSelectivosByPlayer[pId] ?? 0;
      if (selectivoCount > 0) {
        totalSelectivoPending += selectivoCount;
      }
      if (pendingCount > 0 || selectivoCount > 0) {
        playersWithPendingAttention++;
      }
    }
    final coTutorshipPending =
        (dashboardData?['coTutorship']?['pending'] as List<dynamic>?) ?? [];
    final coTutorshipPendingCount = coTutorshipPending.length;
    final hasPendingAttention = playersWithPendingAttention > 0;

    void openPlayersTab() {
      setState(() => _currentBottomTab = 1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (playersNeedingValidation > 0)
          _buildHomeAlertCard(
            accent: Colors.redAccent,
            icon: Icons.warning_amber_rounded,
            title: 'VALIDAR IDENTIDAD',
            message: playersNeedingValidation == 1
                ? 'Falta validar la identidad de 1 jugador.'
                : 'Falta validar la identidad de $playersNeedingValidation jugador(es).',
            onTap: openPlayersTab,
            margin: EdgeInsets.only(
              bottom: hasPendingAttention || coTutorshipPendingCount > 0 ? 12 : 24,
            ),
          ),
        if (hasPendingAttention)
          _buildHomeAlertCard(
            accent: const Color(0xFFFFD600),
            icon: Icons.notifications_active_rounded,
            title: _pendingAttentionTitle(
              teamCount: totalTeamPendingRequests,
              selectivoCount: totalSelectivoPending,
            ),
            message: _pendingAttentionMessage(
              teamCount: totalTeamPendingRequests,
              selectivoCount: totalSelectivoPending,
              playersAffected: playersWithPendingAttention,
            ),
            onTap: openPlayersTab,
            margin: EdgeInsets.only(
              bottom: coTutorshipPendingCount > 0 ? 12 : 24,
            ),
          ),
        if (coTutorshipPendingCount > 0)
          _buildHomeAlertCard(
            accent: AppTheme.brandTeal,
            icon: Icons.people_outline_rounded,
            title: 'CO-TUTORÍA',
            message: coTutorshipPendingCount == 1
                ? 'Tienes 1 solicitud de co-tutoría pendiente.'
                : 'Tienes $coTutorshipPendingCount solicitudes de co-tutoría pendientes.',
            onTap: openPlayersTab,
            margin: const EdgeInsets.only(bottom: 24),
          ),
        _buildMyPlayersQuickSection(),
        const SizedBox(height: 32),

        const Text(
          'MIS TORNEOS',
          style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            final activeTournaments = _activeTournaments;
            if (activeTournaments.isEmpty) {
              return const Text('No tienes torneos activos.', style: TextStyle(color: Colors.white54));
            }
            return SizedBox(
              height: 180,
              child: ListView.builder(
                key: ValueKey('tournaments-$_dashboardEpoch'),
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: activeTournaments.length,
                itemBuilder: (context, index) {
                  final tournament = activeTournaments[index];
                  return _buildCarouselTournamentCard(
                    tournament,
                    key: ValueKey('${tournament['id']}-${tournament['img']}-${tournament['subname']}'),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 32),

        NextBattleCarouselSection(
          key: ValueKey('next-battle-$_dashboardEpoch'),
          store: _matchesStore,
          hasBrandLogo: _hasBrandLogo,
          resolveMediaUrl: _resolveMediaUrl,
          onMatchTap: _openMatchDetail,
          title: 'PRÓXIMA BATALLA',
        ),
        if (_hasBrandLogo && _matchesStore.getCarouselMatches().isNotEmpty)
          const SizedBox(height: 24),
      ],
    );
  }

  void _openPlayersTab({int? playersSubTab}) {
    setState(() {
      _currentBottomTab = 1;
      if (playersSubTab != null) {
        _playersSubTab = playersSubTab;
      }
    });
  }

  bool _isManualReviewPlayer(dynamic profile) {
    if (profile is! Map) return false;
    return profile['identity_status']?.toString() == 'manual_review';
  }

  List<Map<String, dynamic>> _managedProfiles() {
    final followedIds = _followedPlayerIds();
    final allProfiles = dashboardData?['profiles'] as List<dynamic>? ?? [];
    return allProfiles
        .where((p) => p is Map)
        .map((p) => Map<String, dynamic>.from(p as Map))
        .where((p) => !followedIds.contains(_playerIdFromProfile(p)))
        .toList();
  }

  String _playerIdFromProfile(Map<String, dynamic> profile) {
    return (profile['playerId'] ?? profile['id'] ?? profile['_id'] ?? '')
        .toString()
        .trim();
  }

  Set<String> _followedPlayerIds() {
    return _followedProfiles()
        .map(_playerIdFromProfile)
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  bool _isFollowedRelation(dynamic profile) {
    if (profile is! Map) return false;
    return _isFollowedProfile(Map<String, dynamic>.from(profile));
  }

  bool _isFollowedProfile(Map<String, dynamic> profile) {
    final playerId = _playerIdFromProfile(profile);
    if (playerId.isEmpty) return false;
    return _followedPlayerIds().contains(playerId);
  }

  bool _hasPlayerHomeAccess() {
    return _managedProfiles().isNotEmpty || _followedProfiles().isNotEmpty;
  }

  List<Map<String, dynamic>> _followedProfiles() {
    final raw = (dashboardData?['following']?['players'] as List<dynamic>?) ?? [];
    return raw
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
  }

  String _playerFirstName(dynamic profile, {bool isFollowed = false}) {
    final raw = isFollowed
        ? (profile['fullName'] ?? profile['userName'] ?? profile['name'] ?? '').toString().trim()
        : (profile['name'] ?? '').toString().trim();
    if (raw.isEmpty) return 'Jugador';
    return raw.split(RegExp(r'\s+')).first;
  }

  void _openAddChildFlow() {
    Navigator.of(context).pushNamed(
      AddChildPage.route,
      arguments: {
        'parentId': user['_id'],
        'parentName': "${user['name'] ?? ''} ${user['apellidoPa'] ?? ''}".trim(),
        'parentCurp': user['curp'],
        'parentApPa': user['apellidoPa'],
        'parentApMa': user['apellidoMa'],
      },
    ).then((_) => loadFullProfile());
  }

  Map<String, dynamic> _managedPlayerDashboardArgs(
    Map<String, dynamic> profile, {
    String? verSolicitudes,
  }) {
    final playerId = _playerIdFromProfile(profile);
    return {
      'playerId': playerId,
      'playerName': (profile['name'] ?? profile['fullName'] ?? 'Jugador').toString(),
      if (verSolicitudes != null) 'verSolicitudes': verSolicitudes,
      'relation': (profile['relation'] ?? 'managed').toString(),
      'canManage': true,
    };
  }

  void _openManagedPlayerProfile(Map<String, dynamic> profile) {
    final playerId = (profile['playerId'] ?? profile['id'] ?? '').toString();
    if (playerId.isEmpty) return;

    if (_isManualReviewPlayer(profile)) {
      _openPlayersTab(playersSubTab: 0);
      return;
    }
    final isIdentityVerified = profile['identity_status']?.toString() == 'verified';
    if (!isIdentityVerified) {
      Navigator.of(context).pushNamed(
        AddChildPage.route,
        arguments: {
          'parentId': user['_id'],
          'parentName': "${user['name'] ?? ''} ${user['apellidoPa'] ?? ''}".trim(),
          'parentCurp': user['curp'],
          'parentApPa': user['apellidoPa'],
          'parentApMa': user['apellidoMa'],
          'child': profile,
        },
      ).then((_) => loadFullProfile());
      return;
    }

    final pendingRequests = _pendingAttentionCount(playerId);
    Navigator.of(context).pushNamed(
      PlayerDashboardRoute.routeFor(playerId),
      arguments: _managedPlayerDashboardArgs(
        profile,
        verSolicitudes: pendingRequests > 0 ? 'true' : 'false',
      ),
    ).then((_) => loadFullProfile());
  }

  void _openFollowedPlayerProfile(Map<String, dynamic> profile) {
    final playerId = (profile['playerId'] ?? profile['id'] ?? '').toString();
    if (playerId.isEmpty) return;

    final playerName = (profile['fullName'] ??
            profile['userName'] ??
            profile['name'] ??
            'Jugador')
        .toString();

    Navigator.of(context).pushNamed(
      PlayerDashboardRoute.routeFor(playerId),
      arguments: {
        'playerId': playerId,
        'playerName': playerName,
        'viewOnly': 'true',
        'relation': 'followed',
        'initialTab': 'stats',
      },
    ).then((_) => loadFullProfile());
  }

  void _openQuickPlayerEntry(Map<String, dynamic> entry) {
    final profile = Map<String, dynamic>.from(entry['profile'] as Map);
    if (_isFollowedProfile(profile)) {
      _openFollowedPlayerProfile(profile);
    } else {
      _openManagedPlayerProfile(profile);
    }
  }

  Widget _buildMyPlayersQuickSection() {
    final managed = _managedProfiles();
    final followed = _followedProfiles();
    final hasAnyPlayers = managed.isNotEmpty || followed.isNotEmpty;
    final showLoadingPlaceholders = isLoading && !hasAnyPlayers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLoadingPlaceholders)
          _buildMyPlayersLoadingRow()
        else if (!hasAnyPlayers)
          _buildMyPlayersEmptyState()
        else ...[
          _buildMyPlayersCarousel(managed, followed),
          if (managed.isEmpty && followed.isNotEmpty)
            _buildMyPlayersRegisterLink(),
        ],
      ],
    );
  }

  Widget _buildMyPlayersLoadingRow() {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, __) => Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withAlpha(10),
                border: Border.all(color: Colors.white.withAlpha(25)),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyPlayersRegisterLink() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: _openAddChildFlow,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Registrar jugador',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.brandTeal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyPlayersEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aún no tienes jugadores registrados',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: 'Registrar jugador',
              onPressed: _openAddChildFlow,
            ),
          ),
        ],
      ),
    );
  }

  static const double _playersCarouselHeight = 108;

  Widget _buildPlayersCarouselGroupTitle(String title) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Colors.white38,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildPlayersCarouselGroup({
    required String title,
    required List<Map<String, dynamic>> profiles,
    required bool isFollowed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildPlayersCarouselGroupTitle(title),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < profiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              _buildMyPlayersQuickItem({
                'profile': profiles[i],
                'isFollowed': isFollowed,
              }),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPlayersCarouselDivider({double height = _playersCarouselHeight}) {
    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          width: 2,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.white.withAlpha(70),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withAlpha(30),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyPlayersCarousel(
    List<Map<String, dynamic>> managed,
    List<Map<String, dynamic>> followed,
  ) {
    final managedPreview = managed.take(8).toList();
    final followedPreview = followed.take(8 - managedPreview.length).toList();
    final showDivider = managedPreview.isNotEmpty && followedPreview.isNotEmpty;

    final children = <Widget>[];

    if (managedPreview.isNotEmpty) {
      children.add(_buildPlayersCarouselGroup(
        title: 'Mis jugadores',
        profiles: managedPreview,
        isFollowed: false,
      ));
    }

    if (showDivider) {
      children.add(const SizedBox(width: 12));
      children.add(_buildPlayersCarouselDivider());
      children.add(const SizedBox(width: 12));
    }

    if (followedPreview.isNotEmpty) {
      children.add(_buildPlayersCarouselGroup(
        title: 'Siguiendo',
        profiles: followedPreview,
        isFollowed: true,
      ));
    }

    if (children.isNotEmpty) {
      children.add(const SizedBox(width: 16));
    }
    children.add(_buildMyPlayersViewAllCarouselItem());

    return SizedBox(
      height: _playersCarouselHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        clipBehavior: Clip.none,
        children: children,
      ),
    );
  }

  Widget _buildMyPlayersViewAllCarouselItem() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        _buildMyPlayersViewAllItem(),
      ],
    );
  }

  Widget _buildMyPlayersViewAllItem() {
    return GestureDetector(
      onTap: () => _openPlayersTab(playersSubTab: 0),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.brandTeal.withAlpha(55), width: 1),
                color: AppTheme.brandTeal.withAlpha(14),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ver todos',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.brandTeal,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppTheme.brandTeal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMyPlayersQuickItem(Map<String, dynamic> entry) {
    final profile = Map<String, dynamic>.from(entry['profile'] as Map);
    final isFollowed = entry['isFollowed'] == true;
    final firstName = _playerFirstName(profile, isFollowed: isFollowed);
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
    final photo = _resolveMediaUrl((profile['thumb'] ?? profile['photo'] ?? '').toString());
    final playerId = (profile['playerId'] ?? profile['id'] ?? '').toString();
    final pendingRequests = isFollowed ? 0 : _pendingAttentionCount(playerId);
    final needsIdentityValidation = !isFollowed &&
        profile['identity_status']?.toString() != 'verified' &&
        profile['identity_status']?.toString() != 'manual_review';
    final isManualReview = !isFollowed && _isManualReviewPlayer(profile);

    return GestureDetector(
      onTap: () => _openQuickPlayerEntry(entry),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isManualReview
                            ? const Color(0xFFFFD600).withAlpha(140)
                            : (needsIdentityValidation
                            ? Colors.redAccent.withAlpha(90)
                            : Colors.white.withAlpha(45)),
                        width: isManualReview || needsIdentityValidation ? 1.5 : 1,
                      ),
                      color: AppTheme.navyElevated,
                      image: photo.isNotEmpty
                          ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
                          : null,
                    ),
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAlias,
                    child: photo.isEmpty
                        ? Text(
                            initial,
                            style: GoogleFonts.oswald(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isFollowed ? Colors.white54 : Colors.white70,
                            ),
                          )
                        : null,
                  ),
                  if (isManualReview)
                    Positioned(
                      left: -3,
                      top: -3,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD600),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.navySurface, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          size: 11,
                          color: AppTheme.navyPrimary,
                        ),
                      ),
                    )
                  else if (needsIdentityValidation)
                    Positioned(
                      left: -3,
                      top: -3,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.navySurface, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.priority_high_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (pendingRequests > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD600),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppTheme.navySurface, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          pendingRequests > 9 ? '9+' : '$pendingRequests',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navyPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isFollowed ? FontWeight.w500 : FontWeight.w600,
                color: isFollowed ? Colors.white54 : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _tournamentParticipants(Map<String, dynamic> tournament) {
    final teams = tournament['teams'] as List<dynamic>? ?? [];
    final seen = <String>{};
    final participants = <Map<String, dynamic>>[];

    for (final rawTeam in teams) {
      if (rawTeam is! Map) continue;
      final players = rawTeam['players'] as List<dynamic>? ?? [];
      for (final rawPlayer in players) {
        if (rawPlayer is! Map) continue;
        final player = Map<String, dynamic>.from(rawPlayer);
        final id = (player['playerId'] ?? player['id'] ?? '').toString();
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        participants.add({
          'id': id,
          'name': (player['name'] ?? player['alias'] ?? '').toString(),
          'photo': _resolveMediaUrl((player['thumb'] ?? player['photo'] ?? '').toString()),
        });
      }
    }
    return participants;
  }

  Widget _buildTournamentParticipantAvatars(List<Map<String, dynamic>> participants) {
    if (participants.isEmpty) return const SizedBox.shrink();

    const double avatarSize = 30;
    const double overlap = 11;
    const int maxVisible = 5;
    final visible = participants.take(maxVisible).toList();
    final extra = participants.length - visible.length;
    final rowWidth = avatarSize + (visible.length - 1) * (avatarSize - overlap) + (extra > 0 ? 18 : 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: SizedBox(
        width: rowWidth,
        height: avatarSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < visible.length; i++)
              Positioned(
                right: i * (avatarSize - overlap),
                child: _tournamentParticipantAvatar(
                  visible[i],
                  size: avatarSize,
                ),
              ),
            if (extra > 0)
              Positioned(
                right: visible.length * (avatarSize - overlap),
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.brandTeal,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '+$extra',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tournamentParticipantAvatar(Map<String, dynamic> player, {required double size}) {
    final photo = (player['photo'] ?? '').toString();
    final name = (player['name'] ?? '').toString();
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    final isFollowed = player['relation'] == 'followed';
    final borderColor = isFollowed ? AppTheme.brandTeal : Colors.white;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
            color: const Color(0xFF161F2E),
            image: photo.isNotEmpty
                ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
                : null,
          ),
          child: photo.isEmpty
              ? Center(child: Text(initial, style: TextStyle(color: Colors.white70, fontSize: size * 0.45, fontWeight: FontWeight.bold)))
              : null,
        ),
        if (isFollowed)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppTheme.navySurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.brandTeal, width: 1),
              ),
              child: const Icon(Icons.star, color: Colors.yellowAccent, size: 8),
            ),
          ),
      ],
    );
  }

  Widget _buildCarouselTournamentCard(Map<String, dynamic> tournament, {Key? key}) {
    const cardWidth = 280.0;
    const cardHeight = 180.0;
    final participants = _tournamentParticipants(tournament);
    final String coverUrl = (tournament['img'] ?? '').toString();
    final String name = (tournament['name'] ?? 'Torneo').toString();
    final String subname = (tournament['subname'] ?? '').toString();
    final String startRaw = (tournament['start'] ?? '').toString();
    final String endRaw = (tournament['end'] ?? '').toString();

    // Parse dates
    final DateTime? startDt = DateTime.tryParse(startRaw);
    final DateTime? endDt = DateTime.tryParse(endRaw);
    final DateTime now = DateTime.now();

    String startDateLabel = '';
    if (startDt != null) {
      const months = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
      startDateLabel = '${startDt.day} ${months[startDt.month - 1]} ${startDt.year}';
    }

    // Determine status from dates
    String badgeText = '';
    Color badgeColor = AppTheme.brandTeal;
    if (startDt != null && endDt != null) {
      if (now.isAfter(startDt.subtract(const Duration(days: 1))) && now.isBefore(endDt.add(const Duration(days: 1)))) {
        badgeText = 'ACTIVO';
        badgeColor = const Color(0xFF4CAF50);
      } else if (now.isBefore(startDt)) {
        badgeText = 'PRÓXIMO';
        badgeColor = Colors.amber;
      }
    } else if (startDt != null) {
      if (now.isBefore(startDt)) {
        badgeText = 'PRÓXIMO';
        badgeColor = Colors.amber;
      } else {
        badgeText = 'ACTIVO';
        badgeColor = const Color(0xFF4CAF50);
      }
    }

    final String logoUrl = (tournament['logo'] ?? '').toString();

    return GestureDetector(
      onTap: () => _openTournamentDetail(tournament),
      child: SizedBox(
        key: key,
        width: cardWidth,
        height: cardHeight,
        child: Container(
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2A4A),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Portada ampliada (~20%) y recortada por el clip de la card
            if (coverUrl.isNotEmpty)
              Positioned.fill(
                child: Transform.scale(
                  scale: 1.2,
                  alignment: Alignment.center,
                  child: Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    width: cardWidth,
                    height: cardHeight,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: cardWidth,
                      height: cardHeight,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1C2A4A), Color(0xFF0F1629)],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              else
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1C2A4A), Color(0xFF0F1629)],
                      ),
                    ),
                  ),
                ),

            // Degradado para legibilidad del logo y textos
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.35, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),

            if (participants.isNotEmpty)
              Positioned(
                top: 10,
                right: 10,
                child: _buildTournamentParticipantAvatars(participants),
              ),

            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (logoUrl.isNotEmpty)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.emoji_events_outlined,
                          color: Color(0xFF1C2A4A),
                          size: 26,
                        ),
                      ),
                    ),
                  if (logoUrl.isNotEmpty) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (subname.isNotEmpty)
                          Text(
                            subname,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                              height: 1.15,
                              shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (subname.isNotEmpty) const SizedBox(height: 2),
                        Text(
                          name.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: subname.isNotEmpty ? 0.88 : 1),
                            fontSize: subname.isNotEmpty ? 12 : 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            height: 1.1,
                            shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (startDateLabel.isNotEmpty || badgeText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (badgeText.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: TextStyle(
                                      color: badgeColor.withValues(alpha: 0.95),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              if (badgeText.isNotEmpty && startDateLabel.isNotEmpty)
                                const SizedBox(width: 6),
                              if (startDateLabel.isNotEmpty) ...[
                                Icon(Icons.calendar_today_rounded, color: Colors.white.withValues(alpha: 0.65), size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  startDateLabel,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }

  List<Map<String, dynamic>> _activeTeamsForPlayer(dynamic profile, List<dynamic> activeTeams) {
    final playerId = (profile['playerId'] ?? profile['id'] ?? '').toString();
    if (playerId.isEmpty) return [];

    final teams = <Map<String, dynamic>>[];
    for (final raw in activeTeams) {
      if (raw is! Map) continue;
      final team = Map<String, dynamic>.from(raw);
      final playersInTeam = team['players'] as List<dynamic>? ?? [];
      final belongs = playersInTeam.any((pl) {
        if (pl is! Map) return false;
        final pid = (pl['playerId'] ?? pl['id'] ?? '').toString();
        return pid == playerId;
      });
      if (belongs) teams.add(team);
    }
    return teams;
  }


  Widget _buildPlayerTeamRow(Map<String, dynamic> team, String jerseyNumber) {
    final logoUrl = _resolveMediaUrl((team['logo'] ?? '').toString());
    final teamName = (team['name'] ?? 'Equipo').toString();
    final categoryName = (team['categoryName'] ?? team['category']?['name'] ?? 'S/C').toString().toUpperCase();
    final tournamentName = (team['tournamentName'] ?? team['tournament']?['name'] ?? 'Sin Torneo').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2738), // Lighter navy surface
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(20)),
              image: logoUrl.isNotEmpty
                  ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: logoUrl.isEmpty
                ? const Icon(Icons.shield_outlined, color: Colors.white38, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teamName,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      categoryName,
                      style: const TextStyle(color: AppTheme.brandTeal, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('•', style: TextStyle(color: Colors.white24, fontSize: 10)),
                    ),
                    Expanded(
                      child: Text(
                        tournamentName,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (jerseyNumber.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sports_esports_outlined, color: Colors.white.withAlpha(120), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '#$jerseyNumber',
                    style: GoogleFonts.oswald(
                      color: Colors.white.withAlpha(200),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _jerseyForTeamOnProfile(dynamic profile, Map<String, dynamic> team) {
    final teamId = (team['id'] ?? team['_id'] ?? '').toString();
    final profileTeams = profile['teams'] as List<dynamic>? ?? [];
    for (final raw in profileTeams) {
      if (raw is! Map) continue;
      final pt = Map<String, dynamic>.from(raw);
      final ptId = (pt['id'] ?? pt['_id'] ?? '').toString();
      if (ptId == teamId) {
        return (pt['number'] ?? pt['num'] ?? '').toString();
      }
    }
    return (profile['number'] ?? '').toString();
  }

  Widget _buildPlayerCard(dynamic p, List<dynamic> activeTeams) {
    final String playerId = (p['playerId'] ?? p['id'] ?? '').toString();
    final playerActiveTeams = _activeTeamsForPlayer(p, activeTeams);
    final String bgNumber = (p['number'] ?? '0').toString();
    final int pendingTeamRequests = _pendingRequestsByPlayer[playerId] ?? 0;
    final int pendingSelectivos = _pendingSelectivosByPlayer[playerId] ?? 0;
    final int pendingRequests = pendingTeamRequests + pendingSelectivos;
    final bool hasPendingRequests = pendingRequests > 0;
    final bool isIdentityVerified = (p['identity_status']?.toString() == 'verified');
    final bool isManualReview = _isManualReviewPlayer(p);

    return GestureDetector(
      onTap: () {
        if (isManualReview) {
          return;
        }
        if (!isIdentityVerified) {
          Navigator.of(context).pushNamed(
            AddChildPage.route,
            arguments: {
              'parentId': user['_id'],
              'parentName': "${user['name'] ?? ''} ${user['apellidoPa'] ?? ''}".trim(),
              'parentCurp': user['curp'],
              'parentApPa': user['apellidoPa'],
              'parentApMa': user['apellidoMa'],
              'child': p,
            },
          ).then((_) => loadFullProfile());
          return;
        }

        Navigator.of(context).pushNamed(
          PlayerDashboardRoute.routeFor(playerId),
          arguments: _managedPlayerDashboardArgs(
            Map<String, dynamic>.from(p as Map),
            verSolicitudes: hasPendingRequests ? 'true' : 'false',
          ),
        ).then((_) => loadFullProfile());
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF161F2E),
              hasPendingRequests ? const Color(0xFF1E2733) : const Color(0xFF1A2436),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasPendingRequests
                ? const Color(0xFFFFD600).withAlpha(100)
                : (isManualReview
                    ? const Color(0xFFFFD600).withAlpha(90)
                    : (!isIdentityVerified ? Colors.redAccent.withAlpha(80) : Colors.white.withAlpha(20))),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: hasPendingRequests 
                  ? const Color(0xFFFFD600).withAlpha(15) 
                  : (isManualReview
                      ? const Color(0xFFFFD600).withAlpha(15)
                      : (!isIdentityVerified ? Colors.redAccent.withAlpha(15) : const Color(0x33000000))),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Watermark Logo/Number
            Positioned(
              right: 15, // moved left to be more visible
              bottom: -15,
              child: Text(
                bgNumber,
                style: GoogleFonts.oswald(
                  fontSize: 150,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withAlpha(12), // slightly more visible
                  fontStyle: FontStyle.italic,
                  height: 1,
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(10),
                          border: Border.all(
                            color: hasPendingRequests || isManualReview
                                ? const Color(0xFFFFD600)
                                : (!isIdentityVerified ? Colors.redAccent : AppTheme.brandTeal),
                            width: 2.5,
                          ),
                          image: p['thumb'] != null && p['thumb'].toString().isNotEmpty
                              ? DecorationImage(image: NetworkImage(p['thumb']), fit: BoxFit.cover)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: hasPendingRequests || isManualReview
                                  ? const Color(0xFFFFD600).withAlpha(50)
                                  : (!isIdentityVerified ? Colors.redAccent.withAlpha(50) : AppTheme.brandTeal.withAlpha(40)),
                              blurRadius: 12,
                            )
                          ],
                        ),
                        child: (p['thumb'] == null || p['thumb'].toString().isEmpty)
                            ? const Icon(Icons.person, color: Colors.white70, size: 30)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      // Name & Status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (p['name'] ?? '').toString().toUpperCase(),
                              style: GoogleFonts.oswald(
                                color: Colors.white, 
                                fontSize: 24, 
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (hasPendingRequests)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFFFD600).withAlpha(40),
                                          const Color(0xFFFFD600).withAlpha(10),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFFD600).withAlpha(100)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.notifications_active_rounded, color: Color(0xFFFFD600), size: 12),
                                        const SizedBox(width: 6),
                                        Text(
                                          _pendingBadgeLabel(
                                            teamCount: pendingTeamRequests,
                                            selectivoCount: pendingSelectivos,
                                          ),
                                          style: const TextStyle(
                                            color: Color(0xFFFFD600),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (isManualReview)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFFFD600).withAlpha(40),
                                          const Color(0xFFFFD600).withAlpha(10),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFFD600).withAlpha(100)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.hourglass_top_rounded, color: Color(0xFFFFD600), size: 12),
                                        SizedBox(width: 6),
                                        Text(
                                          'EN REVISIÓN',
                                          style: TextStyle(
                                            color: Color(0xFFFFD600),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (!isIdentityVerified)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.redAccent.withAlpha(40),
                                          Colors.redAccent.withAlpha(10),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.redAccent.withAlpha(100)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.gpp_maybe_rounded, color: Colors.redAccent, size: 12),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'FALTA IDENTIDAD',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (isIdentityVerified && !hasPendingRequests)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.brandTeal.withAlpha(15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.brandTeal.withAlpha(40)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.verified_rounded, color: AppTheme.brandTeal, size: 12),
                                        const SizedBox(width: 6),
                                        Text(
                                          'AL DÍA',
                                          style: TextStyle(
                                            color: AppTheme.brandTeal.withAlpha(220),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isManualReview)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD600).withAlpha(20),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFD600).withAlpha(80)),
                          ),
                          child: const Icon(
                            Icons.hourglass_top_rounded,
                            color: Color(0xFFFFD600),
                            size: 16,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(10),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(20)),
                          ),
                          child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                        ),
                    ],
                  ),

                  if (isManualReview) ...[
                    const SizedBox(height: 16),
                    const _ManualReviewProgress(),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // --- EQUIPOS ---
                  Text(
                    'EQUIPOS',
                    style: GoogleFonts.oswald(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (playerActiveTeams.isEmpty)
                    const Text('No pertenece a ningún equipo', style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic))
                  else
                    ...playerActiveTeams.map((team) {
                      final teamMap = Map<String, dynamic>.from(team);
                      final jersey = _jerseyForTeamOnProfile(p, teamMap);
                      return _buildPlayerTeamRow(teamMap, jersey);
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



    Widget _buildPlayersTab() {
    final profiles = _managedProfiles();
    final activeTeams = dashboardData?['activeTeams'] as List<dynamic>? ?? [];
    final pendingRequests = (dashboardData?['coTutorship']?['pending'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jugadores',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 16),
        
        // --- CUSTOM SEGMENTED CONTROL ---
        Container(
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
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: _playersSubTab == 0 ? Alignment.centerLeft : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
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
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _playersSubTab = 0),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            fontFamily: GoogleFonts.inter().fontFamily,
                            color: _playersSubTab == 0 ? AppTheme.navyPrimary : AppTheme.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                          child: const Text('MIS JUGADORES'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _playersSubTab = 1),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            fontFamily: GoogleFonts.inter().fontFamily,
                            color: _playersSubTab == 1 ? AppTheme.navyPrimary : AppTheme.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                          child: const Text('SIGUIENDO'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // --- CONTENT VIEWS ---
        if (_playersSubTab == 0) ...[
          // VISTA: MIS JUGADORES
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gestionados por ti', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AddChildPage.route,
                    arguments: {
                      'parentId': user['_id'],
                      'parentName': "${user['name'] ?? ''} ${user['apellidoPa'] ?? ''}".trim(),
                      'parentCurp': user['curp'],
                      'parentApPa': user['apellidoPa'],
                      'parentApMa': user['apellidoMa'],
                    },
                  ).then((_) => loadFullProfile());
                },
                child: const Row(
                  children: [
                    Icon(Icons.add, color: AppTheme.brandTeal, size: 16),
                    SizedBox(width: 4),
                    Text('Agregar', style: TextStyle(color: AppTheme.brandTeal, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 16),

          if (profiles.where(_isManualReviewPlayer).isNotEmpty) ...[
            Text(
              'EN REVISIÓN MANUAL',
              style: GoogleFonts.oswald(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFFD600),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'El trámite ya está en curso. Un administrador está validando su identificación.',
              style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            ...profiles.where(_isManualReviewPlayer).map((p) => _buildPlayerCard(p, activeTeams)),
            const SizedBox(height: 28),
          ],
          
          if (profiles.isEmpty && pendingRequests.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('Aún no tienes jugadores gestionados.', style: TextStyle(color: Colors.white54)),
              ),
            )
          else
            ...profiles.where((p) => !_isManualReviewPlayer(p)).map((p) => _buildPlayerCard(p, activeTeams)),
          
          if (pendingRequests.isNotEmpty) ...[
            if (profiles.isNotEmpty) const SizedBox(height: 32),
            Text(
              'SOLICITUDES ENVIADAS',
              style: GoogleFonts.oswald(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            ...pendingRequests.map((req) => _buildPendingCoTutorCard(req)),
          ],
        ] else ...[
          // VISTA: SIGUIENDO
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => SearchPlayerSheet(
                  api: widget.api,
                  userId: user['_id'],
                ),
              ).then((reloaded) async {
                if (reloaded == true) {
                  _showModernLoader();
                  await loadFullProfile();
                  if (mounted) Navigator.of(context).pop();
                }
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.brandTeal.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.brandTeal.withAlpha(80)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_search, color: AppTheme.brandTeal, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'BUSCAR JUGADORES',
                    style: GoogleFonts.oswald(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.brandTeal, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Builder(
            builder: (ctx) {
              final followedPlayers = (dashboardData?['following']?['players'] as List<dynamic>?) ?? [];
              
              if (followedPlayers.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(10), style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.group_outlined, color: Colors.white38, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Aún no sigues a nadie',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Usa el botón de búsqueda arriba para encontrar jugadores y mantenerte al día con sus partidos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: followedPlayers.map((fp) => _buildFollowedPlayerCard(fp)).toList(),
              );
            }
          ),
        ],
      ],
    );
  }

  Widget _buildFollowedPlayerCard(dynamic fp) {
    if (fp == null) return const SizedBox.shrink();
    final name = fp['fullName']?.toString().isNotEmpty == true ? fp['fullName'] : fp['userName']?.toString() ?? 'Jugador';
    final photo = _resolveMediaUrl((fp['thumb'] ?? fp['photo'] ?? '').toString());
    final prefs = fp['preferences'] as Map<String, dynamic>? ?? {};
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openFollowedPlayerProfile(Map<String, dynamic>.from(fp as Map)),
          child: Stack(
            children: [
              if ((fp['number']?.toString() ?? '').isNotEmpty)
                Positioned(
                  right: -10,
                  bottom: -15,
                  child: Text(
                    '#${fp['number']}',
                    style: GoogleFonts.oswald(
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withAlpha(5),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.brandTeal, width: 2),
                        image: photo.isNotEmpty
                            ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
                            : null,
                      ),
                      child: photo.isEmpty ? const Icon(Icons.person, color: AppTheme.brandTeal, size: 32) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.oswald(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((fp['alias']?.toString() ?? '').isNotEmpty)
                            Text(
                              '"${fp['alias']}"',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.brandTeal,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (prefs['matches'] == true) _buildFollowBadge(Icons.sports_football, 'Partidos'),
                              if (prefs['stats'] == true) _buildFollowBadge(Icons.bar_chart, 'Stats'),
                              if (prefs['news'] == true) _buildFollowBadge(Icons.article, 'Noticias'),
                            ],
                          )
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white54),
                      color: AppTheme.navyPrimary,
                      onSelected: (val) {
                        if (val == 'unfollow') _confirmUnfollowPlayer(fp);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'unfollow',
                          child: Row(
                            children: [
                              Icon(Icons.person_remove, color: Colors.redAccent, size: 20),
                              SizedBox(width: 8),
                              Text('Dejar de seguir', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFollowBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPendingCoTutorCard(dynamic req) {
    if (req is! Map) return const SizedBox.shrink();
    
    final name = req['fullName']?.toString().isNotEmpty == true 
        ? req['fullName'] 
        : req['name']?.toString() ?? 'Jugador';
    final curp = req['curp']?.toString() ?? '';
    final photo = _resolveMediaUrl((req['thumb'] ?? req['photo'] ?? '').toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF1E2738),
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty ? const Icon(Icons.person, color: Colors.white54, size: 28) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.publicSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (curp.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'CURP: $curp',
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final mood = int.tryParse(req['mood']?.toString() ?? '0') ?? 0;
                    IconData icon = Icons.access_time_rounded;
                    Color color = Colors.orangeAccent;
                    String text = 'Esperando aprobación';

                    if (mood == 2) {
                      icon = Icons.cancel_rounded;
                      color = Colors.redAccent;
                      text = 'Solicitud rechazada';
                    } else if (mood == 3) {
                      icon = Icons.block_rounded;
                      color = Colors.redAccent;
                      text = 'Cancelada';
                    }

                    return Row(
                      children: [
                        Icon(icon, color: color, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          text,
                          style: GoogleFonts.publicSans(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ],
            ),
          ),
          Builder(builder: (context) {
            final mood = int.tryParse(req['mood']?.toString() ?? '0') ?? 0;
            if (mood != 0) return const SizedBox.shrink();
            final reqId = (req['requestId'] ?? '').toString();
            final isCancelling = _cancellingCoTutorIds.contains(reqId);
            
            return IconButton(
              icon: isCancelling 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                  : const Icon(Icons.close_rounded, color: Colors.white54),
              onPressed: isCancelling ? null : () => _cancelCoTutorRequest(Map<String, dynamic>.from(req as Map)),
              tooltip: 'Cancelar solicitud',
            );
          }),
        ],
      ),
    );
  }

  final Set<String> _cancellingCoTutorIds = {};

  Future<void> _cancelCoTutorRequest(Map<String, dynamic> req) async {
    final reqId = (req['requestId'] ?? '').toString();
    if (reqId.isEmpty) return;
    
    setState(() => _cancellingCoTutorIds.add(reqId));
    try {
      final resp = await widget.api.cancelCoTutorshipRequest(
        uid: user['_id']?.toString() ?? '',
        requestId: reqId,
        playerId: req['playerId']?.toString() ?? req['id']?.toString() ?? '',
      );
      if (resp['ok'] == true || resp['status'] != 'error') {
        if (mounted) {
          _toast('Solicitud cancelada');
          await loadFullProfile();
        }
      } else {
        if (mounted) _toast(resp['message']?.toString() ?? 'Error al cancelar la solicitud', isError: true);
      }
    } catch (e) {
      if (mounted) _toast('Error al cancelar la solicitud', isError: true);
    } finally {
      if (mounted) setState(() => _cancellingCoTutorIds.remove(reqId));
    }
  }

  Widget _buildCalendarTab() {
    return PlayerTournamentMatchesPanel(
      dashboard: dashboardData,
      isLoading: isLoading,
      matchesStore: _matchesStore,
      resolveMediaUrl: _resolveMediaUrl,
      onMatchTap: _openMatchDetail,
    );
  }

  String _sessionFirebaseUid() {
    final fromUser = (user['uid'] ?? user['firebase_uid'] ?? '').toString().trim();
    if (fromUser.isNotEmpty) return fromUser;
    final id = (user['_id'] ?? user['id'] ?? '').toString().trim();
    if (id.startsWith('user:')) return id.substring(5);
    return id;
  }

  String? _formatProfileDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final dt = DateTime.tryParse(raw.trim());
    if (dt == null) return raw.trim();
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _identityStatusLabel(String? status) {
    switch ((status ?? '').toString().toLowerCase()) {
      case 'verified':
        return 'Verificada';
      case 'pending':
      case 'in_review':
      case 'manual_review':
        return 'En revisión';
      case 'rejected':
        return 'Rechazada';
      default:
        return 'Pendiente';
    }
  }

  Widget _profileSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _profileStatusChip({required String label, required bool ok}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (ok ? const Color(0xFF4CAF50) : Colors.orangeAccent).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (ok ? const Color(0xFF4CAF50) : Colors.orangeAccent).withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ok ? const Color(0xFF81C784) : Colors.orangeAccent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _profileInfoRow({
    required String label,
    required String value,
    IconData? icon,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white38, size: 18),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final identityStatus = (user['identity_status'] ?? '').toString();
    final isIdentityVerified = identityStatus.toLowerCase() == 'verified';
    final emailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    final expiresRaw = user['verification_expires_at']?.toString();
    final expiresLabel = _formatProfileDate(expiresRaw);
    final registeredRaw = (user['sd'] ?? user['created_at'] ?? user['registered_at'] ?? '').toString();
    final registeredLabel = _formatProfileDate(registeredRaw) ?? '—';
    final phone = (user['tel'] ?? user['phone'] ?? '').toString();
    final mail = (user['mail'] ?? '').toString();
    final rolesList = <String>[];
    final rolesMap = roles;
    if (rolesMap['isTutor'] == true) rolesList.add('Tutor');
    if (rolesMap['isPlayer'] == true) rolesList.add('Jugador');
    if (rolesMap['isCoach'] == true) rolesList.add('Coach');
    final rolesLabel = rolesList.isEmpty ? '—' : rolesList.join(' · ');

    String? vigenciaDetail;
    if (isIdentityVerified && expiresRaw != null && expiresRaw.isNotEmpty) {
      final exp = DateTime.tryParse(expiresRaw);
      if (exp != null) {
        final daysLeft = exp.difference(DateTime.now()).inDays;
        if (daysLeft < 0) {
          vigenciaDetail = 'Vencida';
        } else if (daysLeft == 0) {
          vigenciaDetail = 'Vence hoy';
        } else {
          vigenciaDetail = '$daysLeft día${daysLeft == 1 ? '' : 's'} restantes';
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mi Perfil',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            Text(
              'v1.0.1',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: (user['avatar'] ?? '').toString().isEmpty
                    ? null
                    : NetworkImage(user['avatar'].toString()),
                child: (user['avatar'] ?? '').toString().isEmpty
                    ? const Icon(Icons.person, size: 40, color: Colors.white54)
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                (user['name'] ?? 'Sin nombre').toString(),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              if (mail.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  mail,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _profileSectionTitle('Cuenta'),
              _profileInfoRow(
                label: 'Correo electrónico',
                value: mail,
                icon: Icons.mail_outline_rounded,
                trailing: _profileStatusChip(
                  label: emailVerified ? 'Verificado' : 'Sin verificar',
                  ok: emailVerified,
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              _profileInfoRow(
                label: 'Teléfono',
                value: phone,
                icon: Icons.phone_outlined,
              ),
              const Divider(color: Colors.white12, height: 1),
              _profileInfoRow(
                label: 'Fecha de registro',
                value: registeredLabel,
                icon: Icons.event_available_outlined,
              ),
            ],
          ),
        ),

        GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _profileSectionTitle('Roles en la app'),
              _profileInfoRow(
                label: 'Perfiles activos',
                value: rolesLabel,
                icon: Icons.badge_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              await widget.storage.remove(AppConfig.sessionKey);
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(LoginPage.route, (_) => false);
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'CERRAR SESIÓN',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
// (Fin del archivo)
}

// ... Reutilizamos la misma capa de marcas del login para textura
class _FieldMarkings extends StatelessWidget {
  const _FieldMarkings({required this.isDesktop});
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _FieldPainter(isDesktop: isDesktop),
    );
  }
}

class _FieldPainter extends CustomPainter {
  _FieldPainter({required this.isDesktop});
  final bool isDesktop;

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = isDesktop ? 2.0 : 1.0;
    final double fontSize = isDesktop ? 80.0 : 40.0;

    double startY = size.height * 0.12;
    double endY = size.height * 0.88;
    double fieldHeight = endY - startY;
    double spacing = fieldHeight / 10;

    for (int i = 0; i <= 10; i++) {
      double y = startY + (i * spacing);
      bool isEndZone = (i == 0 || i == 10);
      bool isMid = (i == 5);

      // Líneas con gradiente (estilo moderno/gamer que se desvanece a los lados)
      final linePaint = Paint()
        ..strokeWidth = isEndZone || isMid ? strokeWidth * 1.5 : strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            AppTheme.textPrimary.withValues(alpha: isEndZone || isMid ? 0.2 : 0.08),
            AppTheme.textPrimary.withValues(alpha: isEndZone || isMid ? 0.2 : 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.1, 0.9, 1.0],
        ).createShader(Rect.fromLTWH(0, y, size.width, strokeWidth));

      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

      // Marcas hash sutiles entre líneas
      if (i < 10) {
        final hashPaint = Paint()
          ..color = AppTheme.textPrimary.withValues(alpha: 0.04)
          ..strokeWidth = 1.0;
        double hashY = y + (spacing / 2);
        canvas.drawLine(Offset(size.width * 0.35, hashY), Offset(size.width * 0.38, hashY), hashPaint);
        canvas.drawLine(Offset(size.width * 0.62, hashY), Offset(size.width * 0.65, hashY), hashPaint);
      }

      int yardNum = i * 10;
      if (yardNum > 50) yardNum = 100 - yardNum;

      if (yardNum > 0) {
        // Fuentes con delineado (stroke) estilo e-sports/gamer
        final textSpanStyle = GoogleFonts.oswald(
          fontSize: isMid ? fontSize * 1.4 : fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isMid ? 2.0 : 1.2
            ..color = isMid 
                ? AppTheme.brandTeal.withValues(alpha: 0.25)
                : AppTheme.textPrimary.withValues(alpha: 0.1),
        );

        final textSpan = TextSpan(
          text: isMid ? 'TP' : yardNum.toString(),
          style: textSpanStyle,
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        if (isMid) {
          canvas.save();
          canvas.translate(size.width / 2, y);
          canvas.rotate(-1.5708);
          textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
          canvas.restore();
        } else {
          // Lado Izquierdo
          canvas.save();
          canvas.translate(size.width * 0.12, y);
          canvas.rotate(-1.5708);
          textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
          canvas.restore();

          // Lado Derecho
          canvas.save();
          canvas.translate(size.width * 0.88, y);
          canvas.rotate(1.5708);
          textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ManualReviewProgress extends StatelessWidget {
  const _ManualReviewProgress();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.hourglass_top_rounded,
              size: 15,
              color: Color(0xFFFFD600),
            ),
            const SizedBox(width: 8),
            Text(
              'En proceso de revisión',
              style: GoogleFonts.inter(
                color: const Color(0xFFFFD600),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 0.55,
            minHeight: 5,
            backgroundColor: const Color(0xFFFFD600).withAlpha(28),
            color: const Color(0xFFFFD600),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _step(
              done: true,
              current: false,
              icon: Icons.check_circle_rounded,
              label: 'Enviado',
            ),
            const Expanded(child: _ManualReviewConnector(active: true)),
            _step(
              done: false,
              current: true,
              icon: Icons.hourglass_top_rounded,
              label: 'En revisión',
            ),
            const Expanded(child: _ManualReviewConnector(active: false)),
            _step(
              done: false,
              current: false,
              icon: Icons.verified_outlined,
              label: 'Validación',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Ya está siendo atendida. El perfil se actualizará al validarse.',
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _step({
    required bool done,
    required bool current,
    required IconData icon,
    required String label,
  }) {
    final Color color = done || current
        ? const Color(0xFFFFD600)
        : Colors.white38;
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ManualReviewConnector extends StatelessWidget {
  const _ManualReviewConnector({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 16, left: 6, right: 6),
      color: active ? const Color(0xFFFFD600).withAlpha(120) : Colors.white12,
    );
  }
}
