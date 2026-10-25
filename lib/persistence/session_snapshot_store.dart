import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../sync/protocol/models.dart';

abstract final class SessionSnapshotStore {
  static const String _prefPrefix = 'session_snapshot_';
  static const String _prefIndexKey = 'session_snapshot_ids';

  /// Persists a session snapshot to storage.
  static Future<void> saveSnapshot(SessionSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(snapshot.toJson());
      await prefs.setString('$_prefPrefix${snapshot.sessionId}', jsonStr);

      final ids = prefs.getStringList(_prefIndexKey) ?? <String>[];
      if (!ids.contains(snapshot.sessionId)) {
        ids.add(snapshot.sessionId);
        await prefs.setStringList(_prefIndexKey, ids);
      }
    } catch (_) {}
  }

  /// Loads a specific session snapshot by ID.
  static Future<SessionSnapshot?> loadSnapshot(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString('$_prefPrefix$sessionId');
      if (content == null) return null;
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      return SessionSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Returns the most recently updated unclosed session snapshot, if one exists.
  static Future<SessionSnapshot?> getLatestActiveSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_prefIndexKey) ?? <String>[];

      SessionSnapshot? latest;
      for (final id in ids) {
        try {
          final content = prefs.getString('$_prefPrefix$id');
          if (content == null) continue;
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          final snapshot = SessionSnapshot.fromJson(decoded);

          final isEnded = snapshot.events.any((e) => e is SessionEnded);
          if (!isEnded) {
            if (latest == null || snapshot.updatedAt.isAfter(latest.updatedAt)) {
              latest = snapshot;
            }
          }
        } catch (_) {}
      }
      return latest;
    } catch (_) {
      return null;
    }
  }

  /// Deletes a session snapshot.
  static Future<void> deleteSnapshot(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefPrefix$sessionId');
      final ids = prefs.getStringList(_prefIndexKey) ?? <String>[];
      ids.remove(sessionId);
      await prefs.setStringList(_prefIndexKey, ids);
    } catch (_) {}
  }
}
