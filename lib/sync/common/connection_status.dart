/// Status of a device's sync connection.
/// Pure Dart (no Flutter imports).
enum SyncConnectionStatus {
  connected,
  reconnecting,
  disconnected;

  bool get isConnected => this == SyncConnectionStatus.connected;
  bool get isReconnecting => this == SyncConnectionStatus.reconnecting;
  bool get isDisconnected => this == SyncConnectionStatus.disconnected;
}
