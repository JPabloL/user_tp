import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  ApiService({
    String? apiUrl,
    String? apiCal,
    String? apiCdb,
    String? token,
  })  : apiUrl = apiUrl ?? 'https://cuerposallimite.net/api',
        apiCal = apiCal ?? 'https://api.baldek.com',
        apiCdb = apiCdb ?? 'https://server.cuerposallimite.net',
        token = token ?? '3es_ldo5%4d';

  final String apiUrl;
  final String apiCal;
  final String apiCdb;
  final String token;

  Future<Map<String, dynamic>> migrateUser(String email, String pass) async {
    final uri = Uri.parse('$apiCdb/auth/migrate');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'email': email,
        'password': pass,
      }),
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

  Future<Map<String, dynamic>> createRoleProfile({
    required String uid,
    required String role,
  }) async {
    final uri = Uri.parse('$apiCdb/api/createRoleProfile');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'uid': uid,
        'role': role,
      }),
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
    final endpoint = side == 'back' ? 'uploadIdentityBack' : 'uploadIdentityFront';
    final uri = Uri.parse('$apiCdb/$endpoint/$uid');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: 'id-$side.jpg',
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

  Future<Map<String, dynamic>> createChildProfile(Map<String, dynamic> payload) async {
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
      ..files.add(http.MultipartFile.fromBytes('profilePhoto', bytes, filename: 'profile.jpg'));
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
      ..files.add(http.MultipartFile.fromBytes('docPhoto', docBytes, filename: 'doc.jpg'));
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
      ..files.add(http.MultipartFile.fromBytes('docPhoto', docBytes, filename: 'doc.jpg'));
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
      throw Exception(errorBody['message'] ?? 'Error HTTP ${response.statusCode}');
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
      ..files.add(http.MultipartFile.fromBytes('publicPhoto', bytes, filename: 'profile.jpg'));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
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
}
