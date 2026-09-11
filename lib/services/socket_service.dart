import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:io' show Platform;

/// Real-time WebSocket service that connects to the backend Socket.IO server
/// for live queue updates. Falls back gracefully if connection fails —
/// the QueueProvider's 5-second polling acts as the safety net.
class SocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  String? _patientId;
  VoidCallback? _onQueueUpdated;
  void Function(Map<String, dynamic>)? _onNotification;

  static String get _wsBaseUrl {
    if (kIsWeb) return 'ws://127.0.0.1:3000';
    return 'ws://${Platform.isAndroid ? '10.0.2.2' : '127.0.0.1'}:3000';
  }

  /// Connect to the WebSocket server and join the patient's queue room.
  void connect({
    required String patientId,
    VoidCallback? onQueueUpdated,
    void Function(Map<String, dynamic>)? onNotification,
  }) {
    _patientId = patientId;
    _onQueueUpdated = onQueueUpdated;
    _onNotification = onNotification;
    _doConnect();
  }

  void _doConnect() {
    if (_disposed) return;

    try {
      // Socket.IO uses a specific transport path; for simplicity we use
      // the polling-based fallback approach since the web_socket_channel
      // package doesn't speak the Socket.IO protocol natively.
      // Instead, we connect via the EIO websocket transport.
      final uri = Uri.parse(
        '$_wsBaseUrl/socket.io/?EIO=4&transport=websocket',
      );

      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('Socket error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('Socket disconnected');
          _scheduleReconnect();
        },
      );

      debugPrint('Socket connecting to $uri');
    } catch (e) {
      debugPrint('Socket connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    final message = raw.toString();

    // Socket.IO protocol: '0' = connect, '2' = ping, '3' = pong
    // '42' = event message
    if (message == '2') {
      // Respond to ping with pong
      _channel?.sink.add('3');
      return;
    }

    if (message.startsWith('0')) {
      // Connected — join the patient queue room
      debugPrint('Socket connected, joining patient room');
      if (_patientId != null) {
        _sendEvent('join_queue', {'patientId': _patientId});
      }
      return;
    }

    if (message.startsWith('42')) {
      // Event message: 42["event_name", data]
      try {
        final jsonStr = message.substring(2);
        final parsed = jsonDecode(jsonStr) as List;
        final eventName = parsed[0] as String;
        final data = parsed.length > 1 ? parsed[1] : null;

        if (eventName == 'queue:updated' && data is Map<String, dynamic>) {
          final action = data['type'] as String?;

          if (action == 'notification' && _onNotification != null) {
            final notification = data['notification'] as Map<String, dynamic>?;
            if (notification != null) {
              _onNotification!(notification);
            }
          }

          // Trigger queue data refresh for any queue update
          _onQueueUpdated?.call();
        }
      } catch (e) {
        debugPrint('Socket parse error: $e');
      }
    }
  }

  void _sendEvent(String event, Map<String, dynamic> data) {
    try {
      final payload = '42${jsonEncode([event, data])}';
      _channel?.sink.add(payload);
    } catch (e) {
      debugPrint('Socket send error: $e');
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 10), () {
      if (!_disposed) _doConnect();
    });
  }

  /// Disconnect and clean up all resources.
  void disconnect() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
