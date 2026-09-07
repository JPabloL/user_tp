import 'package:flutter/material.dart';

/// Helpers para el catálogo global de torneos (`getAllTournamentsTp`).
class TournamentCatalogHelpers {
  TournamentCatalogHelpers._();

  static List<Map<String, dynamic>> parseResponse(Map<String, dynamic> response) {
    for (final key in [
      'torneos',
      'tournaments',
      'data',
      'rows',
      'items',
      'list',
      'result',
    ]) {
      final raw = response[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => normalizeTournament(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return [];
  }

  static Map<String, dynamic> normalizeTournament(Map<String, dynamic> raw) {
    final league = raw['league'] is Map
        ? Map<String, dynamic>.from(raw['league'] as Map)
        : <String, dynamic>{};
    final theme = raw['theme'] is Map
        ? Map<String, dynamic>.from(raw['theme'] as Map)
        : <String, dynamic>{};

    return {
      ...raw,
      'name': (raw['name'] ?? 'Torneo').toString(),
      'subname': (raw['subname'] ?? '').toString().trim(),
      'clave': (raw['clave'] ?? raw['public_key'] ?? raw['slug'] ?? '').toString().trim(),
      'id': (raw['id'] ?? raw['_id'] ?? raw['tournamentId'] ?? '').toString().trim(),
      'modalidad': (raw['modalidad'] ?? '').toString().trim(),
      'img': (raw['img'] ?? '').toString().trim(),
      'logo': (raw['logo'] ?? '').toString().trim(),
      'start': (raw['start'] ?? '').toString().trim(),
      'end': (raw['end'] ?? '').toString().trim(),
      'resumeCates': (raw['resumeCates'] ?? raw['prev'] ?? '').toString().trim(),
      'desc': (raw['desc'] ?? '').toString().trim(),
      'active': raw['active'] == true,
      'league': league,
      'theme': theme,
    };
  }

  static List<Map<String, dynamic>> groupActuales(List<Map<String, dynamic>> all) {
    final list = all.where((t) => t['active'] == true).toList();
    list.sort(_compareActualesNearestFirst);
    return list;
  }

  static List<Map<String, dynamic>> groupAnteriores(List<Map<String, dynamic>> all) {
    final list = all.where((t) => t['active'] != true).toList();
    list.sort(_compareAnterioresRecentFirst);
    return list;
  }

  /// Actuales: del más próximo al más lejano (respecto a hoy).
  static int _compareActualesNearestFirst(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final ka = _actualesSortKey(a);
    final kb = _actualesSortKey(b);
    return ka.compareTo(kb);
  }

  /// Anteriores: del más reciente al más lejano (por fecha de fin).
  static int _compareAnterioresRecentFirst(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final ka = _anterioresSortKey(a);
    final kb = _anterioresSortKey(b);
    return ka.compareTo(kb);
  }

  static int _actualesSortKey(Map<String, dynamic> tournament) {
    final now = DateTime.now();
    final start = DateTime.tryParse((tournament['start'] ?? '').toString());
    final end = DateTime.tryParse((tournament['end'] ?? '').toString());

    // Aún no inicia → más próximo = inicio más cercano.
    if (start != null && start.isAfter(now)) {
      return start.millisecondsSinceEpoch;
    }
    // En curso → más próximo = fin más cercano.
    if (end != null && !end.isBefore(now)) {
      return end.millisecondsSinceEpoch;
    }
    if (start != null) {
      return start.millisecondsSinceEpoch;
    }
    return 1 << 30;
  }

  static int _anterioresSortKey(Map<String, dynamic> tournament) {
    final end = DateTime.tryParse(
      (tournament['end'] ?? tournament['start'] ?? '').toString(),
    );
    if (end == null) return 1 << 30;
    // Negativo para que, al ordenar ascendente, el más reciente quede primero.
    return -end.millisecondsSinceEpoch;
  }

  static Color accentColor(Map<String, dynamic> tournament, Color fallback) {
    final theme = tournament['theme'];
    if (theme is Map) {
      final primary = parseHexColor((theme['primary'] ?? '').toString());
      if (primary != null) return primary;
    }
    return fallback;
  }

  static Color? parseHexColor(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final hex = value.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return null;
  }

  static String formatDateRange(Map<String, dynamic> tournament) {
    final start = DateTime.tryParse((tournament['start'] ?? '').toString());
    final end = DateTime.tryParse((tournament['end'] ?? '').toString());
    if (start == null && end == null) return '';
    if (start != null && end != null) {
      return '${_formatDay(start)} — ${_formatDay(end)}';
    }
    if (start != null) return 'Desde ${_formatDay(start)}';
    return 'Hasta ${_formatDay(end!)}';
  }

  static String _formatDay(DateTime dt) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static String leagueName(Map<String, dynamic> tournament) {
    final league = tournament['league'];
    if (league is Map) {
      return (league['name'] ?? '').toString().trim();
    }
    return '';
  }

  static String leagueLogo(Map<String, dynamic> tournament) {
    final league = tournament['league'];
    if (league is Map) {
      return (league['logo'] ?? league['thumb'] ?? '').toString().trim();
    }
    return '';
  }

  static String detailRouteKey(Map<String, dynamic> tournament) {
    final clave = (tournament['clave'] ?? '').toString().trim();
    if (clave.isNotEmpty) return clave;
    return (tournament['id'] ?? '').toString().trim();
  }
}
