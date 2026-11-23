import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import 'api_client.dart';

/// A live event from the server (offer countered, message, notification...).
class LiveEvent {
  LiveEvent(this.name, this.data);
  final String name;
  final Map<String, dynamic> data;
}

/// The Socket.IO connection. It authenticates with a short-lived token from
/// GET /auth/socket-token, re-fetched on every (re)connect, and relays the
/// negotiation and notification events to whoever listens.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  static const _events = [
    'offer-countered', 'offer-revised', 'offer-accepted', 'offer-rejected',
    'negotiation-message', 'design-updated', 'notification',
  ];

  io.Socket? _socket;
  final _controller = StreamController<LiveEvent>.broadcast();
  final Set<String> _rooms = {};

  Stream<LiveEvent> get events => _controller.stream;

  void connect() {
    if (_socket != null) return;
    final s = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setAuthFn((cb) async {
            try {
              final res = await Api.instance.get('/auth/socket-token');
              cb({'token': res['socketToken']});
            } catch (_) {
              cb({});
            }
          })
          .build(),
    );
    for (final name in _events) {
      s.on(name, (data) {
        if (data is Map) _controller.add(LiveEvent(name, Map<String, dynamic>.from(data)));
      });
    }
    s.onConnect((_) {
      for (final room in _rooms) {
        s.emit('join-negotiation', room);
      }
    });
    s.connect();
    _socket = s;
  }

  void joinBooking(String bookingId) {
    _rooms.add(bookingId);
    _socket?.emit('join-negotiation', bookingId);
  }

  void leaveBooking(String bookingId) {
    _rooms.remove(bookingId);
    _socket?.emit('leave-negotiation', bookingId);
  }

  void disconnect() {
    _rooms.clear();
    _socket?.dispose();
    _socket = null;
  }
}
