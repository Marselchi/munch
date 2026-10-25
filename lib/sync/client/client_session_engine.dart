import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';
import '../common/connection_status.dart';
import '../common/event_log.dart';
import '../protocol/envelope.dart';
import '../protocol/messages.dart';
import '../protocol/models.dart';
import 'heartbeat.dart';
import 'reconnect_policy.dart';
import 'ws_client.dart';

/// Client Session Engine managing replica state, event application,
/// and automated seamless reconnection.
/// Pure Dart (no Flutter imports).
class ClientSessionEngine {
  final String playerName;
  final List<String> hostIps;
  final int port;
  final String? initialToken;
  final String? initialPlayerId;

  final WebSocketClient _client = WebSocketClient();
  late final ReconnectPolicy _reconnectPolicy;
  late final ClientHeartbeat _heartbeat;
  final EventLog eventLog = EventLog();

  SyncConnectionStatus _status = SyncConnectionStatus.disconnected;
  SessionSnapshot? _snapshot;
  String? _playerId;
  String? _token;
  bool _isDisposed = false;
  Timer? _reconnectTimer;
  StreamSubscription? _streamSub;

  // Pending level requests tracked by client
  final Set<String> _pendingRequestIds = {};

  // Callbacks
  void Function(SyncConnectionStatus status)? onStatusChanged;
  void Function()? onStateUpdated;
  void Function(String code, String message)? onJoinRejected;
  void Function(String reason)? onSessionEnded;
  void Function(String reqId, String? message)? onLevelRequestDenied;
  void Function(String reqId)? onLevelRequestAcked;

  ClientSessionEngine({
    required this.playerName,
    required this.hostIps,
    this.port = AppConstants.defaultPort,
    this.initialToken,
    this.initialPlayerId,
  }) {
    _token = initialToken;
    _playerId = initialPlayerId;
    _reconnectPolicy = ReconnectPolicy(hostIps: hostIps, port: port);

    _heartbeat = ClientHeartbeat(
      sendPing: _sendPing,
      onWatchdogTimeout: () {
        _handleDisconnectAndReconnect();
      },
    );
  }

  SyncConnectionStatus get status => _status;
  SessionSnapshot? get snapshot => _snapshot;
  String? get playerId => _playerId;
  String? get token => _token;
  List<Player> get players => _snapshot?.players ?? const [];
  Player? get selfPlayer =>
      _playerId != null ? _snapshot?.players.firstWhere((p) => p.id == _playerId, orElse: () => Player(id: _playerId!, name: playerName)) : null;

  bool isRequestPending(String reqId) => _pendingRequestIds.contains(reqId);

  /// Initiates the connection flow.
  Future<void> start() async {
    _setStatus(SyncConnectionStatus.reconnecting);
    await _tryConnect();
  }

  Future<void> _tryConnect() async {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();

    try {
      final ip = _reconnectPolicy.nextIp();
      final channel = await _client.connectSingle(ip, port);

      _reconnectPolicy.reset();
      _heartbeat.start();
      _listenToChannel(channel);

      // Perform handshake: Join or Rejoin
      if (_playerId != null && _token != null) {
        _sendRejoin();
      } else {
        _sendJoin();
      }
    } catch (_) {
      // Failed attempt: schedule next with backoff
      if (!_isDisposed) {
        _setStatus(SyncConnectionStatus.reconnecting);
        final delay = _reconnectPolicy.nextDelay();
        _reconnectTimer = Timer(delay, () => _tryConnect());
      }
    }
  }

  void _listenToChannel(WebSocketChannel channel) {
    _streamSub?.cancel();
    _streamSub = channel.stream.listen(
      (message) {
        _heartbeat.recordTraffic();
        if (message is String) {
          _handleRawMessage(message);
        }
      },
      onDone: () => _handleDisconnectAndReconnect(),
      onError: (_) => _handleDisconnectAndReconnect(),
    );
  }

  void _handleRawMessage(String rawJson) {
    try {
      final envelope = Envelope.decode(rawJson);

      switch (envelope.type) {
        case MessageType.joinAccept:
          final accept = JoinAccept.fromJson(envelope.data);
          _playerId = accept.playerId;
          _token = accept.token;
          _snapshot = accept.snapshot;
          eventLog.clear();
          for (final ev in accept.snapshot.events) {
            eventLog.append(ev);
          }
          _setStatus(SyncConnectionStatus.connected);
          onStateUpdated?.call();
          break;

        case MessageType.joinReject:
          final reject = JoinReject.fromJson(envelope.data);
          _setStatus(SyncConnectionStatus.disconnected);
          onJoinRejected?.call(reject.code, reject.message);
          break;

        case MessageType.syncSnapshot:
          final snapMsg = SyncSnapshotMsg.fromJson(envelope.data);
          _snapshot = snapMsg.snapshot;
          eventLog.clear();
          for (final ev in snapMsg.snapshot.events) {
            eventLog.append(ev);
          }
          _setStatus(SyncConnectionStatus.connected);
          onStateUpdated?.call();
          break;

        case MessageType.syncDelta:
          final deltaMsg = SyncDeltaMsg.fromJson(envelope.data);
          for (final ev in deltaMsg.events) {
            _applySyncEvent(ev);
          }
          _setStatus(SyncConnectionStatus.connected);
          onStateUpdated?.call();
          break;

        case MessageType.levelApplied:
          final event = LevelApplied(
            seq: envelope.data['seq'] as int,
            eventId: envelope.data['eventId'] as String,
            ts: DateTime.fromMillisecondsSinceEpoch(envelope.data['ts'] as int),
            targetPlayerId: envelope.data['targetPlayerId'] as String,
            initiator: Initiator.fromJson(envelope.data['initiator'] as Map<String, dynamic>),
            delta: envelope.data['delta'] as int?,
            setValue: envelope.data['setValue'] as int?,
            prevLevel: envelope.data['prevLevel'] as int,
            newLevel: envelope.data['newLevel'] as int,
            reason: LevelReason.fromJson(envelope.data['reason'] as Map<String, dynamic>),
          );
          _applySyncEvent(event);
          onStateUpdated?.call();
          break;

        case MessageType.levelUndone:
          final event = LevelUndone(
            seq: envelope.data['seq'] as int,
            eventId: envelope.data['eventId'] as String,
            ts: DateTime.fromMillisecondsSinceEpoch(envelope.data['ts'] as int),
            targetChangeId: envelope.data['targetChangeId'] as String,
            restoredLevel: envelope.data['restoredLevel'] as int,
          );
          _applySyncEvent(event);
          onStateUpdated?.call();
          break;

        case MessageType.playerJoined:
          final event = PlayerJoined(
            seq: envelope.data['seq'] as int,
            eventId: envelope.data['eventId'] as String,
            ts: DateTime.fromMillisecondsSinceEpoch(envelope.data['ts'] as int),
            player: Player.fromJson(envelope.data['player'] as Map<String, dynamic>),
          );
          _applySyncEvent(event);
          onStateUpdated?.call();
          break;

        case MessageType.playerLeft:
          final event = PlayerLeft(
            seq: envelope.data['seq'] as int,
            eventId: envelope.data['eventId'] as String,
            ts: DateTime.fromMillisecondsSinceEpoch(envelope.data['ts'] as int),
            playerId: envelope.data['playerId'] as String,
            reason: envelope.data['reason'] as String? ?? 'left',
          );
          _applySyncEvent(event);
          onStateUpdated?.call();
          break;

        case MessageType.playerUpdated:
          final event = PlayerUpdated(
            seq: envelope.data['seq'] as int,
            eventId: envelope.data['eventId'] as String,
            ts: DateTime.fromMillisecondsSinceEpoch(envelope.data['ts'] as int),
            playerId: envelope.data['playerId'] as String,
            gearPower: envelope.data['gearPower'] as int?,
            traitIds: (envelope.data['traitIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList(),
            name: envelope.data['name'] as String?,
          );
          _applySyncEvent(event);
          onStateUpdated?.call();
          break;

        case MessageType.sessionUpdated:
          final event = SessionUpdated(
            seq: envelope.data['seq'] as int,
            eventId: envelope.data['eventId'] as String,
            ts: DateTime.fromMillisecondsSinceEpoch(envelope.data['ts'] as int),
            name: envelope.data['name'] as String?,
            settings: envelope.data['settings'] != null
                ? SessionSettings.fromJson(envelope.data['settings'] as Map<String, dynamic>)
                : null,
          );
          _applySyncEvent(event);
          onStateUpdated?.call();
          break;

        case MessageType.sessionEnded:
          final reason = envelope.data['reason'] as String? ?? 'Игра завершена.';
          _setStatus(SyncConnectionStatus.disconnected);
          onSessionEnded?.call(reason);
          break;

        case MessageType.levelRequestAck:
          final ack = LevelRequestAck.fromJson(envelope.data);
          _pendingRequestIds.add(ack.reqId);
          onLevelRequestAcked?.call(ack.reqId);
          onStateUpdated?.call();
          break;

        case MessageType.levelRequestDenied:
          final denied = LevelRequestDenied.fromJson(envelope.data);
          _pendingRequestIds.remove(denied.reqId);
          onLevelRequestDenied?.call(denied.reqId, denied.message);
          onStateUpdated?.call();
          break;

        case MessageType.heartbeatPong:
          // Pong received, activity recorded
          break;
      }
    } catch (_) {}
  }

  void _applySyncEvent(SyncEvent event) {
    eventLog.append(event);

    if (_snapshot == null) return;

    switch (event) {
      case LevelApplied(:final targetPlayerId, :final newLevel):
        final updatedPlayers = _snapshot!.players.map((p) {
          return p.id == targetPlayerId ? p.copyWith(level: newLevel) : p;
        }).toList();
        _snapshot = _snapshot!.copyWith(
          seq: event.seq,
          players: updatedPlayers,
        );
        // Clear pending request if it matches
        _pendingRequestIds.clear();
        break;

      case LevelUndone(:final targetChangeId, :final restoredLevel):
        final appliedList = eventLog.events
            .whereType<LevelApplied>()
            .where((e) => e.eventId == targetChangeId)
            .toList();
        if (appliedList.isNotEmpty) {
          final applied = appliedList.first;
          final updatedPlayers = _snapshot!.players.map((p) {
            return p.id == applied.targetPlayerId
                ? p.copyWith(level: restoredLevel)
                : p;
          }).toList();
          _snapshot = _snapshot!.copyWith(
            seq: event.seq,
            players: updatedPlayers,
          );
        }
        break;

      case PlayerJoined(:final player):
        if (!_snapshot!.players.any((p) => p.id == player.id)) {
          _snapshot = _snapshot!.copyWith(
            seq: event.seq,
            players: [..._snapshot!.players, player],
          );
        }
        break;

      case PlayerLeft(:final playerId):
        final remaining = _snapshot!.players.where((p) => p.id != playerId).toList();
        _snapshot = _snapshot!.copyWith(
          seq: event.seq,
          players: remaining,
        );
        break;

      case PlayerUpdated(:final playerId, :final gearPower, :final traitIds, :final name):
        final updated = _snapshot!.players.map((p) {
          if (p.id == playerId) {
            return p.copyWith(
              gearPower: gearPower ?? p.gearPower,
              traitIds: traitIds ?? p.traitIds,
              name: name ?? p.name,
            );
          }
          return p;
        }).toList();
        _snapshot = _snapshot!.copyWith(
          seq: event.seq,
          players: updated,
        );
        break;

      case SessionUpdated(:final name, :final settings):
        _snapshot = _snapshot!.copyWith(
          seq: event.seq,
          name: name ?? _snapshot!.name,
          settings: settings ?? _snapshot!.settings,
        );
        break;

      case SessionEnded():
        // Handled in message dispatcher
        break;
    }
  }

  // --- Outgoing Requests ---

  String requestLevelChange({
    int? delta,
    int? setValue,
    required LevelReason reason,
  }) {
    if (_status != SyncConnectionStatus.connected) {
      throw StateError('Нет подключения к столу.');
    }

    final reqId = const Uuid().v4();
    final req = LevelRequest(
      reqId: reqId,
      delta: delta,
      setValue: setValue,
      reason: reason,
    );

    _sendEnvelope(MessageType.levelRequest, req.toJson());
    _pendingRequestIds.add(reqId);
    onStateUpdated?.call();
    return reqId;
  }

  void updateGearPower(int newPower) {
    if (_status != SyncConnectionStatus.connected) return;

    final clamped = newPower.clamp(
      AppConstants.minGearPower,
      AppConstants.maxGearPower,
    );

    final update = GearUpdate(gearPower: clamped);
    _sendEnvelope(MessageType.gearUpdate, update.toJson());

    // Optimistically update local player gear
    if (_playerId != null && _snapshot != null) {
      final updated = _snapshot!.players.map((p) {
        return p.id == _playerId ? p.copyWith(gearPower: clamped) : p;
      }).toList();
      _snapshot = _snapshot!.copyWith(players: updated);
      onStateUpdated?.call();
    }
  }

  void updateTraits(List<String> traitIds) {
    if (_status != SyncConnectionStatus.connected) return;

    final update = TraitsUpdate(traitIds: traitIds);
    _sendEnvelope(MessageType.traitsUpdate, update.toJson());

    if (_playerId != null && _snapshot != null) {
      final updated = _snapshot!.players.map((p) {
        return p.id == _playerId ? p.copyWith(traitIds: traitIds) : p;
      }).toList();
      _snapshot = _snapshot!.copyWith(players: updated);
      onStateUpdated?.call();
    }
  }

  void leave() {
    if (_status == SyncConnectionStatus.connected) {
      _sendEnvelope(MessageType.leaveNotify, {});
    }
    dispose();
  }

  /// Triggered on app resume or manual retry.
  void triggerImmediateReconnect() {
    if (_status != SyncConnectionStatus.connected && !_isDisposed) {
      _reconnectPolicy.reset();
      _tryConnect();
    }
  }

  void _sendJoin() {
    final req = JoinRequest(
      name: playerName,
      appVersion: AppConstants.protocolVersion,
    );
    _sendEnvelope(MessageType.joinRequest, req.toJson());
  }

  void _sendRejoin() {
    final req = RejoinRequest(
      playerId: _playerId!,
      token: _token!,
      lastSeq: eventLog.lastSeq,
    );
    _sendEnvelope(MessageType.rejoinRequest, req.toJson());
  }

  void _sendPing() {
    if (_status == SyncConnectionStatus.connected) {
      _sendEnvelope(MessageType.heartbeatPing, {});
    }
  }

  void _sendEnvelope(String type, Map<String, dynamic> data) {
    final env = Envelope.create(
      type: type,
      sessionId: _snapshot?.sessionId ?? '',
      data: data,
    );
    _client.channel?.sink.add(env.encode());
  }

  void _handleDisconnectAndReconnect() {
    if (_isDisposed) return;
    _heartbeat.stop();
    _streamSub?.cancel();
    _client.disconnect();

    _setStatus(SyncConnectionStatus.reconnecting);

    // Schedule reconnect with backoff
    final delay = _reconnectPolicy.nextDelay();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () => _tryConnect());
  }

  void _setStatus(SyncConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      onStatusChanged?.call(_status);
      onStateUpdated?.call();
    }
  }

  void dispose() {
    _isDisposed = true;
    _heartbeat.stop();
    _reconnectTimer?.cancel();
    _streamSub?.cancel();
    _client.disconnect();
    _setStatus(SyncConnectionStatus.disconnected);
  }
}
