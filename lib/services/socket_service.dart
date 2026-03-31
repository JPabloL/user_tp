import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService({String? url}) {
    if (url != null && url.isNotEmpty && _instance._url != url) {
      _instance._reconfigure(url);
    }
    return _instance;
  }

  SocketService._internal() {
    _init();
  }

  String _url = 'https://server.cuerposallimite.net';
  late io.Socket _socket;
  final _requestUpdatesController = StreamController<dynamic>.broadcast();
  final _matchUpdatesController = StreamController<dynamic>.broadcast();

  Stream<dynamic> get requestUpdates => _requestUpdatesController.stream;
  Stream<dynamic> get requestUpdatesStream => _requestUpdatesController.stream;
  Stream<dynamic> get matchUpdates => _matchUpdatesController.stream;

  void _reconfigure(String url) {
    disconnect();
    _url = url;
    _init();
  }

  void _init() {
    _socket = io.io(
      _url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .build(),
    );
    _initListeners();
  }

  void _initListeners() {
    _socket.onConnect((_) {});
    _socket.onDisconnect((_) {});
    _socket.on('request_updated', (data) {
      _requestUpdatesController.add(data);
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
        _matchUpdatesController.add({
          'event': event,
          'data': data,
        });
      });
    }
  }

  void joinRoom(String id) {
    if (id.isEmpty) return;
    connect();
    _socket.emit('join_id', id);
  }

  Stream<dynamic> watchRequests(String playerId) {
    joinRoom(playerId);
    return onEvent('request_updated');
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

  void disconnect() {
    _socket.disconnect();
  }

  void connect() {
    if (!_socket.connected) {
      _socket.connect();
    }
  }

  void dispose() {
    _requestUpdatesController.close();
    _matchUpdatesController.close();
    disconnect();
  }
}
