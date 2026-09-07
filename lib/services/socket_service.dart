import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

/// Estado de la conexión Socket.IO para indicadores en UI.
enum SocketConnectionState {
  connected,
  connecting,
  disconnected,
  reconnecting,
}

/// Cliente Socket.IO alineado al `index.js` del servidor (puerto 38000 / mismo host HTTPS).
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  SocketService._internal() {
    _init();
  }

  late io.Socket _socket;
  final String _url = AppConfig.socketUrl;

  final _requestUpdatesController = StreamController<dynamic>.broadcast();
  final _userContextController = StreamController<dynamic>.broadcast();
  final _profileUpdatesController = StreamController<dynamic>.broadcast();
  final _matchUpdatesController = StreamController<dynamic>.broadcast();
  final _connectionStateController =
      StreamController<SocketConnectionState>.broadcast();

  Stream<dynamic> get requestUpdates => _requestUpdatesController.stream;
  Stream<dynamic> get requestUpdatesStream => _requestUpdatesController.stream;
  Stream<dynamic> get userContextStream => _userContextController.stream;
  Stream<dynamic> get profileUpdatesStream => _profileUpdatesController.stream;
  Stream<dynamic> get matchUpdates => _matchUpdatesController.stream;
  Stream<SocketConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  SocketConnectionState _connectionState = SocketConnectionState.disconnected;
  SocketConnectionState get connectionState => _connectionState;
  int _reconnectionAttempt = 0;
  int get reconnectionAttempt => _reconnectionAttempt;
  bool get isConnected => _socket.connected;

  final Set<String> _joinedUsers = {};
  final Set<String> _joinedPlayers = {};
  final Set<String> _joinedTeams = {};
  final Set<String> _joinedMatches = {};

  void _init() {
    _socket = io.io(
      _url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(100)
          .setReconnectionDelay(3000)
          .setReconnectionDelayMax(60000)
          .build(),
    );
    _initListeners();
  }

  void _setConnectionState(SocketConnectionState state) {
    _connectionState = state;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(state);
    }
  }

  void _initListeners() {
    _socket.onConnect((_) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Socket conectado: ${_socket.id}');
      }
      _isConnecting = false;
      _reconnectionAttempt = 0;
      _setConnectionState(SocketConnectionState.connected);
      _rejoinAllRooms();
    });

    _socket.onDisconnect((_) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Socket desconectado');
      }
      _isConnecting = false;
      _setConnectionState(SocketConnectionState.disconnected);
    });

    _socket.onConnectError((dynamic error) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Socket error de conexión: $error');
      }
      _isConnecting = false;
      _setConnectionState(SocketConnectionState.reconnecting);
    });

    _socket.on('reconnect_attempt', (dynamic attempt) {
      _reconnectionAttempt = _parseAttempt(attempt);
      if (kDebugMode) {
        // ignore: avoid_print
        print('Socket reconectando (intento $_reconnectionAttempt)...');
      }
      _setConnectionState(SocketConnectionState.reconnecting);
    });

    _socket.on('reconnect', (_) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Socket reconectado');
      }
      _reconnectionAttempt = 0;
      _setConnectionState(SocketConnectionState.connected);
    });

    _socket.on('reconnect_failed', (_) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Socket: reconexión fallida');
      }
      _isConnecting = false;
      _setConnectionState(SocketConnectionState.disconnected);
    });

    _socket.on('reconnect_error', (dynamic error) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Socket error al reconectar: $error');
      }
      _setConnectionState(SocketConnectionState.reconnecting);
    });

    _socket.on('reconnecting', (_) {
      _setConnectionState(SocketConnectionState.reconnecting);
    });

    // Solicitudes de equipo (mood / academia)
    _socket.on('request_updated', (data) {
      _requestUpdatesController.add(data);
    });

    // Tutor / dueño: refresh dashboard (assignPlayerToTeam, etc.)
    _socket.on('user_context_update', (data) {
      _userContextController.add(data);
    });

    // Jugador: nuevo equipo en su perfil
    _socket.on('profile_update', (data) {
      _profileUpdatesController.add(data);
    });

    const matchEvents = [
      'match_score_refresh',
      'match_list_refresh',
      'match_live_update',
      'match_action_added',
      'match_action_deleted',
      'match_mvp_updated',
      'tournament_score_update',
      'attendance_updated',
    ];

    for (final event in matchEvents) {
      _socket.on(event, (data) {
        _matchUpdatesController.add({'event': event, 'data': data});
      });
    }
  }

  void _rejoinAllRooms() {
    for (final userId in _joinedUsers) {
      _emitJoinUser(userId);
    }
    for (final playerId in _joinedPlayers) {
      _emitJoinPlayer(playerId);
    }
    for (final teamId in _joinedTeams) {
      _emitJoinTeam(teamId);
    }
    for (final matchId in _joinedMatches) {
      _emitJoinMatch(matchId);
    }
  }

  void _emitJoinMatch(String matchId) {
    final id = matchId.trim();
    if (id.isEmpty) return;
    _socket.emit('join_match', id);
    _socket.emit('join_id', id);
  }

  void _emitJoinUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return;
    _socket.emit('join_user', id);
    _socket.emit('join_id', id);
  }

  void _emitJoinPlayer(String playerId) {
    final id = playerId.trim();
    if (id.isEmpty) return;
    _socket.emit('join_player', id);
    _socket.emit('join_id', id);
  }

  void _emitJoinTeam(String teamId) {
    final id = teamId.trim();
    if (id.isEmpty) return;
    _socket.emit('join_team', id);
    _socket.emit('join_id', id);
  }

  /// Sala del usuario tutor (`user:...`) + jugadores hijos/propios.
  void joinTutorSession({
    required String userId,
    required Iterable<String> playerIds,
  }) {
    connect();
    joinUser(userId);
    for (final playerId in playerIds) {
      joinPlayer(playerId);
    }
  }

  void joinUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return;
    _joinedUsers.add(id);
    if (_socket.connected) _emitJoinUser(id);
  }

  void joinPlayer(String playerId) {
    final id = playerId.trim();
    if (id.isEmpty) return;
    _joinedPlayers.add(id);
    if (_socket.connected) _emitJoinPlayer(id);
  }

  void joinTeam(String teamId) {
    final id = teamId.trim();
    if (id.isEmpty) return;
    _joinedTeams.add(id);
    if (_socket.connected) _emitJoinTeam(id);
  }

  void joinMatch(String matchId) {
    final id = matchId.trim();
    if (id.isEmpty) return;
    _joinedMatches.add(id);
    if (_socket.connected) _emitJoinMatch(id);
  }

  /// Compatibilidad: equivale a join genérico del servidor (`join_id`).
  void joinRoom(String id) {
    final room = id.trim();
    if (room.isEmpty) return;
    if (room.startsWith('user:')) {
      joinUser(room);
      return;
    }
    joinPlayer(room);
  }

  void disconnect() {
    _socket.disconnect();
  }

  bool _isConnecting = false;

  void connect() {
    if (_socket.connected) {
      _setConnectionState(SocketConnectionState.connected);
      return;
    }
    if (!_isConnecting) {
      _isConnecting = true;
      _setConnectionState(SocketConnectionState.connecting);
      _socket.connect();
      Future.delayed(const Duration(seconds: 2), () => _isConnecting = false);
    }
  }

  int _parseAttempt(dynamic attempt) {
    if (attempt is int) return attempt;
    if (attempt is num) return attempt.toInt();
    return int.tryParse(attempt?.toString() ?? '') ?? _reconnectionAttempt;
  }

  Stream<dynamic> watchRequests(String playerId) {
    joinPlayer(playerId);
    return requestUpdates;
  }

  Stream<dynamic> onEvent(String eventName) {
    late StreamController<dynamic> controller;
    late void Function(dynamic) handler;
    controller = StreamController<dynamic>.broadcast(
      onListen: () {
        handler = (data) => controller.add(data);
        _socket.on(eventName, handler);
      },
      onCancel: () {
        _socket.off(eventName, handler);
      },
    );
    return controller.stream;
  }

  static bool isTeamAssignmentEvent(dynamic data) {
    if (data is! Map) return false;
    final map = Map<String, dynamic>.from(data);
    final type = (map['type'] ?? map['tipo'] ?? '').toString().toLowerCase();
    return type == 'team_assignment' ||
        type == 'new_team' ||
        map['reason']?.toString() == 'team_assignment';
  }

  static String? eventPlayerId(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final id = (map['playerId'] ?? map['player_id'] ?? '').toString().trim();
    return id.isEmpty ? null : id;
  }

  static String? eventPlayerName(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final name = (map['playerName'] ?? map['player_name'] ?? '').toString().trim();
    return name.isEmpty ? null : name;
  }
}
