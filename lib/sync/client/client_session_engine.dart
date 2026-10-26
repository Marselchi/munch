import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';
import '../common/connection_status.dart';
import '../common/discovery_beacon.dart';
import '../common/event_log.dart';
import '../node/host_role.dart';
import '../node/session_node.dart';
import '../protocol/envelope.dart';
import '../protocol/messages.dart';
import '../protocol/models.dart';
import '../server/ws_server.dart';
import 'heartbeat.dart';
import 'reconnect_policy.dart';
import 'ws_client.dart';

/// Client Session Engine managing replica state, event application,
/// and automated seamless reconnection.
/// Pure Dart (no Flutter imports).
class ClientSessionEngine {
  final String playerName;
  List<String> hostIps;
  int port;
  final String? initialToken;
  final String? initialPlayerId;
  final String? claimPlayerId;
  final List<String> listenIps;
  final int? listenPort;

  final WebSocketClient _client = WebSocketClient();
  late final ReconnectPolicy _reconnectPolicy;
  late final ClientHeartbeat _heartbeat;
  final EventLog _fallbackLog = EventLog();

  SessionNode? _node;
  SyncConnectionStatus _status = SyncConnectionStatus.disconnected;
  SessionSnapshot? _snapshot;
  String? _playerId;
  String? _token;
  bool _isDisposed = false;
  Timer? _reconnectTimer;
  Timer? _handshakeTimer;
  Timer? _failoverTimer;
  Timer? _probeTimer;
  DateTime? _disconnectedSince;
  StreamSubscription? _streamSub;
  Completer<bool>? _handshakeCompleter;

  // Pending level requests tracked by client
  final Set<String> _pendingRequestIds = {};

  // Callbacks
  void Function(SyncConnectionStatus status)? onStatusChanged;
  void Function()? onStateUpdated;
  void Function(String code, String message)? onJoinRejected;
  void Function(List<ClaimableSeat> claimableSeats)? onSeatTakeoverOffered;
  void Function(List<ClaimableSeat> seats)? onClaimableSeatsReceived;
  void Function(String reason)? onSessionEnded;
  void Function(String reqId, String? message)? onLevelRequestDenied;
  void Function(String reqId)? onLevelRequestAcked;
  void Function(HostChanged event)? onHostChanged;
  Future<HostWebSocketServer> Function()? onStartLocalServer;
  void Function(HostWebSocketServer server, HostRole hostRole)? onPromotedToHost;

  ClientSessionEngine({
    required this.playerName,
    required this.hostIps,
    this.port = AppConstants.defaultPort,
    this.initialToken,
    this.initialPlayerId,
    this.claimPlayerId,
    this.listenIps = const [],
    this.listenPort,
    this.onStartLocalServer,
    this.onPromotedToHost,
    this.onHostChanged,
  }) {
    _token = initialToken;
    _playerId = initialPlayerId ?? claimPlayerId;
    _reconnectPolicy = ReconnectPolicy(hostIps: hostIps, port: port);

    _heartbeat = ClientHeartbeat(
      sendPing: _sendPing,
      onWatchdogTimeout: () {
        _handleDisconnectAndReconnect();
      },
    );
  }

  SyncConnectionStatus get status => _status;
  SessionSnapshot? get snapshot => _node?.snapshot ?? _snapshot;
  SessionNode? get node => _node;
  EventLog get eventLog => _node?.eventLog ?? _fallbackLog;
  String? get playerId => _playerId;
  String? get token => _token;

  void setInitialSnapshotForTesting(SessionSnapshot snapshot) {
    _snapshot = snapshot;
    _node = SessionNode(initialSnapshot: snapshot);
  }
  List<Player> get players => snapshot?.players ?? const [];
  Player? get selfPlayer {
    if (snapshot == null) return null;
    if (_playerId != null) {
      final p = snapshot!.players.where((p) => p.id == _playerId).firstOrNull;
      if (p != null) return p;
    }
    if (playerName.isNotEmpty) {
      final matches = snapshot!.players.where((p) => p.name == playerName);
      if (matches.length == 1) {
        _playerId ??= matches.first.id;
        return matches.first;
      }
    }
    return null;
  }

  bool isRequestPending(String reqId) => _pendingRequestIds.contains(reqId);

  /// Initiates the connection flow and awaits the server's handshake response
  /// (joinAccept, syncSnapshot, or syncDelta). Returns true if successfully connected.
  Future<bool> start() async {
    _setStatus(SyncConnectionStatus.reconnecting);
    _handshakeCompleter = Completer<bool>();
    await _tryConnect();
    try {
      return await _handshakeCompleter!.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _tryConnect() async {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _cancelHandshakeTimer();

    try {
      // Race candidate IPs concurrently with fast ~1s timeout
      final (channel, _) = await _client.raceCandidates(
        hostIps,
        port,
        timeout: const Duration(milliseconds: 1200),
      );

      _reconnectPolicy.reset();
      _heartbeat.start();
      _listenToChannel(channel);

      // Start 3-second handshake timeout
      _startHandshakeTimer();

      // Perform handshake: Claim, Rejoin, or Join
      if (claimPlayerId != null && _token == null) {
        _sendClaim(claimPlayerId!, playerName);
      } else if (_playerId != null && _token != null) {
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
      if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
        _handshakeCompleter!.complete(false);
      }
    }
  }

  void _startHandshakeTimer() {
    _cancelHandshakeTimer();
    _handshakeTimer = Timer(const Duration(seconds: 3), () {
      if (_status != SyncConnectionStatus.connected && !_isDisposed) {
        if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
          _handshakeCompleter!.complete(false);
        }
        _handleDisconnectAndReconnect();
      }
    });
  }

  void _cancelHandshakeTimer() {
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
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

      // Validate sid on messages if session snapshot is already known
      if (_snapshot != null &&
          envelope.sid.isNotEmpty &&
          envelope.sid != _snapshot!.sessionId) {
        return;
      }

      // Epoch fencing: ignore messages with lower epoch
      if (envelope.epoch < (_node?.epoch ?? 0)) {
        return;
      }

      switch (envelope.type) {
        case MessageType.joinAccept:
          _cancelHandshakeTimer();
          _cancelFailoverTimer();
          _disconnectedSince = null;
          final accept = JoinAccept.fromJson(envelope.data);
          _playerId = accept.playerId;
          _token = accept.token;
          _snapshot = accept.snapshot;
          if (_node == null) {
            _node = SessionNode(initialSnapshot: accept.snapshot);
          } else {
            _node!.resetSnapshot(accept.snapshot);
          }
          _setStatus(SyncConnectionStatus.connected);
          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.complete(true);
          }
          onStateUpdated?.call();
          break;

        case MessageType.joinReject:
          _cancelHandshakeTimer();
          final reject = JoinReject.fromJson(envelope.data);
          _setStatus(SyncConnectionStatus.disconnected);
          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.complete(false);
          }
          if (reject.claimableSeats.isNotEmpty) {
            onSeatTakeoverOffered?.call(reject.claimableSeats);
          }
          onJoinRejected?.call(reject.code, reject.message);
          break;

        case MessageType.seatsListResponse:
          final resp = SeatsListResponse.fromJson(envelope.data);
          onClaimableSeatsReceived?.call(resp.seats);
          break;

        case MessageType.seatClaimed:
          final event = SeatClaimed(
            seq: envelope.data['seq'] as int,
            eventId: envelope.data['eventId'] as String,
            ts: DateTime.fromMillisecondsSinceEpoch(envelope.data['ts'] as int),
            playerId: envelope.data['playerId'] as String,
          );
          _applySyncEvent(event);
          onStateUpdated?.call();
          break;

        case MessageType.rosterUpdate:
          final rMsg = RosterUpdateMsg.fromJson(envelope.data);
          _node?.updateRoster(rMsg.roster);
          onStateUpdated?.call();
          break;

        case MessageType.syncPushRequest:
          final req = SyncPushRequest.fromJson(envelope.data);
          final missingEvents = eventLog.eventsAfter(req.hostSeq);
          _sendEnvelope(MessageType.syncPush, SyncPushMsg(events: missingEvents).toJson());
          break;

        case MessageType.hostTransfer:
          final transfer = HostTransferMsg.fromJson(envelope.data);
          if (transfer.targetPlayerId == _playerId) {
            _handlePromotedToHost(transfer.nextEpoch, transfer.seats);
          }
          break;

        case MessageType.hostChanged:
          final event = HostChanged(
            seq: envelope.data['seq'] as int? ?? (_node?.currentSeq ?? 0) + 1,
            eventId: envelope.data['eventId'] as String? ?? envelope.id,
            ts: DateTime.fromMillisecondsSinceEpoch(envelope.data['ts'] as int? ?? envelope.ts),
            epoch: envelope.data['epoch'] as int,
            newHostPlayerId: envelope.data['newHostPlayerId'] as String,
            ips: (envelope.data['ips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
            port: envelope.data['port'] as int? ?? AppConstants.defaultPort,
          );
          _handleHostChanged(event);
          break;

        case MessageType.syncSnapshot:
          _cancelHandshakeTimer();
          _cancelFailoverTimer();
          _disconnectedSince = null;
          final snapMsg = SyncSnapshotMsg.fromJson(envelope.data);
          _snapshot = snapMsg.snapshot;
          if (_node == null) {
            _node = SessionNode(initialSnapshot: snapMsg.snapshot);
          } else {
            _node!.resetSnapshot(snapMsg.snapshot);
          }
          _setStatus(SyncConnectionStatus.connected);
          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.complete(true);
          }
          onStateUpdated?.call();
          break;

        case MessageType.syncDelta:
          _cancelHandshakeTimer();
          _cancelFailoverTimer();
          _disconnectedSince = null;
          final deltaMsg = SyncDeltaMsg.fromJson(envelope.data);
          for (final ev in deltaMsg.events) {
            _applySyncEvent(ev);
          }
          _setStatus(SyncConnectionStatus.connected);
          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.complete(true);
          }
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
          break;
      }
    } catch (_) {}
  }

  void _applySyncEvent(SyncEvent event) {
    if (_node == null && _snapshot != null) {
      _node = SessionNode(initialSnapshot: _snapshot!);
    }
    if (_node != null) {
      _node!.apply(event);
      _snapshot = _node!.snapshot;
    } else {
      _fallbackLog.append(event);
    }

    if (event is LevelApplied) {
      _pendingRequestIds.clear();
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
    if (_playerId != null && _node != null) {
      final updated = _node!.players.map((p) {
        return p.id == _playerId ? p.copyWith(gearPower: clamped) : p;
      }).toList();
      _node!.resetSnapshot(_node!.snapshot.copyWith(players: updated));
      _snapshot = _node!.snapshot;
      onStateUpdated?.call();
    }
  }

  void updateTraits(List<String> traitIds) {
    if (_status != SyncConnectionStatus.connected) return;

    final update = TraitsUpdate(traitIds: traitIds);
    _sendEnvelope(MessageType.traitsUpdate, update.toJson());

    if (_playerId != null && _node != null) {
      final updated = _node!.players.map((p) {
        return p.id == _playerId ? p.copyWith(traitIds: traitIds) : p;
      }).toList();
      _node!.resetSnapshot(_node!.snapshot.copyWith(players: updated));
      _snapshot = _node!.snapshot;
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

  /// Queries the host for the list of claimable disconnected or local seats.
  void fetchClaimableSeats() {
    _sendEnvelope(MessageType.seatsListRequest, {});
  }

  /// Claims an existing disconnected or local seat at the table.
  Future<bool> claimSeat({required String playerId, String? newName}) async {
    _playerId = playerId;
    _handshakeCompleter = Completer<bool>();
    _sendClaim(playerId, newName ?? playerName);
    try {
      return await _handshakeCompleter!.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  void _sendClaim(String playerId, String? newName) {
    final req = SeatClaimRequest(
      playerId: playerId,
      newName: newName,
      listenIps: listenIps,
      listenPort: listenPort,
    );
    _sendEnvelope(MessageType.seatClaimRequest, req.toJson());
  }

  void _sendJoin() {
    final req = JoinRequest(
      name: playerName,
      appVersion: AppConstants.protocolVersion,
      listenIps: listenIps,
      listenPort: listenPort,
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
      sessionId: snapshot?.sessionId ?? '',
      data: data,
    );
    _client.channel?.sink.add(env.encode());
  }

  void _handleHostChanged(HostChanged event) {
    if (event.epoch < (_node?.epoch ?? 0)) return;
    _cancelFailoverTimer();
    _applySyncEvent(event);
    onHostChanged?.call(event);

    if (event.newHostPlayerId != _playerId) {
      // Connect to the new host
      hostIps = List.from(event.ips);
      port = event.port;
      _reconnectPolicy.updateCandidates(event.ips, event.port);
      _handleDisconnectAndReconnect();
    }
  }

  Future<void> _handlePromotedToHost(int nextEpoch, [List<Seat>? seats]) async {
    _cancelHandshakeTimer();
    _cancelFailoverTimer();
    _heartbeat.stop();
    _streamSub?.cancel();
    _client.disconnect();

    if (_node == null || _playerId == null) return;

    if (seats != null && seats.isNotEmpty) {
      _node!.updateSeats(seats);
    }

    HostWebSocketServer? server;
    if (onStartLocalServer != null) {
      server = await onStartLocalServer!();
    }

    final hostRole = HostRole();
    _node!.attachHostRole(hostRole);

    final ips = listenIps.isNotEmpty ? listenIps : hostIps;
    final sPort = server?.port ?? port;

    final hostChanged = HostChanged(
      seq: _node!.currentSeq + 1,
      eventId: const Uuid().v4(),
      ts: DateTime.now(),
      epoch: nextEpoch,
      newHostPlayerId: _playerId!,
      ips: ips,
      port: sPort,
    );

    hostRole.broadcastHostChanged(hostChanged);
    hostRole.updateHostNetworkInfo(ips, sPort);
    onHostChanged?.call(hostChanged);

    _setStatus(SyncConnectionStatus.connected);
    if (server != null) {
      onPromotedToHost?.call(server, hostRole);
    }
    onStateUpdated?.call();
  }

  /// Called when a UDP broadcast discovery beacon is heard from a table host.
  void handleDiscoveredBeacon(DiscoveryBeaconData beacon) {
    final curSnapshot = snapshot;
    if (curSnapshot != null && beacon.sid != curSnapshot.sessionId) return;
    if (beacon.epoch < (curSnapshot?.epoch ?? 0)) return;

    final ipsChanged = beacon.ips.isNotEmpty &&
        (hostIps.length != beacon.ips.length ||
            !hostIps.every((ip) => beacon.ips.contains(ip)));
    final portChanged = beacon.port != port;

    if (ipsChanged || portChanged || _status != SyncConnectionStatus.connected) {
      hostIps = List.from(beacon.ips);
      port = beacon.port;
      _reconnectPolicy.updateCandidates(beacon.ips, beacon.port);
      triggerImmediateReconnect();
    }
  }

  void _handleDisconnectAndReconnect() {
    if (_isDisposed) return;
    _cancelHandshakeTimer();
    _heartbeat.stop();
    _streamSub?.cancel();
    _client.disconnect();

    _setStatus(SyncConnectionStatus.reconnecting);

    _disconnectedSince ??= DateTime.now();
    _scheduleFailoverElection();

    final delay = _reconnectPolicy.nextDelay();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () => _tryConnect());
  }

  void _scheduleFailoverElection() {
    if (_failoverTimer != null || _node == null || _playerId == null || _node!.roster.isEmpty) {
      return;
    }

    final candidates = _node!.roster
        .where((r) => r.playerId != _node!.hostPlayerId)
        .toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));

    final myIndex = candidates.indexWhere((r) => r.playerId == _playerId);
    if (myIndex < 0) return;

    final electionDelay = AppConstants.failoverGracePeriod +
        (AppConstants.failoverRankInterval * myIndex);

    _failoverTimer = Timer(electionDelay, () async {
      await _runElectionPromotion(candidates, myIndex);
    });

    _startPeerProbing(candidates.sublist(0, myIndex));
  }

  void _startPeerProbing(List<RosterEntry> higherRanked) {
    if (higherRanked.isEmpty) return;
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      if (_status == SyncConnectionStatus.connected || _isDisposed) {
        t.cancel();
        return;
      }
      for (final peer in higherRanked) {
        if (peer.ips.isNotEmpty) {
          try {
            final (channel, _) = await _client.raceCandidates(
              peer.ips,
              peer.port,
              timeout: const Duration(milliseconds: 800),
            );
            _cancelFailoverTimer();
            _probeTimer?.cancel();
            _probeTimer = null;
            _listenToChannel(channel);
            _sendRejoin();
            return;
          } catch (_) {}
        }
      }
    });
  }

  Future<void> _runElectionPromotion(List<RosterEntry> candidates, int myIndex) async {
    _cancelFailoverTimer();
    if (_status == SyncConnectionStatus.connected || _isDisposed) return;

    for (var i = 0; i < myIndex; i++) {
      final peer = candidates[i];
      if (peer.ips.isNotEmpty) {
        try {
          final (channel, _) = await _client.raceCandidates(
            peer.ips,
            peer.port,
            timeout: const Duration(milliseconds: 1000),
          );
          _listenToChannel(channel);
          _sendRejoin();
          return;
        } catch (_) {}
      }
    }

    // No higher peer is running as host -> promote self
    final nextEpoch = (_node?.epoch ?? 0) + 1;
    await _handlePromotedToHost(nextEpoch);
  }

  void _cancelFailoverTimer() {
    _failoverTimer?.cancel();
    _failoverTimer = null;
    _probeTimer?.cancel();
    _probeTimer = null;
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
    if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
      _handshakeCompleter!.complete(false);
    }
    _cancelHandshakeTimer();
    _cancelFailoverTimer();
    _heartbeat.stop();
    _reconnectTimer?.cancel();
    _streamSub?.cancel();
    _client.disconnect();
    _setStatus(SyncConnectionStatus.disconnected);
  }
}
