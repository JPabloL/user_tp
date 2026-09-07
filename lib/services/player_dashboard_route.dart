import 'package:flutter/foundation.dart';

/// Rutas profundas `/jugador/<playerId>` con query opcional `?solicitudes=true&tab=teams`.
class PlayerDashboardRoute {
  PlayerDashboardRoute._();

  static const String baseRoute = '/jugador';

  static String routeFor(String playerId) {
    final id = playerId.trim();
    if (id.isEmpty) return baseRoute;
    return '$baseRoute/${Uri.encodeComponent(id)}';
  }

  static bool matches(String? name) {
    final path = _routePath(name);
    return path == baseRoute || path.startsWith('$baseRoute/');
  }

  static String _routePath(String? name) {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return '/';
    if (raw.contains('?')) {
      return Uri.parse(raw.startsWith('/') ? raw : '/$raw').path;
    }
    return raw.split('?').first;
  }

  static Map<String, String> _queryParams(String? name) {
    final raw = (name ?? '').trim();
    if (raw.contains('?')) {
      final uri = Uri.parse(raw.startsWith('/') ? raw : '/$raw');
      return Map<String, String>.from(uri.queryParameters);
    }
    if (kIsWeb) {
      return Map<String, String>.from(Uri.base.queryParameters);
    }
    return {};
  }

  static String? playerIdFromRoute(String? name) {
    final path = _routePath(name);
    if (!path.startsWith(baseRoute)) return null;
    if (path == baseRoute || path == '$baseRoute/') return null;

    final suffix = path.substring(baseRoute.length);
    if (!suffix.startsWith('/')) return null;

    final encoded = suffix.substring(1).split('/').first.trim();
    if (encoded.isEmpty) return null;
    return Uri.decodeComponent(encoded);
  }

  static ResolvedPlayerDashboardRoute resolve({
    String? routeName,
    Map<String, dynamic>? arguments,
  }) {
    final args = Map<String, dynamic>.from(arguments ?? <String, dynamic>{});

    String playerId = (args['playerId'] ?? '').toString().trim();
    if (playerId.isEmpty) {
      playerId = playerIdFromRoute(routeName) ?? '';
    }
    if (playerId.isEmpty && kIsWeb) {
      playerId = playerIdFromRoute(Uri.base.path) ?? '';
    }

    final query = _queryParams(routeName);

    final verFromArgs = args['verSolicitudes']?.toString() == 'true';
    final verFromQuery = query['solicitudes'] == 'true' ||
        query['verSolicitudes'] == 'true' ||
        query['ver_solicitudes'] == 'true';

    final tabFromArgs = args['initialTab']?.toString().trim();
    final tabFromQuery = query['tab']?.trim();

    final relation = (args['relation'] ?? query['relation'] ?? '').toString().trim();
    final isFollowed = relation == 'followed' || query['mode'] == 'follow';
    final canManage = args['canManage'] == true;
    final viewFromArgs = args['viewOnly']?.toString() == 'true';
    final viewFromQuery = query['viewOnly'] == 'true';
    final viewOnly = (isFollowed || viewFromArgs || viewFromQuery) && !canManage;

    return ResolvedPlayerDashboardRoute(
      playerId: playerId,
      playerName: (args['playerName'] ?? 'Perfil').toString(),
      autoOpenRequests: verFromArgs || verFromQuery,
      initialTab: (tabFromArgs != null && tabFromArgs.isNotEmpty)
          ? tabFromArgs
          : tabFromQuery,
      viewOnly: viewOnly,
      playerRelation: isFollowed ? 'followed' : (relation.isNotEmpty ? relation : null),
      canManage: canManage,
    );
  }
}

class ResolvedPlayerDashboardRoute {
  const ResolvedPlayerDashboardRoute({
    required this.playerId,
    required this.playerName,
    this.autoOpenRequests = false,
    this.initialTab,
    this.viewOnly = false,
    this.playerRelation,
    this.canManage = false,
  });

  final String playerId;
  final String playerName;
  final bool autoOpenRequests;
  final String? initialTab;
  final bool viewOnly;
  final String? playerRelation;
  final bool canManage;

  String get canonicalName {
    if (playerId.isEmpty) return PlayerDashboardRoute.baseRoute;
    final base = PlayerDashboardRoute.routeFor(playerId);
    final params = <String, String>{};
    if (autoOpenRequests) params['solicitudes'] = 'true';
    if (initialTab != null && initialTab!.isNotEmpty) {
      params['tab'] = initialTab!;
    }
    if (viewOnly) params['viewOnly'] = 'true';
    if (params.isEmpty) return base;
    return Uri(path: base, queryParameters: params).toString();
  }

  Map<String, dynamic> toArguments() => {
        'playerId': playerId,
        'playerName': playerName,
        'verSolicitudes': autoOpenRequests ? 'true' : 'false',
        if (initialTab != null && initialTab!.isNotEmpty) 'initialTab': initialTab,
        if (viewOnly) 'viewOnly': 'true',
        if (playerRelation != null && playerRelation!.isNotEmpty)
          'relation': playerRelation,
        if (canManage) 'canManage': true,
      };
}
