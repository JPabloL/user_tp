import 'package:flutter/foundation.dart';

import 'storage_service.dart';

/// Deep link `/joinTeam?token=<clave-publica-equipo>`.
class JoinTeamLink {
  JoinTeamLink._();

  static const String route = '/joinTeam';
  static const String storageKey = 'pending_join_team_token';

  static String routePath(String? name) {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return '/';
    if (raw.contains('?')) {
      return Uri.parse(raw.startsWith('/') ? raw : '/$raw').path;
    }
    return raw.split('?').first;
  }

  static bool isJoinTeamRoute(String? name) {
    return routePath(name).toLowerCase().endsWith('/jointeam');
  }

  static String? tokenFromUri(Uri uri) {
    if (!isJoinTeamRoute(uri.path)) return null;
    final token = uri.queryParameters['token']?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static String? tokenFromRouteName(String? name) {
    if (!isJoinTeamRoute(name)) return null;

    final raw = (name ?? '').trim();
    if (raw.contains('?')) {
      final uri = Uri.parse(raw.startsWith('/') ? raw : '/$raw');
      final token = uri.queryParameters['token']?.trim();
      if (token != null && token.isNotEmpty) return token;
    }

    if (kIsWeb) {
      return tokenFromUri(Uri.base);
    }
    return null;
  }

  static String? tokenFromRouteSettings(Object? arguments) {
    if (arguments is Map) {
      final raw = arguments['token'] ?? arguments['joinTeamToken'];
      final token = raw?.toString().trim();
      if (token != null && token.isNotEmpty) return token;
    }
    return null;
  }

  static String? initialToken({Object? routeArguments, String? routeName}) {
    return tokenFromRouteSettings(routeArguments) ??
        tokenFromRouteName(routeName) ??
        (kIsWeb ? tokenFromUri(Uri.base) : null);
  }

  static Future<void> savePending(StorageService storage, String token) async {
    await storage.setJson(storageKey, {'token': token.trim()});
  }

  static Future<String?> readPending(StorageService storage) async {
    final data = await storage.getJson(storageKey);
    final token = data?['token']?.toString().trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static Future<void> clearPending(StorageService storage) async {
    await storage.remove(storageKey);
  }

  static bool hasActiveSession(Map<String, dynamic>? session) {
    return session != null && session['uid'] != null;
  }
}
