import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';

typedef WebSocketChannelHandler = void Function(WebSocketChannel channel);

/// Embedded WebSocket server hosted on the host device.
class HostWebSocketServer {
  HttpServer? _server;
  int _actualPort = AppConstants.defaultPort;
  final WebSocketChannelHandler onClientConnected;
  bool _isWebRunning = false;

  HostWebSocketServer({required this.onClientConnected});

  int get port => _actualPort;
  bool get isRunning => kIsWeb ? _isWebRunning : _server != null;

  /// Starts the server, attempting [startPort] and auto-incrementing if bound.
  Future<int> start({int startPort = AppConstants.defaultPort}) async {
    await stop();

    if (kIsWeb) {
      _actualPort = startPort;
      _isWebRunning = true;
      return _actualPort;
    }

    final wsHandler = webSocketHandler((WebSocketChannel channel, String? _) {
      onClientConnected(channel);
    });

    int currentPort = startPort;
    const maxAttempts = 15;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        _server = await shelf_io.serve(
          wsHandler,
          InternetAddress.anyIPv4,
          currentPort,
        );
        _actualPort = _server!.port;
        return _actualPort;
      } on SocketException {
        currentPort++;
      } catch (_) {
        currentPort++;
      }
    }

    throw SocketException(
      'Не удалось запустить сервер: все порты с $startPort по $currentPort заняты.',
    );
  }

  /// Returns all active, non-loopback IPv4 addresses of this device,
  /// ranked by connectivity preference:
  /// 1. Physical Wi-Fi / AP (wlan*, en0, ap*, eth*)
  /// 2. Standard private subnets (192.168.*, 10.*, 172.16-31.*)
  /// 3. CGNAT / Mesh VPNs (100.64/10)
  /// 4. Virtual tunnels (tun*, wg*, utun*, ppp*) as last resort
  static Future<List<String>> getHostIpAddresses() async {
    if (kIsWeb) {
      return ['127.0.0.1'];
    }

    final candidates = <({String interfaceName, String address})>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            candidates.add((interfaceName: interface.name, address: addr.address));
          }
        }
      }
    } catch (_) {}

    final ranked = rankIpCandidates(candidates);
    if (ranked.isEmpty) {
      return ['127.0.0.1'];
    }
    return ranked;
  }

  /// Pure ranking function for IP candidates.
  static List<String> rankIpCandidates(
    List<({String interfaceName, String address})> candidates,
  ) {
    if (candidates.isEmpty) return const [];

    final scored = candidates.map((c) {
      return (
        address: c.address,
        score: _scoreCandidate(c.interfaceName.toLowerCase(), c.address),
      );
    }).toList();

    scored.sort((a, b) => a.score.compareTo(b.score));

    // Deduplicate addresses while preserving ranked order
    final seen = <String>{};
    final result = <String>[];
    for (final item in scored) {
      if (seen.add(item.address)) {
        result.add(item.address);
      }
    }
    return result;
  }

  static int _scoreCandidate(String ifName, String ip) {
    // Demoted VPN / Tunnel interfaces
    if (ifName.startsWith('tun') ||
        ifName.startsWith('wg') ||
        ifName.startsWith('utun') ||
        ifName.startsWith('ppp') ||
        ifName.startsWith('tap') ||
        ifName.startsWith('tailscale') ||
        ifName.startsWith('zt')) {
      return 90;
    }

    // Link-local address
    if (ip.startsWith('169.254.')) {
      return 99;
    }

    // Preferred physical Wi-Fi & Hotspot interfaces
    if (ifName.startsWith('wlan')) return 10;
    if (ifName == 'en0') return 11;
    if (ifName.startsWith('ap') || ifName.startsWith('swlan')) return 12;
    if (ifName.startsWith('en') || ifName.startsWith('eth')) return 15;

    // CGNAT / Tailscale 100.64.0.0/10
    if (_isCgnat(ip)) {
      return 80;
    }

    // Standard private LAN subnets
    if (ip.startsWith('192.168.')) return 30;
    if (ip.startsWith('10.')) return 31;
    if (_isPrivate172(ip)) return 32;

    return 50;
  }

  static bool _isCgnat(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    if (parts[0] != '100') return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 64 && second <= 127;
  }

  static bool _isPrivate172(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    if (parts[0] != '172') return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }

  /// Detects if the device is running a hotspot while a full-tunnel VPN is active.
  static Future<bool> isHotspotWithVpnActive() async {
    if (kIsWeb) return false;
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      var hasHotspot = false;
      var hasVpn = false;

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.startsWith('ap') || name.startsWith('swlan')) {
          hasHotspot = true;
        }
        for (final addr in iface.addresses) {
          if (addr.address == '192.168.43.1' || addr.address == '172.20.10.1') {
            hasHotspot = true;
          }
        }
        if (name.startsWith('tun') ||
            name.startsWith('wg') ||
            name.startsWith('utun') ||
            name.startsWith('ppp') ||
            name.startsWith('tailscale')) {
          hasVpn = true;
        }
      }

      return hasHotspot && hasVpn;
    } catch (_) {
      return false;
    }
  }

  /// Shuts down the active server instance.
  Future<void> stop() async {
    if (kIsWeb) {
      _isWebRunning = false;
      return;
    }

    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
  }
}
