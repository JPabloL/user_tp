/// Rutas profundas `/tournament_detail/<clave>` para detalle de torneo.
class TournamentDetailRoute {
  TournamentDetailRoute._();

  static const String baseRoute = '/tournament_detail';

  static String routeFor(String routeKey) {
    final key = routeKey.trim();
    if (key.isEmpty) return baseRoute;
    return '$baseRoute/${Uri.encodeComponent(key)}';
  }

  static bool matches(String? name) {
    final path = _routePath(name);
    return path == baseRoute || path.startsWith('$baseRoute/');
  }

  static String? keyFromRoute(String? name) {
    final path = _routePath(name);
    if (!path.startsWith(baseRoute)) return null;
    if (path == baseRoute || path == '$baseRoute/') return null;

    final raw = path.substring(baseRoute.length);
    final segment = raw.startsWith('/') ? raw.substring(1) : raw;
    if (segment.isEmpty) return null;
    return Uri.decodeComponent(segment);
  }

  static String _routePath(String? name) {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return '/';
    if (raw.contains('?')) {
      return Uri.parse(raw.startsWith('/') ? raw : '/$raw').path;
    }
    return raw.split('?').first;
  }
}
