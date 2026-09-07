/// Reglas compartidas para solicitudes de ingreso a equipos/academias.
class TeamRequestHelpers {
  TeamRequestHelpers._();

  static String academyId(dynamic academy) =>
      (academy['id'] ?? academy['_id'] ?? '').toString();

  static String playerIdFromProfile(Map<String, dynamic> profile) =>
      (profile['playerId'] ?? profile['id'] ?? profile['_id'] ?? '').toString();

  static int toMood(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<Map<String, dynamic>> normalizePlayerRequests(List<dynamic> raw) {
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((request) => request['type']?.toString() != 'co_tutor')
        .toList();
  }

  static Map<String, dynamic>? findExistingRequest(
    List<Map<String, dynamic>> requests,
    String academyId,
  ) {
    if (academyId.isEmpty) return null;

    for (final request in requests) {
      final requestAcademyId =
          (request['academy']?['id'] ?? request['academy']?['_id'] ?? '').toString();
      if (requestAcademyId == academyId) {
        return request;
      }
    }
    return null;
  }

  static TeamRequestStatus statusForExisting(Map<String, dynamic>? existing) {
    if (existing == null || existing.isEmpty) {
      return TeamRequestStatus.canSend;
    }

    final mood = toMood(existing['mood']);
    if (mood == 0) return TeamRequestStatus.pending;
    if (mood == 1) return TeamRequestStatus.accepted;
    if (mood == 2 || mood == 3) return TeamRequestStatus.canResend;
    return TeamRequestStatus.canSend;
  }

  static String statusLabel(TeamRequestStatus status) {
    switch (status) {
      case TeamRequestStatus.pending:
        return 'Solicitud pendiente';
      case TeamRequestStatus.accepted:
        return 'Ya fuiste aceptado en este equipo';
      case TeamRequestStatus.canResend:
        return 'Toca para reenviar solicitud';
      case TeamRequestStatus.canSend:
        return 'Toca para enviar solicitud';
    }
  }
}

enum TeamRequestStatus {
  canSend,
  pending,
  accepted,
  canResend,
}
