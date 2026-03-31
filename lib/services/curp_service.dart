import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class CurpService {
  CurpService(this.api);

  final ApiService api;

  static const bool _isTestMode = false;
  static const String _apiExternalUrl =
      'https://api.valida-curp.com.mx/curp/obtener_datos/';
  static const String _testToken = 'pruebas';
  static const String _prodToken = '8c5f4e3b-2adf-4655-8f62-149ca1a811b5';
  static const String _genericCurp = 'XAXX010101XAXAXA00';

  Future<Map<String, dynamic>> getDetails(String curp) async {
    final cleanCurp = curp.trim().toUpperCase();

    if (!_isValidFormat(cleanCurp)) {
      throw Exception('El formato de la CURP es incorrecto. Revisa los caracteres.');
    }

    final localRes = await _checkLocalStatus(cleanCurp);
    final localStatus = localRes['status']?.toString() ?? '';

    if (localStatus == 'exists_as_player') {
      return {
        'source': 'player_exists',
        'data': localRes['data'],
        'message': 'Este jugador ya está registrado.',
        'playerId': localRes['playerId'],
        'tutorName': localRes['tutorName'],
      };
    }

    if (localStatus == 'found_in_cache') {
      return {
        'source': 'cache',
        'data': localRes['data'],
      };
    }

    final externalData = await _fetchExternal(cleanCurp);
    await _saveToCache(cleanCurp, externalData);
    return {
      'source': 'external',
      'data': externalData,
    };
  }

  bool _isValidFormat(String curp) {
    if (_isTestMode && curp == _genericCurp) return true;
    if (curp.length != 18) return false;
    final re = RegExp(r'^[A-Z]{4}\d{6}[HM][A-Z]{2}[A-Z]{3}[A-Z0-9]{2}$');
    return re.hasMatch(curp);
  }

  Future<Map<String, dynamic>> _checkLocalStatus(String curp) async {
    final uri = Uri.parse('${api.apiCdb}/check-curp-status/$curp');
    final response = await http.get(uri);
    final body = _decode(response);
    return body;
  }

  Future<Map<String, dynamic>> _fetchExternal(String curp) async {
    final token = _isTestMode ? _testToken : _prodToken;
    final curpToSend = curp;
    final uri = Uri.parse('$_apiExternalUrl?token=$token&curp=$curpToSend');

    final response = await http.get(uri);
    final raw = _decode(response);

    if (raw['codigo_error'] != null || raw['error'] != null) {
      throw Exception('CURP no encontrada en RENAPO.');
    }

    final rawData = (raw['response'] as Map<String, dynamic>?) ?? raw;
    final finalData = (rawData['Solicitante'] as Map<String, dynamic>?) ?? rawData;

    if ((finalData['Nombres'] == null || finalData['Nombres'].toString().isEmpty) &&
        (finalData['nombres'] == null || finalData['nombres'].toString().isEmpty)) {
      throw Exception('Respuesta inválida de RENAPO.');
    }
    return finalData;
  }

  Future<void> _saveToCache(String curp, Map<String, dynamic> data) async {
    final payload = <String, dynamic>{
      ...data,
      '_id': 'curp:$curp',
      'type': 'curp',
      'updated_at': DateTime.now().toIso8601String(),
    };
    final uri = Uri.parse('${api.apiCdb}/save-curp-cache');
    try {
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (_) {}
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
