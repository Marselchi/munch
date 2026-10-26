import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';
import '../protocol/envelope.dart';
import '../protocol/messages.dart';
import '../protocol/models.dart';
import '../server/connection_registry.dart';
import 'session_node.dart';

class PendingLevelRequest {
  final String reqId;
  final String playerId;
  final int? delta;
  final int? setValue;
  final LevelReason reason;
  final DateTime createdAt;

  PendingLevelRequest({
    required this.reqId,
    required this.playerId,
    this.delta,
    this.setValue,
    required this.reason,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpired => false;
  int get remainingSeconds => 0;
}

class JoinApprovalRequest {
  final String reqId;
  final String name;
  final WebSocketChannel channel;
  final List<String> listenIps;
  final int? listenPort;
  final DateTime requestedAt;

  JoinApprovalRequest({
    required this.reqId,
    required this.name,
    required this.channel,
    this.listenIps = const [],
    this.listenPort,
    DateTime? requestedAt,
  }) : requestedAt = requestedAt ?? DateTime.now();
}

/// Host role attached to a SessionNode when the current device acts as authoritative host.
/// Pure Dart (no Flutter imports).
class HostRole {
  SessionNode? _node;
  final ConnectionRegistry registry = ConnectionRegistry();

  bool requireJoinApproval = false;
  final Map<String, PendingLevelRequest> _pendingRequests = {};
  final Map<String, JoinApprovalRequest> _joinApprovals = {};

  void Function(HostChanged event)? onHostDemoted;

  Timer? _debounceSaveTimer;

  List<PendingLevelRequest> get pendingRequests =>
      _pendingRequests.values.toList();
  List<JoinApprovalRequest> get pendingJoinApprovals =>
      _joinApprovals.values.toList();

  SessionNode get node {
    final n = _node;
    if (n == null) throw StateError('HostRole is not attached to a SessionNode');
    return n;
  }

  void attach(SessionNode node) {
    _node = node;
    _restoreSeatsFromSnapshot();
    _reassignLocalPlayers();
    _ensureHostInRoster();
    _startTimers();
  }

  void detach() {
    _stopTimers();
    registry.stopWatchdog();
    _node = null;
  }

  void _reassignLocalPlayers() {
    if (_node == null) return;
    final remapped = _node!.players.map((p) {
      if (p.ownerId != null && p.ownerId != _node!.hostPlayerId && p.id != _node!.hostPlayerId) {
        return p.copyWith(ownerId: _node!.hostPlayerId);
      }
      return p;
    }).toList();
    _node!.resetSnapshot(_node!.snapshot.copyWith(players: remapped));
  }

  void _ensureHostInRoster() {
    if (_node == null) return;
    if (!_node!.roster.any((r) => r.playerId == _node!.hostPlayerId)) {
      _node!.updateRoster([
        RosterEntry(
          playerId: _node!.hostPlayerId,
          ips: const [],
          port: AppConstants.defaultPort,
          rank: 0,
        ),
        ..._node!.roster,
      ]);
    }
  }

  void _restoreSeatsFromSnapshot() {
    if (_node == null) return;
    for (final seat in _node!.seats) {
      registry.restoreSeat(playerId: seat.playerId, token: seat.token);
    }
  }

  void _startTimers() {
    registry.startWatchdog();
    registry.onPlayerTimedOut = (playerId) {
      // In Phase 1/2: players are marked claimable rather than automatically deleted
      _node?.onStateUpdated?.call();
    };
    registry.onPlayerWatchdogDisconnected = (playerId) {
      _node?.onStateUpdated?.call();
    };

  }

  void _stopTimers() {
    _debounceSaveTimer?.cancel();
    _debounceSaveTimer = null;
  }

  // --- Authoritative Operations ---

  bool applyLevelChange({
    required String targetPlayerId,
    required Initiator initiator,
    int? delta,
    int? setValue,
    required LevelReason reason,
  }) {
    final player = node.getPlayer(targetPlayerId);
    if (player == null) return false;

    int newLevel = player.level;
    if (setValue != null) {
      newLevel = setValue;
    } else if (delta != null) {
      newLevel += delta;
    }

    final clamped = newLevel.clamp(AppConstants.minLevel, node.settings.maxLevel);
    if (clamped == player.level) {
      return false; // No-op boundary
    }

    final prevLevel = player.level;
    final nextSeq = node.currentSeq + 1;
    final event = LevelApplied(
      seq: nextSeq,
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

    node.apply(event);
    _broadcastEnvelope(MessageType.levelApplied, event.toJson());
    _scheduleSnapshotSave();
    return true;
  }

  bool undoLastLevelChange() {
    final candidate = node.eventLog.undoCandidate;
    if (candidate == null) return false;

    final targetPlayer = node.getPlayer(candidate.targetPlayerId);
    if (targetPlayer == null) return false;

    final restoredLevel = candidate.prevLevel;
    final nextSeq = node.currentSeq + 1;
    final undoEvent = LevelUndone(
      seq: nextSeq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      targetChangeId: candidate.eventId,
      restoredLevel: restoredLevel,
    );

    node.apply(undoEvent);
    _broadcastEnvelope(MessageType.levelUndone, undoEvent.toJson());
    _scheduleSnapshotSave();
    return true;
  }

  void updateGearPower(String playerId, int newGearPower) {
    final player = node.getPlayer(playerId);
    if (player == null) return;

    final clamped = newGearPower.clamp(
      AppConstants.minGearPower,
      AppConstants.maxGearPower,
    );
    if (clamped == player.gearPower) return;

    final nextSeq = node.currentSeq + 1;
    final event = PlayerUpdated(
      seq: nextSeq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      playerId: playerId,
      gearPower: clamped,
    );

    node.apply(event);
    _broadcastEnvelope(MessageType.playerUpdated, event.toJson());
    _scheduleSnapshotSave();
  }

  void updateTraits(String playerId, List<String> traitIds) {
    final player = node.getPlayer(playerId);
    if (player == null) return;

    final nextSeq = node.currentSeq + 1;
    final event = PlayerUpdated(
      seq: nextSeq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      playerId: playerId,
      traitIds: traitIds,
    );

    node.apply(event);
    _broadcastEnvelope(MessageType.playerUpdated, event.toJson());
    _scheduleSnapshotSave();
  }

  void updateMaxLevel(int newMaxLevel) {
    final clamped = newMaxLevel.clamp(
      AppConstants.defaultMaxLevel,
      AppConstants.absoluteMaxLevel,
    );
    if (clamped == node.settings.maxLevel) return;

    final newSettings = node.settings.copyWith(maxLevel: clamped);
    final nextSeq = node.currentSeq + 1;
    final event = SessionUpdated(
      seq: nextSeq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      settings: newSettings,
    );

    node.apply(event);
    _broadcastEnvelope(MessageType.sessionUpdated, event.toJson());
    _scheduleSnapshotSave();
  }

  Player addLocalPlayer(String rawName) {
    final uniqueName = _resolveUniqueName(
      rawName.trim().isEmpty ? 'Игрок ${node.players.length + 1}' : rawName.trim(),
    );
    final playerId = const Uuid().v4();

    final newPlayer = Player(
      id: playerId,
      name: uniqueName,
      level: 1,
      gearPower: 0,
      ownerId: node.hostPlayerId,
    );

    final nextSeq = node.currentSeq + 1;
    final joinEvent = PlayerJoined(
      seq: nextSeq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      player: newPlayer,
    );

    node.apply(joinEvent);
    _broadcastEnvelope(MessageType.playerJoined, joinEvent.toJson());
    _scheduleSnapshotSave();
    return newPlayer;
  }

  void removePlayer(String playerId, {String reason = 'removed'}) {
    final player = node.getPlayer(playerId);
    if (player == null) return;

    registry.remove(playerId);
    final updatedSeats = node.seats.where((s) => s.playerId != playerId).toList();
    node.updateSeats(updatedSeats);

    final remainingRoster = node.roster.where((r) => r.playerId != playerId).toList();
    node.updateRoster(remainingRoster);
    _broadcastEnvelope(
      MessageType.rosterUpdate,
      RosterUpdateMsg(roster: node.roster).toJson(),
    );

    final nextSeq = node.currentSeq + 1;
    final leftEvent = PlayerLeft(
      seq: nextSeq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      playerId: playerId,
      reason: reason,
    );

    node.apply(leftEvent);
    _broadcastEnvelope(MessageType.playerLeft, leftEvent.toJson());
    _scheduleSnapshotSave();
  }

  /// Updates host's IP and port in the roster and broadcasts roster update.
  void updateHostNetworkInfo(List<String> ips, int port) {
    if (_node == null) return;
    final other = node.roster.where((r) => r.playerId != node.hostPlayerId).toList();
    final hostEntry = RosterEntry(
      playerId: node.hostPlayerId,
      ips: ips,
      port: port,
      rank: 0,
    );
    node.updateRoster([hostEntry, ...other]);
    _broadcastEnvelope(
      MessageType.rosterUpdate,
      RosterUpdateMsg(roster: node.roster).toJson(),
    );
  }

  /// Nominates a connected player as deputy (rank 1 in failover roster).
  void nominateDeputy(String playerId) {
    if (_node == null) return;
    final target = node.getPlayer(playerId);
    if (target == null || playerId == node.hostPlayerId) return;

    final updated = node.roster.map<RosterEntry>((r) {
      if (r.playerId == playerId) {
        return r.copyWith(rank: 1);
      } else if (r.rank >= 1 && r.playerId != node.hostPlayerId) {
        return r.copyWith(rank: r.rank + 1);
      }
      return r;
    }).toList();

    node.updateRoster(updated);
    _broadcastEnvelope(
      MessageType.rosterUpdate,
      RosterUpdateMsg(roster: node.roster).toJson(),
    );
  }

  /// Initiates a planned handoff to a connected client.
  void transferHost(String targetPlayerId) {
    if (_node == null) return;
    final target = node.getPlayer(targetPlayerId);
    if (target == null || targetPlayerId == node.hostPlayerId) return;

    final nextEpoch = node.epoch + 1;
    final transferMsg = HostTransferMsg(
      nextEpoch: nextEpoch,
      targetPlayerId: targetPlayerId,
      seats: node.seats,
    );
    _sendToPlayer(targetPlayerId, MessageType.hostTransfer, transferMsg.toJson());
  }

  /// Broadcasts HostChanged to all connected clients and applies it locally.
  void broadcastHostChanged(HostChanged event) {
    node.apply(event);
    _broadcastEnvelope(MessageType.hostChanged, event.toJson());
    _scheduleSnapshotSave();
  }

  void endSession({String reason = 'Ведущий завершил игру.'}) {
    final nextSeq = node.currentSeq + 1;
    final endEvent = SessionEnded(
      seq: nextSeq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      reason: reason,
    );

    node.apply(endEvent);
    _broadcastEnvelope(MessageType.sessionEnded, endEvent.toJson());
    _scheduleSnapshotSave();
    dispose();
  }

  // --- Requests Queue ---

  void handleLevelRequest(String playerId, LevelRequest request) {
    final pending = PendingLevelRequest(
      reqId: request.reqId,
      playerId: playerId,
      delta: request.delta,
      setValue: request.setValue,
      reason: request.reason,
    );

    _pendingRequests[request.reqId] = pending;

    final ack = LevelRequestAck(reqId: request.reqId);
    _sendToPlayer(playerId, MessageType.levelRequestAck, ack.toJson());
    node.onStateUpdated?.call();
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
    node.onStateUpdated?.call();
  }

  void _checkExpiredRequests() {
    // Requests do not expire automatically; host explicitly approves or denies them.
  }

  // --- Incoming Connections & Messaging ---

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
        node.onStateUpdated?.call();
        break;
      }
    }
  }

  List<ClaimableSeat> getClaimableSeats() {
    final result = <ClaimableSeat>[];
    for (final player in node.players) {
      if (player.id == node.hostPlayerId) continue;

      final isLocal = player.ownerId != null;
      final conn = registry.get(player.id);
      final isDisconnected = conn == null || !conn.isConnected;

      if (isLocal || isDisconnected) {
        result.add(ClaimableSeat(
          playerId: player.id,
          name: player.name,
          level: player.level,
          gearPower: player.gearPower,
          isLocal: isLocal,
        ));
      }
    }
    return result;
  }

  void _handleClientRawMessage(WebSocketChannel channel, String rawJson) {
    try {
      final envelope = Envelope.decode(rawJson);

      if (envelope.v != AppConstants.protocolVersion) {
        _sendReject(
          channel,
          RejectCode.protocolMismatch,
          'Несовместимая версия протокола.',
        );
        return;
      }

      // Epoch fencing: if a message from another host with higher epoch is received, demote
      if (_node != null && envelope.epoch > node.epoch) {
        onHostDemoted?.call(HostChanged(
          seq: node.currentSeq,
          eventId: envelope.id,
          ts: DateTime.fromMillisecondsSinceEpoch(envelope.ts),
          epoch: envelope.epoch,
          newHostPlayerId: envelope.data['newHostPlayerId'] as String? ?? '',
          ips: (envelope.data['ips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
          port: envelope.data['port'] as int? ?? AppConstants.defaultPort,
        ));
        return;
      }

      switch (envelope.type) {
        case MessageType.joinRequest:
          _handleJoinRequest(channel, JoinRequest.fromJson(envelope.data));
          break;
        case MessageType.rejoinRequest:
          _handleRejoinRequest(
            channel,
            envelope.sid,
            RejoinRequest.fromJson(envelope.data),
          );
          break;
        case MessageType.seatsListRequest:
          _sendDirect(
            channel,
            MessageType.seatsListResponse,
            SeatsListResponse(seats: getClaimableSeats()).toJson(),
          );
          break;
        case MessageType.seatClaimRequest:
          _handleSeatClaim(
            channel,
            SeatClaimRequest.fromJson(envelope.data),
          );
          break;
        case MessageType.syncPush:
          _handleSyncPush(channel, SyncPushMsg.fromJson(envelope.data));
          break;
        case MessageType.hostChanged:
          final newEpoch = envelope.data['epoch'] as int? ?? 0;
          if (_node != null && newEpoch > node.epoch) {
            onHostDemoted?.call(HostChanged(
              seq: envelope.data['seq'] as int? ?? node.currentSeq,
              eventId: envelope.data['eventId'] as String? ?? envelope.id,
              ts: DateTime.fromMillisecondsSinceEpoch(envelope.data['ts'] as int? ?? envelope.ts),
              epoch: newEpoch,
              newHostPlayerId: envelope.data['newHostPlayerId'] as String? ?? '',
              ips: (envelope.data['ips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
              port: envelope.data['port'] as int? ?? AppConstants.defaultPort,
            ));
          }
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

  void _handleSyncPush(WebSocketChannel channel, SyncPushMsg push) {
    if (_node == null) return;
    for (final ev in push.events) {
      if (ev.seq > node.currentSeq) {
        node.apply(ev);
        String broadcastType = MessageType.levelApplied;
        if (ev is LevelApplied) {
          broadcastType = MessageType.levelApplied;
        } else if (ev is LevelUndone) {
          broadcastType = MessageType.levelUndone;
        } else if (ev is PlayerUpdated) {
          broadcastType = MessageType.playerUpdated;
        } else if (ev is PlayerJoined) {
          broadcastType = MessageType.playerJoined;
        } else if (ev is PlayerLeft) {
          broadcastType = MessageType.playerLeft;
        } else if (ev is SessionUpdated) {
          broadcastType = MessageType.sessionUpdated;
        }

        _broadcastEnvelope(broadcastType, ev.toJson());
      }
    }
    _scheduleSnapshotSave();
    final snapMsg = SyncSnapshotMsg(snapshot: node.snapshot);
    _sendDirect(channel, MessageType.syncSnapshot, snapMsg.toJson());
    node.onStateUpdated?.call();
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
        listenIps: req.listenIps,
        listenPort: req.listenPort,
      );
      _sendReject(
        channel,
        RejectCode.approvalRequired,
        'Ожидание подтверждения ведущего стола.',
      );
      node.onStateUpdated?.call();
      return;
    }

    _completeJoin(channel, req.name, req.listenIps, req.listenPort);
  }

  void approveJoinRequest(String reqId) {
    final approval = _joinApprovals.remove(reqId);
    if (approval == null) return;
    _completeJoin(
      approval.channel,
      approval.name,
      approval.listenIps,
      approval.listenPort,
    );
  }

  void denyJoinRequest(String reqId) {
    final approval = _joinApprovals.remove(reqId);
    if (approval == null) return;
    _sendReject(
      approval.channel,
      RejectCode.sessionEnded,
      'Ведущий отклонил заявку на вход.',
    );
    node.onStateUpdated?.call();
  }

  void _completeJoin(
    WebSocketChannel channel,
    String rawName, [
    List<String> listenIps = const [],
    int? listenPort,
  ]) {
    final uniqueName = _resolveUniqueName(rawName);
    final playerId = const Uuid().v4();
    final token = const Uuid().v4().replaceAll('-', '');

    final newPlayer = Player(
      id: playerId,
      name: uniqueName,
      level: 1,
      gearPower: 0,
    );

    // Register seat in registry and persist into session snapshot
    registry.register(playerId: playerId, token: token, channel: channel);
    final newSeat = Seat(playerId: playerId, token: token);
    node.updateSeats([...node.seats, newSeat]);

    // Update roster: assign rank
    final existingRanks = node.roster.map((r) => r.rank).toSet();
    var nextRank = 1;
    while (existingRanks.contains(nextRank)) {
      nextRank++;
    }
    final newEntry = RosterEntry(
      playerId: playerId,
      ips: listenIps,
      port: listenPort ?? AppConstants.defaultPort,
      rank: nextRank,
    );
    node.updateRoster([...node.roster, newEntry]);

    final nextSeq = node.currentSeq + 1;
    final joinEvent = PlayerJoined(
      seq: nextSeq,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      player: newPlayer,
    );

    node.apply(joinEvent);

    final accept = JoinAccept(
      playerId: playerId,
      token: token,
      snapshot: node.snapshot,
    );

    _sendDirect(channel, MessageType.joinAccept, accept.toJson());
    _broadcastEnvelope(
      MessageType.playerJoined,
      joinEvent.toJson(),
      excludePlayerId: playerId,
    );
    _broadcastEnvelope(
      MessageType.rosterUpdate,
      RosterUpdateMsg(roster: node.roster).toJson(),
    );

    _scheduleSnapshotSave();
  }

  void _handleRejoinRequest(
    WebSocketChannel channel,
    String sid,
    RejoinRequest req,
  ) {
    // Validate session ID on rejoin
    if (sid.isNotEmpty && sid != node.sessionId) {
      _sendReject(
        channel,
        RejectCode.invalidToken,
        'Несовпадение идентификатора сессии.',
      );
      return;
    }

    final existing = registry.findByToken(req.token);
    if (existing == null || existing.playerId != req.playerId) {
      _sendReject(
        channel,
        RejectCode.invalidToken,
        'Токен недействителен или место освобождено.',
        claimableSeats: getClaimableSeats(),
      );
      return;
    }

    // Reattach connection
    registry.register(
      playerId: req.playerId,
      token: req.token,
      channel: channel,
    );

    // Event reconciliation: if client has events the host lacks
    if (req.lastSeq > node.currentSeq) {
      _sendDirect(
        channel,
        MessageType.syncPushRequest,
        SyncPushRequest(hostSeq: node.currentSeq).toJson(),
      );
    } else {
      // Send full authoritative snapshot on rejoin to guarantee all players,
      // levels, traits, and event history are 100% restored on the client.
      final snapMsg = SyncSnapshotMsg(snapshot: node.snapshot);
      _sendDirect(channel, MessageType.syncSnapshot, snapMsg.toJson());
    }

    // Always provide the latest roster on rejoin
    _sendDirect(
      channel,
      MessageType.rosterUpdate,
      RosterUpdateMsg(roster: node.roster).toJson(),
    );

    node.onStateUpdated?.call();
  }

  String _resolveUniqueName(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) trimmed = 'Манчкин';
    if (trimmed.length > AppConstants.maxNameLength) {
      trimmed = trimmed.substring(0, AppConstants.maxNameLength);
    }

    final existingNames = node.players.map((p) => p.name).toSet();
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
      sessionId: node.sessionId,
      epoch: node.epoch,
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
      sessionId: node.sessionId,
      epoch: node.epoch,
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
      sessionId: node.sessionId,
      epoch: node.epoch,
      data: data,
    );
    try {
      channel.sink.add(env.encode());
    } catch (_) {}
  }

  void _handleSeatClaim(WebSocketChannel channel, SeatClaimRequest req) {
    final player = node.getPlayer(req.playerId);
    if (player == null || player.id == node.hostPlayerId) {
      _sendReject(
        channel,
        RejectCode.invalidToken,
        'Место не найдено или недоступно для захвата.',
        claimableSeats: getClaimableSeats(),
      );
      return;
    }

    final isLocal = player.ownerId != null;
    final conn = registry.get(player.id);
    final isDisconnected = conn == null || !conn.isConnected;
    if (!isLocal && !isDisconnected) {
      _sendReject(
        channel,
        RejectCode.invalidToken,
        'Место уже занято другим активным игроком.',
        claimableSeats: getClaimableSeats(),
      );
      return;
    }

    // Mint a new token and invalidate any prior token
    final newToken = const Uuid().v4().replaceAll('-', '');
    final otherSeats = node.seats.where((s) => s.playerId != req.playerId).toList();
    node.updateSeats([...otherSeats, Seat(playerId: req.playerId, token: newToken)]);

    // Bind connection to seat
    registry.register(playerId: req.playerId, token: newToken, channel: channel);

    // Update roster entry with client IP / port
    final existingRanks = node.roster.map((r) => r.rank).toSet();
    var nextRank = 1;
    while (existingRanks.contains(nextRank)) {
      nextRank++;
    }
    final existingEntry = node.roster.where((r) => r.playerId == req.playerId).firstOrNull;
    final otherRoster = node.roster.where((r) => r.playerId != req.playerId).toList();
    node.updateRoster([
      ...otherRoster,
      RosterEntry(
        playerId: req.playerId,
        ips: req.listenIps.isNotEmpty ? req.listenIps : (existingEntry?.ips ?? const []),
        port: req.listenPort ?? existingEntry?.port ?? AppConstants.defaultPort,
        rank: existingEntry?.rank ?? nextRank,
      ),
    ]);

    // If a new name is specified, update it
    if (req.newName != null && req.newName!.trim().isNotEmpty && req.newName!.trim() != player.name) {
      final resolvedName = _resolveUniqueName(req.newName!.trim());
      final updateEvent = PlayerUpdated(
        seq: node.currentSeq + 1,
        eventId: const Uuid().v4(),
        ts: DateTime.now(),
        playerId: player.id,
        name: resolvedName,
      );
      node.apply(updateEvent);
      _broadcastEnvelope(
        MessageType.playerUpdated,
        updateEvent.toJson(),
        excludePlayerId: req.playerId,
      );
    }

    // Apply SeatClaimed (SessionReducer clears ownerId)
    final claimEvent = SeatClaimed(
      seq: node.currentSeq + 1,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      playerId: req.playerId,
    );
    node.apply(claimEvent);

    final accept = JoinAccept(
      playerId: req.playerId,
      token: newToken,
      snapshot: node.snapshot,
    );
    _sendDirect(channel, MessageType.joinAccept, accept.toJson());

    _broadcastEnvelope(
      MessageType.seatClaimed,
      claimEvent.toJson(),
      excludePlayerId: req.playerId,
    );
    _broadcastEnvelope(
      MessageType.rosterUpdate,
      RosterUpdateMsg(roster: node.roster).toJson(),
    );

    _scheduleSnapshotSave();
  }

  void _sendReject(
    WebSocketChannel channel,
    String code,
    String message, {
    List<ClaimableSeat> claimableSeats = const [],
  }) {
    final reject = JoinReject(
      code: code,
      message: message,
      claimableSeats: claimableSeats,
    );
    _sendDirect(channel, MessageType.joinReject, reject.toJson());
  }

  void _scheduleSnapshotSave() {
    _debounceSaveTimer?.cancel();
    _debounceSaveTimer = Timer(AppConstants.snapshotDebounce, () {
      node.onSnapshotChanged?.call(node.snapshot);
    });
  }

  void dispose() {
    _stopTimers();
    registry.dispose();
  }
}
