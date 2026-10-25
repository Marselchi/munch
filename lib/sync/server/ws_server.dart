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

  /// Returns all active, non-loopback IPv4 addresses of this device.
  static Future<List<String>> getHostIpAddresses() async {
    if (kIsWeb) {
      return ['127.0.0.1'];
    }

    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            ips.add(addr.address);
          }
        }
      }
    } catch (_) {}

    if (ips.isEmpty) {
      ips.add('127.0.0.1');
    }
    return ips;
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
