import 'dart:async';
import '../../core/constants/app_constants.dart';

/// Client-side ping timer and watchdog for silent connection loss detection.
/// Pure Dart (no Flutter imports).
class ClientHeartbeat {
  final void Function() sendPing;
  final void Function() onWatchdogTimeout;

  Timer? _pingTimer;
  Timer? _watchdogTimer;
  DateTime _lastTrafficReceived = DateTime.now();

  ClientHeartbeat({
    required this.sendPing,
    required this.onWatchdogTimeout,
  });

  void start() {
    stop();
    _lastTrafficReceived = DateTime.now();

    _pingTimer = Timer.periodic(AppConstants.pingInterval, (_) {
      sendPing();
    });

    _watchdogTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (DateTime.now().difference(_lastTrafficReceived) >
          AppConstants.clientWatchdogTimeout) {
        stop();
        onWatchdogTimeout();
      }
    });
  }

  void recordTraffic() {
    _lastTrafficReceived = DateTime.now();
  }

  void stop() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }
}
