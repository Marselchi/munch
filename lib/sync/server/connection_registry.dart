import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';

class ClientConnection {
  final String playerId;
  final String token;
  WebSocketChannel? channel;
  bool isConnected;
  int lastSentSeq;
  DateTime lastActivityAt;
  DateTime? disconnectedAt;

  ClientConnection({
    required this.playerId,
    required this.token,
    this.channel,
    this.isConnected = true,
    this.lastSentSeq = 0,
    DateTime? lastActivityAt,
    this.disconnectedAt,
  }) : lastActivityAt = lastActivityAt ?? DateTime.now();

  void recordActivity() {
    lastActivityAt = DateTime.now();
  }

  void markDisconnected() {
    isConnected = false;
    channel = null;
    disconnectedAt = DateTime.now();
  }

  void markConnected(WebSocketChannel newChannel) {
    channel = newChannel;
    isConnected = true;
    disconnectedAt = null;
    lastActivityAt = DateTime.now();
  }

  bool isSeatExpired(Duration gracePeriod) {
    if (isConnected || disconnectedAt == null) return false;
    return DateTime.now().difference(disconnectedAt!) > gracePeriod;
  }
}

/// Registry of client connections on the host.
/// Pure Dart (no Flutter imports).
class ConnectionRegistry {
  final Map<String, ClientConnection> _clients = {};
  Timer? _watchdogTimer;
  void Function(String playerId)? onPlayerTimedOut;
  void Function(String playerId)? onPlayerWatchdogDisconnected;

  void startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkWatchdogs());
  }

  void stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  void register({
    required String playerId,
    required String token,
    required WebSocketChannel channel,
  }) {
    final existing = _clients[playerId];
    if (existing != null) {
      // Disconnect old socket if any
      try {
        existing.channel?.sink.close();
      } catch (_) {}
      existing.markConnected(channel);
    } else {
      _clients[playerId] = ClientConnection(
        playerId: playerId,
        token: token,
        channel: channel,
        isConnected: true,
      );
    }
  }

  /// Restores a previously saved seat on session resume.
  void restoreSeat({
    required String playerId,
    required String token,
  }) {
    final existing = _clients[playerId];
    if (existing == null) {
      _clients[playerId] = ClientConnection(
        playerId: playerId,
        token: token,
        channel: null,
        isConnected: false,
        disconnectedAt: DateTime.now(),
      );
    }
  }

  ClientConnection? get(String playerId) => _clients[playerId];

  ClientConnection? findByToken(String token) {
    for (final c in _clients.values) {
      if (c.token == token) return c;
    }
    return null;
  }

  List<ClientConnection> get allConnections => _clients.values.toList();

  List<ClientConnection> get connectedClients =>
      _clients.values.where((c) => c.isConnected && c.channel != null).toList();

  void sendTo(String playerId, String message) {
    final client = _clients[playerId];
    if (client != null && client.isConnected && client.channel != null) {
      try {
        client.channel!.sink.add(message);
        client.recordActivity();
      } catch (_) {
        client.markDisconnected();
      }
    }
  }

  void broadcast(String message) {
    for (final client in connectedClients) {
      try {
        client.channel!.sink.add(message);
      } catch (_) {
        client.markDisconnected();
      }
    }
  }

  void remove(String playerId) {
    final client = _clients.remove(playerId);
    try {
      client?.channel?.sink.close();
    } catch (_) {}
  }

  void _checkWatchdogs() {
    final now = DateTime.now();

    for (final client in _clients.values) {
      // Host watchdog: no traffic for hostWatchdogTimeout -> mark disconnected
      if (client.isConnected) {
        if (now.difference(client.lastActivityAt) > AppConstants.hostWatchdogTimeout) {
          client.markDisconnected();
          onPlayerWatchdogDisconnected?.call(client.playerId);
        }
      }
      // Note: Seats are NOT auto-deleted after grace period.
      // Disconnected seats become claimable and persist until explicit host removal.
    }
  }

  void dispose() {
    stopWatchdog();
    for (final client in _clients.values) {
      try {
        client.channel?.sink.close();
      } catch (_) {}
    }
    _clients.clear();
  }
}
