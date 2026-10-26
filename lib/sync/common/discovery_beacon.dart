import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/constants/app_constants.dart';

/// Payload broadcasted by the table host over UDP LAN beacons.
class DiscoveryBeaconData {
  final String app;
  final String sid;
  final String name;
  final int epoch;
  final List<String> ips;
  final int port;

  const DiscoveryBeaconData({
    this.app = AppConstants.appMarker,
    required this.sid,
    required this.name,
    required this.epoch,
    required this.ips,
    required this.port,
  });

  Map<String, dynamic> toJson() => {
        'app': app,
        'sid': sid,
        'name': name,
        'epoch': epoch,
        'ips': ips,
        'port': port,
      };

  factory DiscoveryBeaconData.fromJson(Map<String, dynamic> json) =>
      DiscoveryBeaconData(
        app: json['app'] as String? ?? AppConstants.appMarker,
        sid: json['sid'] as String,
        name: json['name'] as String? ?? 'Стол Манчкин',
        epoch: json['epoch'] as int? ?? 0,
        ips: (json['ips'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        port: json['port'] as int? ?? AppConstants.defaultPort,
      );
}

/// UDP Broadcast Beacon emitter running on the authoritative host.
class HostBeaconBroadcaster {
  RawDatagramSocket? _socket;
  Timer? _timer;
  DiscoveryBeaconData? _currentData;
  bool _isBroadcasting = false;

  bool get isBroadcasting => _isBroadcasting;

  /// Starts broadcasting [data] every 2 seconds over LAN.
  Future<void> start(DiscoveryBeaconData data) async {
    if (kIsWeb) return;
    _currentData = data;
    await stop();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      _socket?.broadcastEnabled = true;
      _isBroadcasting = true;

      // Broadcast immediately and then periodically
      _sendBeacon();
      _timer = Timer.periodic(AppConstants.discoveryBeaconInterval, (_) {
        _sendBeacon();
      });
    } catch (_) {
      // Graceful degradation if UDP broadcast fails
      _isBroadcasting = false;
    }
  }

  /// Updates the beacon data dynamically (e.g. after epoch increment or IP change).
  void updateData(DiscoveryBeaconData newData) {
    _currentData = newData;
  }

  void _sendBeacon() {
    if (_socket == null || _currentData == null) return;
    try {
      final jsonStr = jsonEncode(_currentData!.toJson());
      final bytes = utf8.encode(jsonStr);

      // Send to local network broadcast address
      _socket!.send(
        bytes,
        InternetAddress('255.255.255.255'),
        AppConstants.discoveryPort,
      );
    } catch (_) {}
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    _isBroadcasting = false;
  }
}

/// UDP Broadcast Beacon listener running on client devices.
class ClientBeaconListener {
  RawDatagramSocket? _socket;
  bool _isListening = false;
  void Function(DiscoveryBeaconData beacon)? onBeaconReceived;

  bool get isListening => _isListening;

  /// Starts listening for table discovery beacons.
  Future<void> start() async {
    if (kIsWeb) return;
    await stop();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.discoveryPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      _isListening = true;

      _socket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = _socket?.receive();
            if (datagram != null) {
              _processDatagram(datagram);
            }
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {
      _isListening = false;
    }
  }

  void _processDatagram(Datagram datagram) {
    try {
      final text = utf8.decode(datagram.data);
      final json = jsonDecode(text) as Map<String, dynamic>;
      if (json['app'] == AppConstants.appMarker) {
        final beacon = DiscoveryBeaconData.fromJson(json);
        onBeaconReceived?.call(beacon);
      }
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    _isListening = false;
  }
}
