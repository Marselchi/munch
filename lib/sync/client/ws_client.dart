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

  /// Races candidate IPs in parallel with a fast timeout (~1s).
  /// Returns the first established connection; any other attempts are cleanly closed.
  Future<(WebSocketChannel, String)> raceCandidates(
    List<String> ips,
    int port, {
    Duration timeout = const Duration(seconds: 1),
  }) async {
    if (ips.isEmpty) {
      throw TimeoutException('Список IP кандидатов пуст.');
    }
    if (ips.length == 1) {
      final ch = await connectSingle(ips.first, port, timeout: timeout);
      return (ch, ips.first);
    }

    final completer = Completer<(WebSocketChannel, String)>();
    var remaining = ips.length;

    for (final ip in ips) {
      connectSingle(ip, port, timeout: timeout).then((channel) {
        if (!completer.isCompleted) {
          completer.complete((channel, ip));
        } else {
          try {
            channel.sink.close();
          } catch (_) {}
        }
      }).catchError((_) {
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.completeError(
            TimeoutException('Не удалось подключиться ни к одному из IP ведущего: $ips'),
          );
        }
      });
    }

    return completer.future;
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
