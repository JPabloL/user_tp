/// Convierte convocatorias a selectivo de `user-context-v2` en solicitudes
/// pendientes (mismo flujo que ingreso a equipo).
class SelectivoHelpers {
  SelectivoHelpers._();

  static const String requestType = 'selectivo';

  static Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static Map<String, dynamic>? selectivosFrom(dynamic dashboard) {
    return asMap(asMap(dashboard)?['selectivos']);
  }

  static bool isSelectivoRequest(dynamic request) {
    if (request is! Map) return false;
    return request['type']?.toString() == requestType;
  }

  static bool isPendingConsent(Map<String, dynamic> candidate) {
    final status = (candidate['status'] ?? '').toString();
    final consent = asMap(candidate['consent']);
    final consentStatus = (consent?['status'] ?? '').toString();
    final perms = asMap(candidate['permissions']);
    final canRespond = perms?['canRespondConsent'] == true;
    return canRespond &&
        (status == 'pending_consent' || consentStatus == 'pending');
  }

  static String playerIdOf(Map<String, dynamic> candidate) {
    final player = asMap(candidate['player']);
    return (player?['id'] ?? candidate['playerId'] ?? '').toString().trim();
  }

  static List<Map<String, dynamic>> pendingCandidates({
    required dynamic dashboard,
    String? playerId,
  }) {
    final selectivos = selectivosFrom(dashboard);
    if (selectivos == null) return [];

    final wantedId = (playerId ?? '').trim();
    if (wantedId.isNotEmpty) {
      final byPlayer = selectivos['byPlayer'] as List<dynamic>? ?? [];
      for (final item in byPlayer) {
        final group = asMap(item);
        if (group == null) continue;
        if ((group['playerId'] ?? '').toString().trim() != wantedId) continue;
        return _pendingFromList(group['candidates']);
      }
    }

    final all = _pendingFromList(selectivos['candidates']);
    if (wantedId.isEmpty) return all;
    return all.where((c) => playerIdOf(c) == wantedId).toList();
  }

  static List<Map<String, dynamic>> _fromList(dynamic raw) {
    final list = raw is List ? raw : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static List<Map<String, dynamic>> _pendingFromList(dynamic raw) {
    return _fromList(raw).where(isPendingConsent).toList();
  }

  static List<Map<String, dynamic>> playerCandidates({
    required dynamic dashboard,
    String? playerId,
  }) {
    final selectivos = selectivosFrom(dashboard);
    if (selectivos == null) return [];

    final wantedId = (playerId ?? '').trim();
    if (wantedId.isNotEmpty) {
      final byPlayer = selectivos['byPlayer'] as List<dynamic>? ?? [];
      for (final item in byPlayer) {
        final group = asMap(item);
        if (group == null) continue;
        if ((group['playerId'] ?? '').toString().trim() != wantedId) continue;
        return _fromList(group['candidates']);
      }
    }

    final all = _fromList(selectivos['candidates']);
    if (wantedId.isEmpty) return all;
    return all.where((c) => playerIdOf(c) == wantedId).toList();
  }

  static bool needsConsentResponse(dynamic requestOrCandidate) {
    final map = asMap(requestOrCandidate);
    if (map == null) return false;
    final candidate = asMap(map['candidate']) ?? map;
    final perms = asMap(candidate['permissions']) ?? asMap(map['permissions']);
    return perms?['canRespondConsent'] == true;
  }

  static Map<String, int> pendingConsentCounts(dynamic dashboard) {
    final counts = <String, int>{};
    for (final candidate in pendingCandidates(dashboard: dashboard)) {
      final id = playerIdOf(candidate);
      if (id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  static Map<String, dynamic> toPendingRequest(Map<String, dynamic> candidate) {
    final academy = asMap(candidate['academy']) ?? <String, dynamic>{};
    final team = asMap(candidate['team']) ?? <String, dynamic>{};
    final call = asMap(candidate['selectionCall']) ?? <String, dynamic>{};
    final consent = asMap(candidate['consent']) ?? <String, dynamic>{};
    final category = asMap(candidate['category']) ?? asMap(team['category']) ?? <String, dynamic>{};
    return {
      'type': requestType,
      'origin': requestType,
      'mood': 0,
      '_id': candidate['id'],
      'id': candidate['id'],
      'academy': academy,
      'team': team,
      'selectionCall': call,
      'league': asMap(candidate['league']) ?? <String, dynamic>{},
      'player': asMap(candidate['player']) ?? <String, dynamic>{},
      'category': category,
      'consent': consent,
      'permissions': asMap(candidate['permissions']) ?? <String, dynamic>{},
      'status': candidate['status'],
      'date': (consent['requestedAt'] ?? candidate['createdAt'] ?? '').toString(),
      'candidate': candidate,
    };
  }

  static const Set<String> activeProcessStatuses = {
    'pending_consent',
    'pending_admin',
    'aspirant',
    'roster',
  };

  static bool isActiveProcess(Map<String, dynamic> candidate) {
    return activeProcessStatuses.contains((candidate['status'] ?? '').toString());
  }

  static int processStageIndex(String status) {
    switch (status) {
      case 'pending_consent':
        return 0;
      case 'pending_admin':
        return 1;
      case 'aspirant':
        return 2;
      case 'roster':
        return 3;
      default:
        return -1;
    }
  }

  static String processStatusLabel(String status) {
    switch (status) {
      case 'pending_consent':
        return 'Pendiente de consentimiento';
      case 'pending_admin':
        return 'Pendiente de aprobación por los organizadores';
      case 'aspirant':
        return 'En proceso de selección';
      case 'roster':
        return 'Seleccionado';
      default:
        return '';
    }
  }

  static List<Map<String, dynamic>> asPendingRequests({
    required dynamic dashboard,
    required String playerId,
  }) {
    final wanted = playerId.trim();
    return _fromList(selectivosFrom(dashboard)?['candidates'])
        .where((c) => wanted.isEmpty || playerIdOf(c) == wanted)
        .map(toPendingRequest)
        .toList();
  }
}
