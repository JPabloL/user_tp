import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'api_service.dart';
import 'storage_service.dart';

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

  Future<String?> inicializarNotificaciones() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return null;
      }

      final token = await _messaging.getToken(
        vapidKey:
            'BCAPjY-JSAZld57m31TM6VZzc5RpC3QAJyToRoEeCGb4cYjIxscF550UBFIWXgzB3D0CYmlIp4e2mZcHWLk8ueU',
      );
      if (token == null || token.isEmpty) return null;

      await _actualizarTokenEnServidor(token);
      _escucharForeground();
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> _actualizarTokenEnServidor(String token) async {
    final session = await storageService.getJson(AppConfig.sessionKey);
    final userId = session?['id']?.toString();
    if (userId == null || userId.isEmpty) return;

    try {
      await apiService.saveFcmToken(userId: userId, fcmToken: token);
      session?['fcm_token'] = token;
      if (session != null) {
        await storageService.setJson(AppConfig.sessionKey, session);
      }
    } catch (_) {}
  }

  void _escucharForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _mostrarNotificacionVisual(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateByPayload(message.data);
    });
  }

  Future<void> _mostrarNotificacionVisual(RemoteMessage message) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final routeName = ModalRoute.of(context)?.settings.name ?? '';
    if (routeName.contains('jugador')) return;

    final title = message.notification?.title ?? 'Aviso';
    final body = message.notification?.body ?? '';
    final data = message.data;
    final encoded = jsonEncode(data);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Text('$title\n$body'),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => _navigateByPayload(jsonDecode(encoded) as Map<String, dynamic>),
        ),
      ),
    );
  }

  void _navigateByPayload(Map<String, dynamic> data) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamed(
      '/jugador',
      arguments: {
        'playerId': data['playerId'],
        'playerName': data['playerName'],
        'verSolicitudes': data['verSolicitudes'],
      },
    );
  }
}
