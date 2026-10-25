import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReconnectSessionData {
  final String sessionId;
  final String playerId;
  final String token;
  final List<String> hostIps;
  final int port;
  final String playerName;

  const ReconnectSessionData({
    required this.sessionId,
    required this.playerId,
    required this.token,
    required this.hostIps,
    required this.port,
    required this.playerName,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'playerId': playerId,
        'token': token,
        'hostIps': hostIps,
        'port': port,
        'playerName': playerName,
      };

  factory ReconnectSessionData.fromJson(Map<String, dynamic> json) =>
      ReconnectSessionData(
        sessionId: json['sessionId'] as String,
        playerId: json['playerId'] as String,
        token: json['token'] as String,
        hostIps: (json['hostIps'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        port: json['port'] as int? ?? 8787,
        playerName: json['playerName'] as String? ?? 'Игрок',
      );
}

abstract final class SettingsStore {
  static const String _keyLastName = 'last_player_name';
  static const String _keyRecentIps = 'recent_host_ips';
  static const String _keyActiveSession = 'active_reconnect_session';

  static Future<String?> getLastPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastName);
  }

  static Future<void> setLastPlayerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastName, name.trim());
  }

  static Future<List<String>> getRecentHostIps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyRecentIps) ?? const [];
  }

  static Future<void> addRecentHostIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_keyRecentIps) ?? []).toSet();
    list.add(ip);
    await prefs.setStringList(_keyRecentIps, list.toList());
  }

  static Future<void> saveActiveReconnectSession(ReconnectSessionData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveSession, jsonEncode(data.toJson()));
  }

  static Future<ReconnectSessionData?> getActiveReconnectSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyActiveSession);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return ReconnectSessionData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearActiveReconnectSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActiveSession);
  }
}
