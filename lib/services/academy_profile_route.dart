import 'package:flutter/foundation.dart';

/// Rutas profundas `/academy/<academyId>` con query opcional `sourceTournamentId`.
class AcademyProfileRoute {
  AcademyProfileRoute._();

  static const String baseRoute = '/academy';

  static String routeFor(
    String academyId, {
    String? sourceTournamentId,
  }) {
    final id = academyId.trim();
    if (id.isEmpty) return baseRoute;

    final base = '$baseRoute/${Uri.encodeComponent(id)}';
    final tournamentId = sourceTournamentId?.trim() ?? '';
    if (tournamentId.isEmpty) return base;

    return Uri(
      path: base,
      queryParameters: {'sourceTournamentId': tournamentId},
    ).toString();
  }

  static bool matches(String? name) {
    final path = _routePath(name);
    return path == baseRoute || path.startsWith('$baseRoute/');
  }

  static String? academyIdFromRoute(String? name) {
    final path = _routePath(name);
    if (!path.startsWith(baseRoute)) return null;
    if (path == baseRoute || path == '$baseRoute/') return null;

    final suffix = path.substring(baseRoute.length);
    if (!suffix.startsWith('/')) return null;

    final encoded = suffix.substring(1).split('/').first.trim();
    if (encoded.isEmpty) return null;
    return Uri.decodeComponent(encoded);
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
    return <String, String>{};
  }

  static ResolvedAcademyProfileRoute resolve({
    String? routeName,
    Map<String, dynamic>? arguments,
  }) {
    final args = Map<String, dynamic>.from(arguments ?? <String, dynamic>{});

    String academyId = (args['academyId'] ?? '').toString().trim();
    if (academyId.isEmpty) {
      academyId = academyIdFromRoute(routeName) ?? '';
    }
    if (academyId.isEmpty && kIsWeb) {
      academyId = academyIdFromRoute(Uri.base.path) ?? '';
    }

    final query = _queryParams(routeName);

    final sourceFromArgs = (args['sourceTournamentId'] ?? '').toString().trim();
    final sourceFromQuery = (query['sourceTournamentId'] ?? '').trim();

    return ResolvedAcademyProfileRoute(
      academyId: academyId,
      sourceTournamentId: sourceFromArgs.isNotEmpty
          ? sourceFromArgs
          : (sourceFromQuery.isNotEmpty ? sourceFromQuery : null),
    );
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

class ResolvedAcademyProfileRoute {
  const ResolvedAcademyProfileRoute({
    required this.academyId,
    this.sourceTournamentId,
  });

  final String academyId;
  final String? sourceTournamentId;

  String get canonicalName {
    if (academyId.isEmpty) return AcademyProfileRoute.baseRoute;
    return AcademyProfileRoute.routeFor(
      academyId,
      sourceTournamentId: sourceTournamentId,
    );
  }

  Map<String, dynamic> toArguments() => {
        'academyId': academyId,
        if (sourceTournamentId != null && sourceTournamentId!.isNotEmpty)
          'sourceTournamentId': sourceTournamentId,
      };
}
