import 'dart:math' as math;

/// Manages exponential backoff and IP rotation for client reconnection.
/// Pure Dart (no Flutter imports).
class ReconnectPolicy {
  List<String> hostIps;
  int port;

  int _attemptCount = 0;
  int _currentIpIndex = 0;
  final math.Random _random = math.Random();

  ReconnectPolicy({
    required this.hostIps,
    required this.port,
  });

  int get attemptCount => _attemptCount;

  /// Updates candidate IPs and port upon host migration or beacon discovery.
  void updateCandidates(List<String> newIps, int newPort) {
    hostIps = List.from(newIps);
    port = newPort;
    _currentIpIndex = 0;
    reset();
  }

  /// Returns the next candidate IP to try and advances the rotation.
  String nextIp() {
    if (hostIps.isEmpty) return '127.0.0.1';
    final ip = hostIps[_currentIpIndex % hostIps.length];
    _currentIpIndex++;
    return ip;
  }

  /// Calculates the backoff delay:
  /// 1s -> 2s -> 4s -> 8s -> 15s cap, with ±20% jitter.
  Duration nextDelay() {
    _attemptCount++;
    // Base backoff: 2^(attempt - 1), capped at 15
    final baseSeconds = math.min(15, math.pow(2, _attemptCount - 1).toInt());

    // ±20% jitter: range [0.8, 1.2]
    final jitterFactor = 0.8 + (_random.nextDouble() * 0.4);
    final ms = (baseSeconds * 1000 * jitterFactor).round();

    return Duration(milliseconds: math.max(500, ms));
  }

  /// Resets backoff count (e.g. after successful connection).
  void reset() {
    _attemptCount = 0;
  }
}
