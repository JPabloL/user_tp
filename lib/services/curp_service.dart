import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

    await _checkLocalRestrictions(cleanCurp);

    final localRes = await _checkLocalStatus(cleanCurp);
    final localStatus = localRes['status']?.toString() ?? '';

    if (localStatus == 'exists_as_player') {
      final data = localRes['data'] as Map<String, dynamic>? ?? {};
      final tutorObj = data['tutor'] as Map<String, dynamic>? ?? {};
      final tutorName = tutorObj['name'] ?? tutorObj['alias'] ?? localRes['tutorName'] ?? 'Otro tutor';

      return {
        'source': 'player_exists',
        'data': data,
        'message': 'Este jugador ya está registrado.',
        'playerId': localRes['playerId'],
        'tutorName': tutorName,
        'recoveryMode': localRes['recoveryMode'],
        'accountType': localRes['accountType'],
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

  Future<void> _checkLocalRestrictions(String curp) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Revisar bloqueo por mantenimiento (1 hora)
    final lockoutTimestamp = prefs.getInt('curp_api_lockout_until') ?? 0;
    if (lockoutTimestamp > 0) {
      final lockoutDate = DateTime.fromMillisecondsSinceEpoch(lockoutTimestamp);
      if (DateTime.now().isBefore(lockoutDate)) {
        final diffMinutes = lockoutDate.difference(DateTime.now()).inMinutes;
        throw Exception('Servicio de validación en mantenimiento. Intenta de nuevo en $diffMinutes minutos.');
      } else {
        await prefs.remove('curp_api_lockout_until');
      }
    }

    // 2. Revisar si la CURP ya fue marcada como inválida
    final invalidCurps = prefs.getStringList('invalid_curps_list') ?? [];
    if (invalidCurps.contains(curp)) {
      throw Exception('CURP no encontrada en los registros oficiales de RENAPO.');
    }
  }

  Future<void> _registerInvalidCurp(String curp) async {
    final prefs = await SharedPreferences.getInstance();
    final invalidCurps = prefs.getStringList('invalid_curps_list') ?? [];
    if (!invalidCurps.contains(curp)) {
      invalidCurps.add(curp);
      await prefs.setStringList('invalid_curps_list', invalidCurps);
    }
  }

  Future<void> _registerApiLockout() async {
    final prefs = await SharedPreferences.getInstance();
    // Bloquear por 1 hora
    final lockoutUntil = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
    await prefs.setInt('curp_api_lockout_until', lockoutUntil);
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
    print('HTTP ${response.statusCode} - ${response.body}');
    
    // No usamos _decode aquí porque la API puede regresar 400 con el JSON del error
    Map<String, dynamic> raw = {};
    try {
      raw = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}
    
    print('RAW RENAPO RESPONSE: $raw');

    final codigoError = (raw['codigo_error'] ?? raw['code_error'])?.toString() ?? '';
    final errorMsg = (raw['error_message'] ?? (raw['error'] is String ? raw['error'] : ''))?.toString() ?? '';

    if (codigoError.isNotEmpty && codigoError != '0' && codigoError != '00' && codigoError != 'false') {
      String userFriendlyMessage = 'Error consultando CURP ($codigoError)';
      
      switch (codigoError) {
        case '1':
        case '2':
        case '3':
        case '4':
          // Errores internos de cuenta/token de la API (bloqueado, agotado, etc.)
          _registerApiLockout();
          userFriendlyMessage = 'Servicio en mantenimiento, intente más tarde.';
          break;
        case '101':
          _registerInvalidCurp(curp);
          userFriendlyMessage = 'La estructura de la CURP es inválida.';
          break;
        case '200':
          _registerApiLockout();
          userFriendlyMessage = 'Error de conexión con RENAPO, intente más tarde.';
          break;
        case '300':
          _registerInvalidCurp(curp);
          userFriendlyMessage = 'CURP no encontrada en los registros oficiales de RENAPO.';
          break;
        default:
          if (errorMsg.isNotEmpty && errorMsg != 'false' && errorMsg.toLowerCase() != 'null') {
             userFriendlyMessage = errorMsg;
          }
      }
      throw Exception(userFriendlyMessage);
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
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      print('save-curp-cache response status: ${response.statusCode}');
      print('save-curp-cache response body: ${response.body}');
    } catch (e) {
      print('Error saving to cache: $e');
    }
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
