import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  ApiService({String? apiUrl, String? apiCal, String? apiCdb, String? token})
    : apiUrl = apiUrl ?? 'https://cuerposallimite.net/api',
      apiCal = apiCal ?? 'https://api.baldek.com',
      apiCdb = apiCdb ?? 'https://server.cuerposallimite.net',
      token = token ?? '3es_ldo5%4d';

  final String apiUrl;
  final String apiCal;
  final String apiCdb;
  final String token;

  Future<Map<String, dynamic>> updateCoTutorshipRequestStatus({
    required String uid,
    required String requestId,
    required String playerId,
    required String status,
  }) async {
    final uri = Uri.parse('$apiCdb/updateCoTutorshipRequestStatus');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'uid': uid,
        'requestId': requestId,
        'playerId': playerId,
        'status': status,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> cancelCoTutorshipRequest({
    required String uid,
    required String requestId,
    required String playerId,
  }) async {
    final uri = Uri.parse('$apiCdb/cancelCoTutorshipRequest');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'uid': uid,
        'requestId': requestId,
        'playerId': playerId,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> migrateUser(String email, String pass) async {
    final uri = Uri.parse('$apiCdb/auth/migrate');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'email': email, 'password': pass}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> registerUserV2(
    Map<String, dynamic> userData,
  ) async {
    final uri = Uri.parse('$apiCdb/registerNfllFirebase');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'uid': userData['uid'],
        'item': {
          'name': userData['name'],
          'mail': userData['mail'],
          'phone': userData['phone'],
        },
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> syncUser(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$apiCdb/auth/sync');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'uid': payload['uid'],
        'email': payload['email'],
        'name': payload['name'],
        'provider': payload['provider'],
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> getUserContext(String uid) async {
    final uri = Uri.parse('$apiCdb/user-context');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': uid}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> getAllAcademyDataV8(String academyId) async {
    final uri = Uri.parse('$apiCdb/getAllAcademyDataV8');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'search': academyId}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> getAcademyPublicProfile(String academyId) async {
    return post('/getAcademyPublicProfile', {'academyId': academyId});
  }

  Future<Map<String, dynamic>> getAcademyProfileContext(String academyId) async {
    return post('/getAcademyProfileContext', {'academyId': academyId});
  }

  Future<Map<String, dynamic>> getUserContextV2(String uid) async {
    final uri = Uri.parse('$apiCdb/user-context-v2');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': uid}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> getTournamentTeamsGroupedByCategory(
    String tournamentId,
  ) async {
    return post('/getTournamentTeamsGroupedByCategory', {
      'tournamentId': tournamentId,
    });
  }

  Future<Map<String, dynamic>> getTeamRosterAttendance(String teamId) async {
    return post('/getTeamRosterAttendance', {'teamId': teamId});
  }

  Future<Map<String, dynamic>> getOnlyTournamentDetailByClave(String clave) async {
    final uri = Uri.parse('$apiCdb/getOnlyTournamentDetailByClave');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'clave': clave,
        'token': '3es_ldo5%4d'
      }),
    );
    return _decode(response);
  }

  /// Torneo completo por id (mismo contrato que Ionic: viewNlff tournament/byId).
  Future<Map<String, dynamic>?> getTournamentById(String id) async {
    final uri = Uri.parse('$apiCdb/viewNlff');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'view': 'tournament',
        'mood': 'byId',
        'search': id,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    if (response.body.isEmpty) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      return Map<String, dynamic>.from(decoded.first as Map);
    }
    return null;
  }

  Future<Map<String, dynamic>> createRoleProfile({
    required String uid,
    required String role,
  }) async {
    final uri = Uri.parse('$apiCdb/api/createRoleProfile');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'uid': uid, 'role': role}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> saveFcmToken({
    required String userId,
    required String fcmToken,
  }) async {
    final uri = Uri.parse('$apiCdb/saveFcmToken');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'userId': userId,
        'fcm_token': fcmToken,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> createPlayerProfile(
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$apiCdb/createPlayerProfile/');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> uploadAvatar({
    required String uid,
    required List<int> bytes,
    String filename = 'avatar.jpg',
  }) async {
    final uri = Uri.parse('$apiCdb/uploadAvatar/$uid');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: filename,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<Map<String, dynamic>> uploadIdentityDoc({
    required String uid,
    required List<int> bytes,
    required String side,
  }) async {
    final endpoint = side == 'back'
        ? 'uploadIdentityBack'
        : 'uploadIdentityFront';
    final uri = Uri.parse('$apiCdb/$endpoint/$uid');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: 'id-$side.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<Map<String, dynamic>> checkCurp(String curp) async {
    final uri = Uri.parse('$apiCdb/checkCurp');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'search': curp}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> createChildProfile(
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$apiCdb/createChildProfile');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> uploadChildRosterPhoto({
    required String playerId,
    required List<int> bytes,
  }) async {
    final uri = Uri.parse('$apiCdb/uploadChildRosterPhoto/$playerId');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'profilePhoto',
          bytes,
          filename: 'profile.jpg',
        ),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<Map<String, dynamic>> validateChildIdentity({
    required String playerId,
    required List<int> docBytes,
    required String docType,
  }) async {
    final uri = Uri.parse('$apiCdb/validateChildIdentity/$playerId');
    final request = http.MultipartRequest('POST', uri)
      ..fields['docType'] = docType
      ..fields['legalConsent'] = 'true'
      ..files.add(
        http.MultipartFile.fromBytes('docPhoto', docBytes, filename: 'doc.jpg'),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<Map<String, dynamic>> requestManualReview({
    required String playerId,
    required List<int> docBytes,
    required String docType,
  }) async {
    final uri = Uri.parse('$apiCdb/requestManualReview/$playerId');
    final request = http.MultipartRequest('POST', uri)
      ..fields['docType'] = docType
      ..fields['legalConsent'] = 'true'
      ..files.add(
        http.MultipartFile.fromBytes('docPhoto', docBytes, filename: 'doc.jpg'),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<Map<String, dynamic>> loadPlayerDashboardData(String playerId) async {
    final uri = Uri.parse('$apiCdb/allPlayerDashboardData');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': playerId, 'token': token}),
    );
    return _decode(response);
  }

  Future<List<dynamic>> getMyRequests(String playerId) async {
    final uri = Uri.parse('$apiCdb/viewNlff');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'view': 'requests',
        'mood': 'byPlayer',
        'search': playerId,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(
        errorBody['message'] ?? 'Error HTTP ${response.statusCode}',
      );
    }
    if (response.body.isEmpty) return <dynamic>[];
    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) return decoded;
    if (decoded is Map<String, dynamic>) {
      return (decoded['data'] as List<dynamic>?) ?? <dynamic>[];
    }
    return <dynamic>[];
  }

  Future<Map<String, dynamic>> getPlayerStatsByTeam({
    required String teamId,
    required String playerId,
  }) async {
    final uri = Uri.parse('$apiCdb/getPlayerStatsByTeam');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'teamId': teamId,
        'playerId': playerId,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> getPlayerStatsHistory(String playerId) async {
    final uri = Uri.parse('$apiCdb/getPlayerStatsHistory');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': playerId, 'token': token}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> updatePlayerPublicPhoto({
    required String playerId,
    required List<int> bytes,
  }) async {
    final uri = Uri.parse('$apiCdb/updatePlayerPublicPhoto/$playerId');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'publicPhoto',
          bytes,
          filename: 'profile.jpg',
        ),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  /// Busca academias/equipos por nombre para el flujo de solicitud de ingreso.
  Future<List<dynamic>> searchTeams(String query) async {
    final uri = Uri.parse('$apiCdb/viewNlff');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'view': 'teams',
        'mood': 'search',
        'search': query,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error HTTP ${response.statusCode}');
    }
    if (response.body.isEmpty) return <dynamic>[];
    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) return decoded;
    if (decoded is Map<String, dynamic>) {
      return (decoded['data'] as List<dynamic>?) ?? <dynamic>[];
    }
    return <dynamic>[];
  }

  /// Envía una solicitud de ingreso del jugador a un equipo.
  Future<Map<String, dynamic>> sendTeamRequest({
    required String playerId,
    required String teamId,
    required String userId,
  }) async {
    final uri = Uri.parse('$apiCdb/sendTeamRequest');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'playerId': playerId,
        'teamId': teamId,
        'userId': userId,
      }),
    );
    return _decode(response);
  }

  /// Actualiza el estado de una solicitud (aceptar mood=1, rechazar mood=2, cancelar mood=3).
  /// Equivalente a apiService.updateRequest(item, userId) de Ionic → POST /updateRequestMood
  Future<Map<String, dynamic>> updateRequest({
    required Map<String, dynamic> request,
    required String userId,
  }) async {
    final uri = Uri.parse('$apiCdb/updateRequestMood');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'item': request,
        'actingUserId': userId,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Intenta extraer mensaje de error del body
      try {
        final err = jsonDecode(response.body);
        final msg = err is Map ? err['message'] ?? err['reason'] : null;
        throw Exception(msg ?? 'Error HTTP ${response.statusCode}');
      } catch (_) {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    }

    if (response.body.isEmpty) return {'ok': true};

    // El servidor puede devolver Map OR List (CouchDB bulk response)
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List && decoded.isNotEmpty) {
      // Toma el primer elemento si es array CouchDB [{"ok":true,"id":"...","rev":"..."}]
      final first = decoded.first;
      if (first is Map<String, dynamic>) return first;
    }
    // Fallback: si no podemos parsear la forma, lo tratamos como éxito
    return {'ok': true};
  }

  /// Busca academia/equipo por clave pública (`public_key`).
  Future<Map<String, dynamic>?> findAcademyByPublicKey(String publicKey) async {
    final query = publicKey.trim();
    if (query.isEmpty) return null;

    final results = await searchAcademies(query, 'clave');
    if (results.isEmpty) return null;

    for (final item in results) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final key = (map['public_key'] ?? map['clave'] ?? '').toString().trim();
      if (key.toLowerCase() == query.toLowerCase()) {
        return map;
      }
    }

    return Map<String, dynamic>.from(results.first as Map);
  }

  /// Busca academias por nombre ('name') o clave pública ('clave').
  /// Equivalente a apiService.searchAcademies(term, searchType) de Ionic.
  /// Endpoint correcto: POST /searchAcademiesNlff con body { query, searchType, token }
  Future<List<dynamic>> searchAcademies(String term, String type) async {
    final uri = Uri.parse('$apiCdb/searchAcademiesNlff');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'query': term,
        'searchType': type, // 'name' or 'clave'
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error HTTP ${response.statusCode}');
    }
    if (response.body.isEmpty) return <dynamic>[];
    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) return decoded;
    if (decoded is Map<String, dynamic>) {
      if (decoded['status'] == 'error') {
        throw Exception(decoded['message']?.toString() ?? 'Error del servidor');
      }
      return (decoded['data'] as List<dynamic>?) ?? <dynamic>[];
    }
    return <dynamic>[];
  }

  /// Elimina definitivamente una solicitud de ingreso enviada por el jugador.
  Future<Map<String, dynamic>> deleteRequestPlayer(String requestId) async {
    final uri = Uri.parse('$apiCdb/deleteRequestPlayer');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'requestId': requestId,
      }),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Error HTTP ${response.statusCode}');
    }
    return body;
  }

  /// Envía una solicitud de co-tutoría al servidor
  Future<Map<String, dynamic>> sendCoTutorshipRequest({
    required String uid,
    required String curp,
    required String nipVinculacion,
  }) async {
    final uri = Uri.parse('$apiCdb/requestCoTutorship');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'uid': uid,
        'curp': curp,
        'nip_vinculacion': nipVinculacion,
      }),
    );
    return _decode(response);
  }

  /// Vincula un perfil de jugador a una nueva cuenta comprobando las credenciales de la cuenta vieja
  Future<Map<String, dynamic>> linkPlayerToUser({
    required String playerId,
    required String userId,
    required String email,
    required String password,
    Map<String, dynamic>? userData,
  }) async {
    final uri = Uri.parse('$apiCdb/link-player-to-user');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': '3es_ldo5%4d', // Token fijo del endpoint
        'playerId': playerId,
        'userId': userId,
        'email': email,
        'password': password,
        if (userData != null) 'userData': userData,
      }),
    );
    return _decode(response);
  }

  /// Envía un correo con la contraseña legacy al tutor usando su correo (cuentas anteriores).
  Future<Map<String, dynamic>> sendMailRecoverTptutor({
    required String email,
  }) async {
    final uri = Uri.parse('$apiCdb/sendMailRecoverTptutor');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'mail': email.trim().toLowerCase(),
      }),
    );
    return _decode(response);
  }

  /// Indica si el correo pertenece a una cuenta tutor legacy (no migrada a Firebase).
  Future<bool> hasLegacyTutorAccount(String email) async {
    final res = await migrateUser(email.trim().toLowerCase(), '__recovery_probe__');
    final status = res['status']?.toString().toLowerCase() ?? '';
    final msg = (res['message'] ?? '').toString().toLowerCase();

    if (status == 'ok') return false;

    final notFound = status == 'not_found' ||
        msg.contains('usuario no encontrado') ||
        msg.contains('no se encontró') ||
        msg.contains('not found');

    return !notFound;
  }

  /// Envía un correo con la contraseña legacy al usuario de la cuenta vieja usando el ID del jugador
  Future<Map<String, dynamic>> sendMailRecoverByPlayerId({
    required String playerId,
  }) async {
    final uri = Uri.parse('$apiCdb/sendMailRecoverByPlayerId');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': '3es_ldo5%4d',
        'playerId': playerId,
      }),
    );
    return _decode(response);
  }

  /// Crea un ticket de soporte
  Future<Map<String, dynamic>> createSupportTicket({
    required Map<String, dynamic> ticketData,
  }) async {
    final uri = Uri.parse('$apiCdb/createSupportTicket');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': '3es_ldo5%4d',
        ...ticketData,
      }),
    );
    return _decode(response);
  }

  /// Consulta la información de un tutor por su ID
  Future<Map<String, dynamic>> getTutorById(String tutorId) async {
    final uri = Uri.parse('$apiCdb/getTutorById');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'tutorId': tutorId,
      }),
    );
    return _decode(response);
  }

  /// Guarda la edición de un documento genérico en la base de datos
  Future<Map<String, dynamic>> updateDoc(Map<String, dynamic> item) async {
    final uri = Uri.parse('$apiCdb/editNlff');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'item': item}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> getUserRelatedMatches(String uid) async {
    return post('/getUserRelatedMatches', {
      'uid': uid,
    });
  }

  Future<Map<String, dynamic>> getMatchesByTournament(String tournamentId) async {
    return post('/getMatchesByTournament', {
      'tournamentId': tournamentId,
    });
  }

  Future<Map<String, dynamic>> getAllTournamentsTp() async {
    return post('/getAllTournamentsTp', {});
  }

  Future<Map<String, dynamic>> respondSelectionCandidateConsent({
    required String uid,
    required String selectionCandidateId,
    required String decision,
  }) {
    return post('/respondSelectionCandidateConsent', {
      'uid': uid,
      'selectionCandidateId': selectionCandidateId,
      'decision': decision,
    });
  }

  Future<Map<String, dynamic>> resetSelectionCandidateConsent({
    required String uid,
    required String selectionCandidateId,
  }) {
    return post('/resetSelectionCandidateConsent', {
      'uid': uid,
      'selectionCandidateId': selectionCandidateId,
    });
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$apiCdb$endpoint');
    final payload = Map<String, dynamic>.from(body);
    if (!payload.containsKey('token')) {
      payload['token'] = token;
    }
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    
    // Some endpoints might return a plain JSON without status code checks inside _decode
    // We use _decode because it checks status >= 200 && < 300
    try {
      return _decode(response);
    } catch (e) {
      if (response.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<List<dynamic>> postList(String path, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$apiCdb$path');
    if (!payload.containsKey('token')) {
      payload['token'] = token;
    }
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map && decoded.containsKey('rows')) {
          final rows = decoded['rows'];
          if (rows is List) return rows;
        }
      }
    }
    return [];
  }
}
