import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';

/// Pure Dart WebSocket client with IP trial and connect timeout.
class WebSocketClient {
  WebSocketChannel? _channel;

  WebSocketChannel? get channel => _channel;
  bool get isConnected => _channel != null;

  /// Attempts to connect to `ws://<ip>:<port>`.
  Future<WebSocketChannel> connectSingle(
    String ip,
    int port, {
    Duration timeout = AppConstants.connectTimeout,
  }) async {
    final uri = Uri.parse('ws://$ip:$port');
    final channel = WebSocketChannel.connect(uri);

    // Await ready with timeout
    await channel.ready.timeout(timeout);
    _channel = channel;
    return channel;
  }

  /// Tries candidate IPs in order, returning the first successful connection.
  Future<(WebSocketChannel, String)> connectAny(
    List<String> ips,
    int port, {
    Duration timeout = AppConstants.connectTimeout,
  }) async {
    for (final ip in ips) {
      try {
        final channel = await connectSingle(ip, port, timeout: timeout);
        return (channel, ip);
      } catch (_) {
        // Try next IP
      }
    }
    throw TimeoutException('Не удалось подключиться ни к одному IP ведущего: $ips');
  }

  void disconnect() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
