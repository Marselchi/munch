import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Platform channel wrapper to bind network process to physical Wi-Fi (excluding VPN).
abstract final class NetworkBinder {
  static const MethodChannel _channel =
      MethodChannel('com.munchkin.munchkin_companion/network');

  /// Requests the Android OS to bind socket operations for this process
  /// to the physical Wi-Fi network (NET_CAPABILITY_NOT_VPN).
  static Future<bool> bindToPhysicalWifi() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('bindToPhysicalWifi');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Unbinds process sockets from physical Wi-Fi, returning to system default routing.
  static Future<void> unbindFromNetwork() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('unbindFromNetwork');
    } catch (_) {}
  }

  /// Checks if an active VPN tunnel is detected on the device.
  static Future<bool> isVpnActive() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isVpnActive');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
