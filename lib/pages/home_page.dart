import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';
import '../services/toast_service.dart';
import 'add_child_page.dart';
import 'login_page.dart';
import 'player_dashboard_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.storage,
    required this.pushService,
    required this.socketService,
  });

  static const String route = '/home';

  final ApiService api;
  final StorageService storage;
  final PushNotificationService pushService;
  final SocketService socketService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _animDuration = Duration(milliseconds: 280);
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
  StreamSubscription<dynamic>? _requestSub;

  bool showPlayerForm = false;
  final numberCtrl = TextEditingController();
  final positionsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadFullProfile();
  }

  @override
  void dispose() {
    _requestSub?.cancel();
    numberCtrl.dispose();
    positionsCtrl.dispose();
    super.dispose();
  }

  Future<void> loadFullProfile() async {
    setState(() => isLoading = true);
    final session = await widget.storage.getJson(AppConfig.sessionKey);
    if (session == null || session['uid'] == null) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(LoginPage.route, (_) => false);
      return;
    }

    try {
      final res = await widget.api.getUserContext(session['uid'].toString());
      if (res['status'] == 'ok') {
        user = {...user, ...(res['user'] as Map<String, dynamic>? ?? {})};
        roles = (res['roles'] as Map<String, dynamic>?) ?? roles;
        myChildren = (res['children'] as List<dynamic>?) ?? [];
        playerProfile = (res['myPlayerProfile'] as Map<String, dynamic>?) ?? playerProfile;

        final hasToken = (res['user']?['fcm_token'] ?? '').toString().isNotEmpty;
        mostrarBotonPush = !hasToken;

        if (hasToken && (session['fcm_token'] == null || session['fcm_token'].toString().isEmpty)) {
          session['fcm_token'] = res['user']['fcm_token'];
          await widget.storage.setJson(AppConfig.sessionKey, session);
        }

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
          if ((user['avatar'] ?? '').toString().isEmpty) currentStep = 0;
        }

        _watchSocketRequests();
      }
    } catch (_) {
      _toast('Error de conexión', isError: true);
    }

    if (mounted) setState(() => isLoading = false);
  }

  void _watchSocketRequests() {
    final playerId = user['_id']?.toString();
    if (playerId == null || playerId.isEmpty) return;
    _requestSub ??= widget.socketService.watchRequests(playerId).listen((data) {
      _toast('Actualización en solicitudes recibida');
    });
  }

  Future<void> takeSelfieStep1() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
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
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
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
        if (match) {
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

  Future<void> activarAvisos() async {
    final token = await widget.pushService.inicializarNotificaciones();
    if (token == null) {
      _toast('No se pudieron activar las notificaciones', isError: true);
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
    ToastService.show(context, msg, isError: isError);
  }

  void _setLoading(bool value) {
    if (mounted) setState(() => isLoading = value);
  }

  InputDecoration _inputStyle(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, size: 18),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.black, width: 1.2),
      ),
    );
  }

  String _statusLabel() {
    if (currentStep < 2) return 'Verificación pendiente';
    if (isLocked && expirationDate != null) {
      return 'Vigente hasta ${expirationDate!.day}/${expirationDate!.month}/${expirationDate!.year}';
    }
    return 'Perfil verificado';
  }

  Widget _buildTabContent() {
    Widget general = Column(
      key: const ValueKey('general-tab'),
      children: [
        if (currentStep < 2) ...[
          AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completa tu validación (${currentStep + 1}/2)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (currentStep == 0)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: takeSelfieStep1,
                    child: const Text('Tomar selfie'),
                  ),
                if (currentStep == 1)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: uploadIdStep2,
                    child: const Text('Subir identificación'),
                  ),
              ],
            ),
          ),
        ] else ...[
          AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              value: showSecurityDetails,
              onChanged: (v) => setState(() => showSecurityDetails = v),
              title: const Text('Seguridad de cuenta'),
              subtitle: Text(
                isLocked && expirationDate != null
                    ? 'Vigente hasta ${expirationDate!.toLocal()}'
                    : 'Verificada',
              ),
            ),
          ),
        ],
        if (mostrarBotonPush)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: activarAvisos,
              child: const Text('Activar avisos push'),
            ),
          ),
        const SizedBox(height: 8),
        if (!(roles['isPlayer'] == true))
          AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Activar perfil de jugador'),
                const SizedBox(height: 8),
                if (!showPlayerForm)
                  FilledButton(
                    onPressed: () => setState(() => showPlayerForm = true),
                    child: const Text('Activar ahora'),
                  ),
                AnimatedCrossFade(
                  duration: _animDuration,
                  crossFadeState:
                      showPlayerForm ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  firstChild: Column(
                    children: [
                      TextField(
                        controller: numberCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputStyle('Número', icon: Icons.tag),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: positionsCtrl,
                        decoration: _inputStyle(
                          'Posiciones (separadas por coma)',
                          icon: Icons.sports,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: createPlayerProfile,
                        child: const Text('Guardar perfil'),
                      ),
                    ],
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );

    Widget seguridad = Column(
      key: const ValueKey('seguridad-tab'),
      children: [
        AnimatedContainer(
          duration: _animDuration,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SwitchListTile(
            value: showSecurityDetails,
            onChanged: (v) => setState(() => showSecurityDetails = v),
            title: const Text('Seguridad de cuenta'),
            subtitle: Text(_statusLabel()),
          ),
        ),
        if (mostrarBotonPush)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: OutlinedButton(
              onPressed: activarAvisos,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                minimumSize: const Size.fromHeight(46),
              ),
              child: const Text('Activar avisos push'),
            ),
          ),
      ],
    );

    Widget familia = Column(
      key: const ValueKey('familia-tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mis hijos', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.of(context).pushNamed(
              AddChildPage.route,
              arguments: {'parentId': user['_id']?.toString() ?? ''},
            );
            if (mounted) {
              await loadFullProfile();
            }
          },
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Registrar jugador'),
        ),
        const SizedBox(height: 8),
        if (myChildren.isEmpty)
          AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('Aun no hay perfiles infantiles vinculados.'),
          ),
        ...myChildren.map(
          (child) => AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              title: Text((child['name'] ?? 'Sin nombre').toString()),
              subtitle: Text((child['identity_status'] ?? 'sin estado').toString()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final status = (child['identity_status'] ?? '').toString();
                if (status == 'verified') {
                  await Navigator.of(context).pushNamed(
                    PlayerDashboardPage.route,
                    arguments: {
                      'playerId': child['_id']?.toString(),
                      'playerName': child['name']?.toString(),
                      'verSolicitudes': 'false',
                    },
                  );
                  if (mounted) await loadFullProfile();
                  return;
                }
                await Navigator.of(context).pushNamed(
                  AddChildPage.route,
                  arguments: {
                    'parentId': user['_id']?.toString() ?? '',
                    'prefillCurp': child['curp']?.toString(),
                    'playerId': child['_id']?.toString(),
                    'playerName': child['name']?.toString(),
                    'child': Map<String, dynamic>.from(child as Map),
                  },
                );
                if (mounted) {
                  await loadFullProfile();
                }
              },
            ),
          ),
        ),
      ],
    );

    if (currentTab == 'seguridad') return seguridad;
    if (currentTab == 'familia') return familia;
    return general;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadFullProfile,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                        onPressed: loadFullProfile,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Home',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusLabel(),
                    style: const TextStyle(color: Color(0xFF646C76), fontSize: 14),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
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
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (user['mail'] ?? '').toString(),
                                style: const TextStyle(color: Color(0xFF727983)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: currentStep < 2 ? const Color(0xFFFFF3E0) : const Color(0xFFE9F7EF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            currentStep < 2 ? 'Pendiente' : 'Activo',
                            style: TextStyle(
                              color: currentStep < 2 ? const Color(0xFFD9822B) : const Color(0xFF1F8F4D),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
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
                      ButtonSegment(value: 'seguridad', label: Text('Seguridad')),
                      ButtonSegment(value: 'familia', label: Text('Familia')),
                    ],
                    selected: {currentTab},
                    onSelectionChanged: (value) => setState(() => currentTab = value.first),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: _animDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final offsetAnimation = Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: offsetAnimation, child: child),
                      );
                    },
                    child: _buildTabContent(),
                  ),
                ],
              ),
            ),
    );
  }
}
