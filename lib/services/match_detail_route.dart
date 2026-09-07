import 'package:flutter/foundation.dart';

/// Argumentos opcionales al navegar al detalle (snapshot para UI inicial).
class MatchDetailRouteArgs {
  final String matchId;
  final Map<String, dynamic>? matchSnapshot;
  MatchDetailRouteArgs({required this.matchId, this.matchSnapshot});
}

/// Rutas profundas `/match_detail/<matchId>` para sobrevivir refresh en Web.
class MatchDetailRoute {
  MatchDetailRoute._();

  static const String baseRoute = '/match_detail';

  static String routeFor(String matchId) {
    final id = matchId.trim();
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

  static String? matchIdFromRoute(String? name) {
    final path = _routePath(name);
    if (!path.startsWith(baseRoute)) return null;
    if (path == baseRoute || path == '$baseRoute/') return null;

    final suffix = path.substring(baseRoute.length);
    if (!suffix.startsWith('/')) return null;

    final encoded = suffix.substring(1).split('/').first.trim();
    if (encoded.isEmpty) return null;
    return Uri.decodeComponent(encoded);
  }

  static Map<String, dynamic>? _argumentsMap(dynamic arguments) {
    if (arguments is MatchDetailRouteArgs) {
      return {
        'matchId': arguments.matchId,
        if (arguments.matchSnapshot != null)
          'matchSnapshot': arguments.matchSnapshot,
      };
    }
    if (arguments is Map) {
      return Map<String, dynamic>.from(arguments);
    }
    return null;
  }

  static ResolvedMatchDetailRoute resolve({
    String? routeName,
    dynamic arguments,
  }) {
    final args = _argumentsMap(arguments) ?? <String, dynamic>{};

    String matchId = (args['matchId'] ?? args['_id'] ?? args['id'] ?? '')
        .toString()
        .trim();

    if (matchId.isEmpty) {
      matchId = matchIdFromRoute(routeName) ?? '';
    }
    if (matchId.isEmpty && kIsWeb) {
      matchId = matchIdFromRoute(Uri.base.path) ?? '';
    }

    Map<String, dynamic>? snapshot;
    final rawSnapshot = args['matchSnapshot'] ?? args['match'];
    if (rawSnapshot is Map) {
      snapshot = Map<String, dynamic>.from(rawSnapshot);
    } else if (args.containsKey('home') || args.containsKey('visitor')) {
      snapshot = Map<String, dynamic>.from(args);
    }

    return ResolvedMatchDetailRoute(
      matchId: matchId,
      matchSnapshot: snapshot,
    );
  }
}

class ResolvedMatchDetailRoute {
  const ResolvedMatchDetailRoute({
    required this.matchId,
    this.matchSnapshot,
  });

  final String matchId;
  final Map<String, dynamic>? matchSnapshot;

  String get canonicalName {
    if (matchId.isEmpty) return MatchDetailRoute.baseRoute;
    return MatchDetailRoute.routeFor(matchId);
  }

  MatchDetailRouteArgs toRouteArgs() => MatchDetailRouteArgs(
        matchId: matchId,
        matchSnapshot: matchSnapshot,
      );
}
