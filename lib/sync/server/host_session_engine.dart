import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';
import '../common/event_log.dart';
import '../protocol/envelope.dart';
import '../protocol/messages.dart';
import '../protocol/models.dart';
import 'connection_registry.dart';

class PendingLevelRequest {
  final String reqId;
  final String playerId;
  final int? delta;
  final int? setValue;
  final LevelReason reason;
  final DateTime createdAt;
  final DateTime expiresAt;

  PendingLevelRequest({
    required this.reqId,
    required this.playerId,
    this.delta,
    this.setValue,
    required this.reason,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        expiresAt = (createdAt ?? DateTime.now()).add(AppConstants.requestExpiry);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  int get remainingSeconds =>
      expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 60);
}

class JoinApprovalRequest {
  final String reqId;
  final String name;
  final WebSocketChannel channel;
  final DateTime requestedAt;

  JoinApprovalRequest({
    required this.reqId,
    required this.name,
    required this.channel,
    DateTime? requestedAt,
  }) : requestedAt = requestedAt ?? DateTime.now();
}

/// Authoritative Host Game Session Engine.
/// Pure Dart (no Flutter imports).
class HostSessionEngine {
  final String hostPlayerName;
  final String sessionName;
  final ConnectionRegistry registry = ConnectionRegistry();
  late final EventLog eventLog;

  late String sessionId;
  late String hostPlayerId;
  int _seq = 0;
  SessionSettings settings;
  final Map<String, Player> _players = {};

  bool requireJoinApproval = false;
  final Map<String, PendingLevelRequest> _pendingRequests = {};
  final Map<String, JoinApprovalRequest> _joinApprovals = {};

  Timer? _requestExpirationTimer;
  Timer? _debounceSaveTimer;
  void Function(SessionSnapshot snapshot)? onSnapshotChanged;
  void Function()? onStateUpdated;

  HostSessionEngine({
    required this.hostPlayerName,
    this.sessionName = 'Манчкин За Столом',
    this.settings = const SessionSettings(),
    SessionSnapshot? resumeFromSnapshot,
  }) {
    if (resumeFromSnapshot != null) {
      _resumeFrom(resumeFromSnapshot);
    } else {
      _createNew();
    }

    _startTimers();
  }

  void _createNew() {
    final uuid = const Uuid();
    sessionId = uuid.v4();
    hostPlayerId = uuid.v4();
    _seq = 0;
    eventLog = EventLog();

    final hostPlayer = Player(
      id: hostPlayerId,
      name: hostPlayerName.trim().isEmpty ? 'Ведущий' : hostPlayerName.trim(),
      level: 1,
      gearPower: 0,
    );

    _players[hostPlayerId] = hostPlayer;

    // Append initial host joined event
    _seq++;
    final joinEvent = PlayerJoined(
      seq: _seq,
      eventId: uuid.v4(),
      ts: DateTime.now(),
      player: hostPlayer,
    );
    eventLog.append(joinEvent);
  }

  void _resumeFrom(SessionSnapshot snapshot) {
    sessionId = snapshot.sessionId;
    hostPlayerId = snapshot.hostPlayerId;
    _seq = snapshot.seq;
    settings = snapshot.settings;
    eventLog = EventLog(snapshot.events);

    _players.clear();
    for (final player in snapshot.players) {
      _players[player.id] = player;
    }
  }

  void _startTimers() {
    registry.startWatchdog();
    registry.onPlayerTimedOut = (playerId) {
      removePlayer(playerId, reason: 'timedOut');
    };
    registry.onPlayerWatchdogDisconnected = (playerId) {
      onStateUpdated?.call();
    };

    _requestExpirationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkExpiredRequests();
    });
  }

  int get currentSeq => _seq;
  List<Player> get players => _players.values.toList();
  Player? getPlayer(String id) => _players[id];
  List<PendingLevelRequest> get pendingRequests =>
      _pendingRequests.values.toList();
  List<JoinApprovalRequest> get pendingJoinApprovals =>
      _joinApprovals.values.toList();

  SessionSnapshot get snapshot => SessionSnapshot(
        sessionId: sessionId,
        name: sessionName,
        protocolVersion: AppConstants.protocolVersion,
        hostPlayerId: hostPlayerId,
        settings: settings,
        seq: _seq,
        players: players,
        events: eventLog.events,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  // --- Level Operations ---

  /// Applies a level change (host-initiated or approved request).
  /// Returns true if applied, or false if rejected as a no-op (e.g. at limits).
  bool applyLevelChange({
    required String targetPlayerId,
    required Initiator initiator,
    int? delta,
    int? setValue,
    required LevelReason reason,
  }) {
    final player = _players[targetPlayerId];
    if (player == null) return false;

    int newLevel = player.level;
    if (setValue != null) {
      newLevel = setValue;
    } else if (delta != null) {
      newLevel += delta;
    }

    // Bounds clamp
    final clamped = newLevel.clamp(AppConstants.minLevel, settings.maxLevel);
    if (clamped == player.level) {
      // No-op rejected
      return false;
    }

    final prevLevel = player.level;
    _players[targetPlayerId] = player.copyWith(level: clamped);

    _seq++;
    final event = LevelApplied(
      seq: _seq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      targetPlayerId: targetPlayerId,
      initiator: initiator,
      delta: delta,
      setValue: setValue,
      prevLevel: prevLevel,
      newLevel: clamped,
      reason: reason,
    );

    eventLog.append(event);
    _broadcastEnvelope(MessageType.levelApplied, event.toJson());
    _scheduleSnapshotSave();
    onStateUpdated?.call();
    return true;
  }

  /// Undoes the single most recent active (not-yet-undone) level change.
  /// Returns true if an undo was performed, false if the undo stack is empty.
  bool undoLastLevelChange() {
    final candidate = eventLog.undoCandidate;
    if (candidate == null) return false;

    final targetPlayer = _players[candidate.targetPlayerId];
    if (targetPlayer == null) return false;

    // Restore level to candidate.prevLevel
    final restoredLevel = candidate.prevLevel;
    _players[candidate.targetPlayerId] =
        targetPlayer.copyWith(level: restoredLevel);

    _seq++;
    final undoEvent = LevelUndone(
      seq: _seq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      targetChangeId: candidate.eventId,
      restoredLevel: restoredLevel,
    );

    eventLog.append(undoEvent);
    _broadcastEnvelope(MessageType.levelUndone, undoEvent.toJson());
    _scheduleSnapshotSave();
    onStateUpdated?.call();
    return true;
  }

  /// Updates gear power for a player (host or player owned).
  void updateGearPower(String playerId, int newGearPower) {
    final player = _players[playerId];
    if (player == null) return;

    final clamped = newGearPower.clamp(
      AppConstants.minGearPower,
      AppConstants.maxGearPower,
    );
    if (clamped == player.gearPower) return;

    _players[playerId] = player.copyWith(gearPower: clamped);

    _seq++;
    final event = PlayerUpdated(
      seq: _seq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      playerId: playerId,
      gearPower: clamped,
    );

    eventLog.append(event);
    _broadcastEnvelope(MessageType.playerUpdated, event.toJson());
    _scheduleSnapshotSave();
    onStateUpdated?.call();
  }

  /// Updates player traits (classes/races picked from rules).
  void updateTraits(String playerId, List<String> traitIds) {
    final player = _players[playerId];
    if (player == null) return;

    _players[playerId] = player.copyWith(traitIds: traitIds);

    _seq++;
    final event = PlayerUpdated(
      seq: _seq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      playerId: playerId,
      traitIds: traitIds,
    );

    eventLog.append(event);
    _broadcastEnvelope(MessageType.playerUpdated, event.toJson());
    _scheduleSnapshotSave();
    onStateUpdated?.call();
  }

  /// Changes the session max level (e.g. from 20 up to 22).
  void updateMaxLevel(int newMaxLevel) {
    final clamped = newMaxLevel.clamp(
      AppConstants.defaultMaxLevel,
      AppConstants.absoluteMaxLevel,
    );
    if (clamped == settings.maxLevel) return;

    settings = settings.copyWith(maxLevel: clamped);

    _seq++;
    final event = SessionUpdated(
      seq: _seq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      settings: settings,
    );

    eventLog.append(event);
    _broadcastEnvelope(MessageType.sessionUpdated, event.toJson());
    _scheduleSnapshotSave();
    onStateUpdated?.call();
  }

  // --- Level Request Queue ---

  void handleLevelRequest(String playerId, LevelRequest request) {
    final pending = PendingLevelRequest(
      reqId: request.reqId,
      playerId: playerId,
      delta: request.delta,
      setValue: request.setValue,
      reason: request.reason,
    );

    _pendingRequests[request.reqId] = pending;

    // Send immediate ack to requester
    final ack = LevelRequestAck(reqId: request.reqId);
    _sendToPlayer(playerId, MessageType.levelRequestAck, ack.toJson());

    onStateUpdated?.call();
  }

  void approveRequest(String reqId) {
    final req = _pendingRequests.remove(reqId);
    if (req == null) return;

    applyLevelChange(
      targetPlayerId: req.playerId,
      initiator: PlayerRequested(req.playerId),
      delta: req.delta,
      setValue: req.setValue,
      reason: req.reason,
    );
  }

  void denyRequest(String reqId, [String? message]) {
    final req = _pendingRequests.remove(reqId);
    if (req == null) return;

    final denied = LevelRequestDenied(reqId: reqId, message: message);
    _sendToPlayer(req.playerId, MessageType.levelRequestDenied, denied.toJson());

    onStateUpdated?.call();
  }

  void _checkExpiredRequests() {
    final expired = <String>[];
    for (final req in _pendingRequests.values) {
      if (req.isExpired) {
        expired.add(req.reqId);
      }
    }

    for (final id in expired) {
      denyRequest(id, 'Время ожидания решения ведущего истекло.');
    }
  }

  // --- Client Connection & Message Dispatcher ---

  void handleIncomingConnection(WebSocketChannel channel) {
    channel.stream.listen(
      (message) {
        if (message is String) {
          _handleClientRawMessage(channel, message);
        }
      },
      onDone: () {
        _handleChannelClosed(channel);
      },
      onError: (_) {
        _handleChannelClosed(channel);
      },
    );
  }

  void _handleChannelClosed(WebSocketChannel channel) {
    for (final c in registry.allConnections) {
      if (c.channel == channel) {
        c.markDisconnected();
        onStateUpdated?.call();
        break;
      }
    }
  }

  void _handleClientRawMessage(WebSocketChannel channel, String rawJson) {
    try {
      final envelope = Envelope.decode(rawJson);

      // Check protocol version
      if (envelope.v != AppConstants.protocolVersion) {
        _sendReject(
          channel,
          RejectCode.protocolMismatch,
          'Несовместимая версия протокола.',
        );
        return;
      }

      switch (envelope.type) {
        case MessageType.joinRequest:
          _handleJoinRequest(channel, JoinRequest.fromJson(envelope.data));
          break;
        case MessageType.rejoinRequest:
          _handleRejoinRequest(channel, RejoinRequest.fromJson(envelope.data));
          break;
        case MessageType.heartbeatPing:
          _handlePing(channel);
          break;
        case MessageType.levelRequest:
          final sender = _findSender(channel);
          if (sender != null) {
            handleLevelRequest(sender.playerId, LevelRequest.fromJson(envelope.data));
          }
          break;
        case MessageType.gearUpdate:
          final sender = _findSender(channel);
          if (sender != null) {
            final update = GearUpdate.fromJson(envelope.data);
            updateGearPower(sender.playerId, update.gearPower);
          }
          break;
        case MessageType.traitsUpdate:
          final sender = _findSender(channel);
          if (sender != null) {
            final update = TraitsUpdate.fromJson(envelope.data);
            updateTraits(sender.playerId, update.traitIds);
          }
          break;
        case MessageType.leaveNotify:
          final sender = _findSender(channel);
          if (sender != null) {
            removePlayer(sender.playerId, reason: 'left');
          }
          break;
      }
    } catch (_) {}
  }

  ClientConnection? _findSender(WebSocketChannel channel) {
    for (final c in registry.allConnections) {
      if (c.channel == channel && c.isConnected) {
        c.recordActivity();
        return c;
      }
    }
    return null;
  }

  void _handlePing(WebSocketChannel channel) {
    final sender = _findSender(channel);
    sender?.recordActivity();
    _sendDirect(channel, MessageType.heartbeatPong, {});
  }

  void _handleJoinRequest(WebSocketChannel channel, JoinRequest req) {
    if (requireJoinApproval) {
      final approvalId = const Uuid().v4();
      _joinApprovals[approvalId] = JoinApprovalRequest(
        reqId: approvalId,
        name: req.name,
        channel: channel,
      );
      _sendReject(
        channel,
        RejectCode.approvalRequired,
        'Ожидание подтверждения ведущего стола.',
      );
      onStateUpdated?.call();
      return;
    }

    _completeJoin(channel, req.name);
  }

  void approveJoinRequest(String reqId) {
    final approval = _joinApprovals.remove(reqId);
    if (approval == null) return;
    _completeJoin(approval.channel, approval.name);
  }

  void denyJoinRequest(String reqId) {
    final approval = _joinApprovals.remove(reqId);
    if (approval == null) return;
    _sendReject(
      approval.channel,
      RejectCode.sessionEnded,
      'Ведущий отклонил заявку на вход.',
    );
    onStateUpdated?.call();
  }

  void _completeJoin(WebSocketChannel channel, String rawName) {
    final uniqueName = _resolveUniqueName(rawName);
    final playerId = const Uuid().v4();
    final token = const Uuid().v4().replaceAll('-', '');

    final newPlayer = Player(
      id: playerId,
      name: uniqueName,
      level: 1,
      gearPower: 0,
    );

    _players[playerId] = newPlayer;
    registry.register(playerId: playerId, token: token, channel: channel);

    _seq++;
    final joinEvent = PlayerJoined(
      seq: _seq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      player: newPlayer,
    );
    eventLog.append(joinEvent);

    // Send JoinAccept with full snapshot
    final accept = JoinAccept(
      playerId: playerId,
      token: token,
      snapshot: snapshot,
    );

    _sendDirect(channel, MessageType.joinAccept, accept.toJson());

    // Broadcast player.joined to everyone else
    _broadcastEnvelope(MessageType.playerJoined, joinEvent.toJson(),
        excludePlayerId: playerId);

    _scheduleSnapshotSave();
    onStateUpdated?.call();
  }

  /// Adds a local player directly from the host interface without requiring a network client.
  Player addLocalPlayer(String rawName) {
    final uniqueName = _resolveUniqueName(
      rawName.trim().isEmpty ? 'Игрок ${_players.length + 1}' : rawName.trim(),
    );
    final playerId = const Uuid().v4();

    final newPlayer = Player(
      id: playerId,
      name: uniqueName,
      level: 1,
      gearPower: 0,
    );

    _players[playerId] = newPlayer;

    _seq++;
    final joinEvent = PlayerJoined(
      seq: _seq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      player: newPlayer,
    );
    eventLog.append(joinEvent);

    _broadcastEnvelope(MessageType.playerJoined, joinEvent.toJson());

    _scheduleSnapshotSave();
    onStateUpdated?.call();
    return newPlayer;
  }

  void _handleRejoinRequest(WebSocketChannel channel, RejoinRequest req) {
    final existing = registry.findByToken(req.token);
    if (existing == null || existing.playerId != req.playerId) {
      _sendReject(
        channel,
        RejectCode.invalidToken,
        'Токен недействителен или место освобождено.',
      );
      return;
    }

    // Restore connection
    registry.register(
      playerId: req.playerId,
      token: req.token,
      channel: channel,
    );

    // Delta or snapshot resync
    if (req.lastSeq >= 0 && req.lastSeq <= _seq) {
      final missedEvents = eventLog.eventsAfter(req.lastSeq);
      final deltaMsg = SyncDeltaMsg(events: missedEvents);
      _sendDirect(channel, MessageType.syncDelta, deltaMsg.toJson());
    } else {
      final snapMsg = SyncSnapshotMsg(snapshot: snapshot);
      _sendDirect(channel, MessageType.syncSnapshot, snapMsg.toJson());
    }

    onStateUpdated?.call();
  }

  void removePlayer(String playerId, {String reason = 'removed'}) {
    final player = _players.remove(playerId);
    if (player == null) return;

    registry.remove(playerId);

    _seq++;
    final leftEvent = PlayerLeft(
      seq: _seq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      playerId: playerId,
      reason: reason,
    );
    eventLog.append(leftEvent);

    _broadcastEnvelope(MessageType.playerLeft, leftEvent.toJson());
    _scheduleSnapshotSave();
    onStateUpdated?.call();
  }

  void endSession({String reason = 'Ведущий завершил игру.'}) {
    _seq++;
    final endEvent = SessionEnded(
      seq: _seq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      reason: reason,
    );
    eventLog.append(endEvent);

    _broadcastEnvelope(MessageType.sessionEnded, endEvent.toJson());
    _scheduleSnapshotSave();
    dispose();
  }

  String _resolveUniqueName(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) trimmed = 'Манчкин';
    if (trimmed.length > AppConstants.maxNameLength) {
      trimmed = trimmed.substring(0, AppConstants.maxNameLength);
    }

    final existingNames = _players.values.map((p) => p.name).toSet();
    if (!existingNames.contains(trimmed)) return trimmed;

    var counter = 2;
    while (existingNames.contains('$trimmed ($counter)')) {
      counter++;
    }
    return '$trimmed ($counter)';
  }

  void _sendToPlayer(String playerId, String type, Map<String, dynamic> data) {
    final env = Envelope.create(
      type: type,
      sessionId: sessionId,
      data: data,
    );
    registry.sendTo(playerId, env.encode());
  }

  void _broadcastEnvelope(
    String type,
    Map<String, dynamic> data, {
    String? excludePlayerId,
  }) {
    final env = Envelope.create(
      type: type,
      sessionId: sessionId,
      data: data,
    );
    final encoded = env.encode();

    for (final client in registry.connectedClients) {
      if (excludePlayerId != null && client.playerId == excludePlayerId) {
        continue;
      }
      try {
        client.channel?.sink.add(encoded);
        client.recordActivity();
      } catch (_) {
        client.markDisconnected();
      }
    }
  }

  void _sendDirect(
    WebSocketChannel channel,
    String type,
    Map<String, dynamic> data,
  ) {
    final env = Envelope.create(
      type: type,
      sessionId: sessionId,
      data: data,
    );
    try {
      channel.sink.add(env.encode());
    } catch (_) {}
  }

  void _sendReject(WebSocketChannel channel, String code, String message) {
    final reject = JoinReject(code: code, message: message);
    _sendDirect(channel, MessageType.joinReject, reject.toJson());
  }

  void _scheduleSnapshotSave() {
    _debounceSaveTimer?.cancel();
    _debounceSaveTimer = Timer(AppConstants.snapshotDebounce, () {
      onSnapshotChanged?.call(snapshot);
    });
  }

  void dispose() {
    _requestExpirationTimer?.cancel();
    _debounceSaveTimer?.cancel();
    registry.dispose();
  }
}
