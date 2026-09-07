import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_config.dart';
import '../firebase_config.dart';
import 'api_service.dart';
import 'player_dashboard_route.dart';
import 'storage_service.dart';
import 'toast_service.dart';

/// Payload típico del backend Tochito Pro (FCM data).
class PushNotificationAction {
  const PushNotificationAction({
    required this.playerId,
    required this.playerName,
    this.openRequests = false,
    this.openTeamsTab = false,
    this.rawType = '',
  });

  final String playerId;
  final String playerName;
  final bool openRequests;
  final bool openTeamsTab;
  final String rawType;

  bool get hasPlayerTarget => playerId.isNotEmpty;
}

class PushInitResult {
  const PushInitResult({this.token, this.error});

  final String? token;
  final String? error;

  bool get ok => token != null && token!.isNotEmpty;
}

typedef PushForegroundHandler = void Function(PushNotificationAction action);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: FirebaseConfig.options);
}

class PushNotificationService {
  PushNotificationService({
    required this.apiService,
    required this.storageService,
    required this.navigatorKey,
  });

  final ApiService apiService;
  final StorageService storageService;
  final GlobalKey<NavigatorState> navigatorKey;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _initialized = false;
  bool _listenersAttached = false;
  PushForegroundHandler? _foregroundHandler;
  String? _lastSyncError;

  static const String _vapidKey =
      'BCAPjY-JSAZld57m31TM6VZzc5RpC3QAJyToRoEeCGb4cYjIxscF550UBFIWXgzB3D0CYmlIp4e2mZcHWLk8ueU';

  String? get lastSyncError => _lastSyncError;

  void setForegroundHandler(PushForegroundHandler? handler) {
    _foregroundHandler = handler;
  }

  /// Solicita permisos, registra token en backend y escucha mensajes.
  Future<PushInitResult> ensureInitialized({bool force = false}) async {
    _lastSyncError = null;

    if (_initialized && !force) {
      final existing = await _getFcmToken();
      if (existing != null && existing.isNotEmpty) {
        final sync = await _syncTokenToServer(existing);
        return PushInitResult(token: existing, error: sync.ok ? null : sync.error);
      }
    }

    try {
      if (!FirebaseConfig.isConfiguredForCurrentPlatform) {
        return const PushInitResult(
          error:
              'Firebase está configurado solo para Web. Ejecuta: flutterfire configure',
        );
      }

      final permissionOk = await _requestPlatformPermissions();
      if (!permissionOk) {
        return const PushInitResult(
          error: 'Permiso de notificaciones denegado en el dispositivo',
        );
      }

      if (!kIsWeb) {
        await _messaging.setAutoInitEnabled(true);
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      if (kIsWeb) {
        // Espera a que index.html registre firebase-messaging-sw.js
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }

      final token = await _getFcmToken();
      if (token == null || token.isEmpty) {
        return PushInitResult(
          error: kIsWeb
              ? 'No se obtuvo token FCM en el navegador. Permite notificaciones y usa HTTPS (PWA).'
              : 'No se obtuvo token FCM. Revisa google-services.json / GoogleService-Info.plist y APNs en Firebase',
        );
      }

      final sync = await _syncTokenToServer(token);
      if (!sync.ok) {
        return PushInitResult(token: token, error: sync.error);
      }

      if (kIsWeb) {
        final verify = await _verifyTokenOnServer(token);
        if (!verify.ok) {
          return PushInitResult(token: token, error: verify.error);
        }
      }

      _initialized = true;
      _attachListeners();
      _messaging.onTokenRefresh.listen((refreshed) async {
        await _syncTokenToServer(refreshed);
      });

      if (kDebugMode) {
        // ignore: avoid_print
        print('FCM OK: token ${token.length} chars, listeners activos');
      }

      return PushInitResult(token: token);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Push init error: $e');
      }
      return PushInitResult(error: e.toString());
    }
  }

  /// Alias usado en Home (activar avisos manualmente).
  Future<PushInitResult> inicializarNotificaciones({bool force = false}) =>
      ensureInitialized(force: force);

  Future<String?> _getFcmToken() {
    return _messaging.getToken(vapidKey: kIsWeb ? _vapidKey : null);
  }

  Future<bool> _requestPlatformPermissions() async {
    if (kIsWeb) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      final result = await Permission.notification.request();
      return result.isGranted;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> handleLaunchNotification() async {
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.queryParameters['push'] == '1') {
        navigateByPayload(Map<String, dynamic>.from(uri.queryParameters));
        return;
      }
    }

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleMessage(initial, fromTap: true);
    }
  }

  void _attachListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    FirebaseMessaging.onMessage.listen((message) {
      _handleMessage(message, fromTap: false);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleMessage(message, fromTap: true);
    });
  }

  /// Comprueba que CouchDB guardó el mismo token que usa FCM en el navegador.
  Future<({bool ok, String? error})> _verifyTokenOnServer(String localToken) async {
    final session = await storageService.getJson(AppConfig.sessionKey);
    final uid = session?['uid']?.toString();
    if (uid == null || uid.isEmpty) {
      return (ok: true, error: null);
    }

    try {
      final res = await apiService.getUserContextV2(uid);
      final serverToken = (res['user']?['fcm_token'] ?? res['fcm_token'] ?? '')
          .toString()
          .trim();
      if (serverToken.isEmpty) {
        return (
          ok: false,
          error:
              'El servidor no tiene fcm_token en tu usuario. Revisa el endpoint saveFcmToken en Node.',
        );
      }
      if (serverToken != localToken) {
        if (kDebugMode) {
          // ignore: avoid_print
          print(
            'FCM mismatch local=${localToken.substring(0, 12)}... '
            'server=${serverToken.substring(0, 12)}...',
          );
        }
        return (
          ok: false,
          error:
              'El token en el servidor no coincide con el del navegador. Vuelve a activar avisos.',
        );
      }
      return (ok: true, error: null);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FCM verify skip: $e');
      }
      return (ok: true, error: null);
    }
  }

  Future<({bool ok, String? error})> _syncTokenToServer(String token) async {
    final session = await storageService.getJson(AppConfig.sessionKey);
    final userId = session?['id']?.toString();
    if (userId == null || userId.isEmpty) {
      _lastSyncError = 'Sesión sin user id';
      return (ok: false, error: _lastSyncError);
    }

    try {
      final res = await apiService.saveFcmToken(userId: userId, fcmToken: token);
      if (!_isSaveTokenSuccess(res)) {
        _lastSyncError = (res['message'] ?? 'saveFcmToken rechazado').toString();
        if (kDebugMode) {
          // ignore: avoid_print
          print('saveFcmToken respuesta: $res');
        }
        return (ok: false, error: _lastSyncError);
      }

      session?['fcm_token'] = token;
      await storageService.setJson(AppConfig.sessionKey, session!);
      _lastSyncError = null;
      return (ok: true, error: null);
    } catch (e) {
      _lastSyncError = e.toString();
      if (kDebugMode) {
        // ignore: avoid_print
        print('saveFcmToken error: $e');
      }
      return (ok: false, error: _lastSyncError);
    }
  }

  void _handleMessage(RemoteMessage message, {required bool fromTap}) {
    final action = parsePayload(message.data);
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        'Push recibido (${fromTap ? 'tap' : 'foreground'}): '
        '${action.rawType} data=${message.data}',
      );
    }

    if (fromTap) {
      navigate(action);
      return;
    }

    _foregroundHandler?.call(action);
    _showForegroundBanner(message, action);
  }

  static PushNotificationAction parsePayload(Map<String, dynamic> data) {
    final normalized = <String, dynamic>{};
    data.forEach((key, value) {
      normalized[key.toString()] = value;
    });

    final playerId = (normalized['playerId'] ??
            normalized['player_id'] ??
            normalized['childId'] ??
            normalized['child_id'] ??
            '')
        .toString()
        .trim();

    final playerName = (normalized['playerName'] ??
            normalized['player_name'] ??
            normalized['name'] ??
            'Jugador')
        .toString()
        .trim();

    final tipo = (normalized['tipo'] ?? normalized['type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    final isTeamAssignment = tipo == 'team_assignment' ||
        tipo == 'new_team' ||
        _isTruthy(normalized['verEquipos']);

    final isSelectivo = tipo.contains('selectivo') ||
        tipo.contains('selection') ||
        tipo.contains('consent') ||
        tipo.contains('pending_consent') ||
        _isTruthy(normalized['verSelectivos']);

    final openRequests = !isTeamAssignment &&
        (_isTruthy(normalized['verSolicitudes']) ||
            _isTruthy(normalized['openRequests']) ||
            tipo.contains('request') ||
            tipo.contains('solicitud') ||
            isSelectivo);

    final openTeamsTab = isTeamAssignment || _isTruthy(normalized['verEquipos']);

    return PushNotificationAction(
      playerId: playerId,
      playerName: playerName.isEmpty ? 'Jugador' : playerName,
      openRequests: openRequests,
      openTeamsTab: openTeamsTab,
      rawType: tipo,
    );
  }

  static bool _isSaveTokenSuccess(Map<String, dynamic> res) {
    final status = res['status']?.toString().toLowerCase();
    if (status == 'ok' || status == 'success') return true;
    // Sin campo status pero HTTP 200 con mensaje de éxito
    if (status == null && res['message'] != null) {
      final msg = res['message'].toString().toLowerCase();
      if (msg.contains('actualizado') || msg.contains('guardado')) return true;
    }
    return false;
  }

  static bool _isTruthy(dynamic value) {
    if (value == true || value == 1) return true;
    final text = value?.toString().toLowerCase().trim() ?? '';
    return text == 'true' || text == '1' || text == 'yes' || text == 'si';
  }

  bool _isOnPlayerDashboard() {
    final context = navigatorKey.currentContext;
    if (context == null) return false;
    final name = ModalRoute.of(context)?.settings.name ?? '';
    return name.contains('jugador');
  }

  Future<void> _showForegroundBanner(
    RemoteMessage message,
    PushNotificationAction action,
  ) async {
    if (_isOnPlayerDashboard()) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final title = message.notification?.title ?? _titleForAction(action);
    final body = message.notification?.body ?? _bodyForAction(action);

    final messenger = ToastService.rootMessengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        backgroundColor: const Color(0xFF1C2A4A),
        content: Text('$title\n$body'),
        action: SnackBarAction(
          label: 'Ver',
          textColor: const Color(0xFF3BD0AE),
          onPressed: () => navigate(action),
        ),
      ),
    );
  }

  static String _titleForAction(PushNotificationAction action) {
    if (action.rawType.contains('selectivo') ||
        action.rawType.contains('selection') ||
        action.rawType.contains('consent')) {
      return 'Convocatoria a selectivo';
    }
    if (action.openRequests) return 'Nueva solicitud';
    if (action.openTeamsTab) return 'Actualización de equipo';
    return 'Aviso Tochito Pro';
  }

  static String _bodyForAction(PushNotificationAction action) {
    if (action.rawType.contains('selectivo') ||
        action.rawType.contains('selection') ||
        action.rawType.contains('consent')) {
      return '${action.playerName} tiene una convocatoria pendiente de tu consentimiento';
    }
    if (action.openRequests) {
      return 'Hay novedades en las solicitudes de ${action.playerName}';
    }
    if (action.openTeamsTab) {
      return '${action.playerName} fue integrado a un equipo';
    }
    return 'Tienes una nueva notificación';
  }

  void navigate(PushNotificationAction action) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    if (!action.hasPlayerTarget) {
      nav.pushNamed('/home');
      return;
    }

    nav.pushNamed(
      PlayerDashboardRoute.routeFor(action.playerId),
      arguments: {
        'playerId': action.playerId,
        'playerName': action.playerName,
        'verSolicitudes': action.openRequests ? 'true' : 'false',
        if (action.openTeamsTab) 'initialTab': 'teams',
      },
    );
  }

  void navigateByPayload(Map<String, dynamic> data) {
    navigate(parsePayload(data));
  }
}
