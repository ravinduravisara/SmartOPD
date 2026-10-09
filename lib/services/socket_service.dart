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
  bool _isSocketIoConnected = false;

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
    _disposed = false;
    _doConnect();
  }

  /// Update active patient ID and join the room if already connected.
  void updatePatientId(String patientId) {
    _patientId = patientId;
    if (_isSocketIoConnected) {
      _sendEvent('join_queue', {'patientId': patientId});
    }
  }

  void _doConnect() {
    if (_disposed) return;

    _reconnectTimer?.cancel();
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isSocketIoConnected = false;

    try {
      final uri = Uri.parse(
        '$_wsBaseUrl/socket.io/?EIO=4&transport=websocket',
      );

      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('Socket error: $error');
          _isSocketIoConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('Socket disconnected');
          _isSocketIoConnected = false;
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

    // Engine.IO protocol: '0' = open, '2' = ping, '3' = pong
    if (message == '2') {
      // Respond to ping with pong
      _channel?.sink.add('3');
      return;
    }

    // Engine.IO open handshake: send Socket.IO CONNECT packet '40' to namespace '/'
    if (message.startsWith('0')) {
      _channel?.sink.add('40');
      return;
    }

    // Socket.IO namespace connected
    if (message.startsWith('40')) {
      _isSocketIoConnected = true;
      debugPrint('Socket connected, joining patient room');
      if (_patientId != null) {
        _sendEvent('join_queue', {'patientId': _patientId});
      }
      return;
    }

    // Socket.IO event message: 42["event_name", data]
    if (message.startsWith('42')) {
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
    _isSocketIoConnected = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
