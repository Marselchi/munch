import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../persistence/session_snapshot_store.dart';
import '../../../sync/client/client_session_engine.dart';
import '../../../sync/common/discovery_beacon.dart';
import '../../../sync/common/event_log.dart';
import '../../../sync/common/network_binder.dart';
import '../../../sync/node/host_role.dart';
import '../../../sync/protocol/models.dart';
import '../../../sync/server/host_session_engine.dart';
import '../../../sync/server/ws_server.dart';

class HostSessionState {
  final HostSessionEngine engine;
  final HostWebSocketServer server;
  final List<String> hostIps;
  final int port;
  final int updateTick; // Monotonically increases on state change

  const HostSessionState({
    required this.engine,
    required this.server,
    required this.hostIps,
    required this.port,
    this.updateTick = 0,
  });

  HostSessionState copyWith({
    HostSessionEngine? engine,
    HostWebSocketServer? server,
    List<String>? hostIps,
    int? port,
    int? updateTick,
  }) {
    return HostSessionState(
      engine: engine ?? this.engine,
      server: server ?? this.server,
      hostIps: hostIps ?? this.hostIps,
      port: port ?? this.port,
      updateTick: updateTick ?? this.updateTick,
    );
  }
}

class HostSessionNotifier extends Notifier<HostSessionState?> {
  HostBeaconBroadcaster? _broadcaster;

  @override
  HostSessionState? build() {
    ref.onDispose(() {
      _broadcaster?.stop();
      state?.engine.dispose();
      state?.server.stop();
      NetworkBinder.unbindFromNetwork();
    });
    return null;
  }

  Future<void> startSession({
    required String hostName,
    String sessionName = 'Манчкин За Столом',
    SessionSnapshot? resumeFromSnapshot,
  }) async {
    // Bind Android process to physical Wi-Fi (excluding VPN)
    await NetworkBinder.bindToPhysicalWifi();

    // 1. Create engine
    final engine = HostSessionEngine(
      hostPlayerName: hostName,
      sessionName: sessionName,
      resumeFromSnapshot: resumeFromSnapshot,
    );

    // Snapshot auto-saving to disk
    engine.onSnapshotChanged = (snapshot) {
      SessionSnapshotStore.saveSnapshot(snapshot);
      _broadcaster?.updateData(DiscoveryBeaconData(
        sid: snapshot.sessionId,
        name: snapshot.name,
        epoch: snapshot.epoch,
        ips: state?.hostIps ?? const [],
        port: state?.port ?? 8787,
      ));
    };

    // 2. Start WebSocket Server
    final server = HostWebSocketServer(
      onClientConnected: (channel) {
        engine.handleIncomingConnection(channel);
      },
    );

    final actualPort = await server.start();
    final ips = await HostWebSocketServer.getHostIpAddresses();

    engine.updateHostNetworkInfo(ips, actualPort);

    _broadcaster?.stop();
    final broadcaster = HostBeaconBroadcaster();
    await broadcaster.start(DiscoveryBeaconData(
      sid: engine.sessionId,
      name: engine.sessionName,
      epoch: engine.snapshot.epoch,
      ips: ips,
      port: actualPort,
    ));
    _broadcaster = broadcaster;

    state = HostSessionState(
      engine: engine,
      server: server,
      hostIps: ips,
      port: actualPort,
      updateTick: 0,
    );

    // Trigger state tick on engine updates
    engine.onStateUpdated = () {
      if (state != null) {
        state = state!.copyWith(updateTick: state!.updateTick + 1);
      }
    };
  }

  void adoptPromotedHost({
    required ClientSessionEngine clientEngine,
    required HostWebSocketServer server,
    required HostRole hostRole,
  }) {
    if (clientEngine.node == null) return;
    final hostEngine = HostSessionEngine.fromNode(clientEngine.node!, hostRole);

    hostEngine.onSnapshotChanged = (snapshot) {
      SessionSnapshotStore.saveSnapshot(snapshot);
      _broadcaster?.updateData(DiscoveryBeaconData(
        sid: snapshot.sessionId,
        name: snapshot.name,
        epoch: snapshot.epoch,
        ips: clientEngine.hostIps,
        port: server.port,
      ));
    };

    _broadcaster?.stop();
    final broadcaster = HostBeaconBroadcaster();
    broadcaster.start(DiscoveryBeaconData(
      sid: hostEngine.sessionId,
      name: hostEngine.sessionName,
      epoch: hostEngine.snapshot.epoch,
      ips: clientEngine.hostIps,
      port: server.port,
    ));
    _broadcaster = broadcaster;

    state = HostSessionState(
      engine: hostEngine,
      server: server,
      hostIps: clientEngine.hostIps,
      port: server.port,
      updateTick: 0,
    );

    hostEngine.onStateUpdated = () {
      if (state != null) {
        state = state!.copyWith(updateTick: state!.updateTick + 1);
      }
    };
  }

  void transferHost(String targetPlayerId) {
    state?.engine.transferHost(targetPlayerId);
  }

  void nominateDeputy(String playerId) {
    state?.engine.nominateDeputy(playerId);
  }

  bool applyLevelChange({
    required String targetPlayerId,
    required Initiator initiator,
    int? delta,
    int? setValue,
    required LevelReason reason,
  }) {
    if (state == null) return false;
    return state!.engine.applyLevelChange(
      targetPlayerId: targetPlayerId,
      initiator: initiator,
      delta: delta,
      setValue: setValue,
      reason: reason,
    );
  }

  bool undoLastLevelChange() {
    if (state == null) return false;
    return state!.engine.undoLastLevelChange();
  }

  void updateGearPower(String playerId, int gearPower) {
    state?.engine.updateGearPower(playerId, gearPower);
  }

  void updateTraits(String playerId, List<String> traitIds) {
    state?.engine.updateTraits(playerId, traitIds);
  }

  void updateMaxLevel(int maxLevel) {
    state?.engine.updateMaxLevel(maxLevel);
  }

  void approveRequest(String reqId) {
    state?.engine.approveRequest(reqId);
  }

  void denyRequest(String reqId, [String? message]) {
    state?.engine.denyRequest(reqId, message);
  }

  void approveJoin(String reqId) {
    state?.engine.approveJoinRequest(reqId);
  }

  void denyJoin(String reqId) {
    state?.engine.denyJoinRequest(reqId);
  }

  void setRequireJoinApproval(bool require) {
    if (state != null) {
      state!.engine.requireJoinApproval = require;
      state = state!.copyWith(updateTick: state!.updateTick + 1);
    }
  }

  void kickPlayer(String playerId) {
    state?.engine.removePlayer(playerId, reason: 'removed');
  }

  void addLocalPlayer(String name) {
    state?.engine.addLocalPlayer(name);
  }

  Future<void> endSession() async {
    if (state != null) {
      final sid = state!.engine.sessionId;
      state!.engine.endSession();
      await _broadcaster?.stop();
      _broadcaster = null;
      await state!.server.stop();
      await SessionSnapshotStore.deleteSnapshot(sid);
      await NetworkBinder.unbindFromNetwork();
      state = null;
    }
  }
}

final hostSessionProvider =
    NotifierProvider<HostSessionNotifier, HostSessionState?>(
  HostSessionNotifier.new,
);

// --- Sliced Providers for Granular UI Rebuilds ---

/// Monotonically increasing tick for session invalidation.
final hostSessionTickProvider = Provider<int>((ref) {
  return ref.watch(hostSessionProvider.select((s) => s?.updateTick ?? 0));
});

/// List of all player IDs in the session (rebuilds only on join/leave).
final hostPlayerIdsProvider = Provider<List<String>>((ref) {
  ref.watch(hostSessionTickProvider);
  final hostState = ref.watch(hostSessionProvider);
  if (hostState == null) return const [];
  return hostState.engine.players.map((p) => p.id).toList();
});

/// Individual player provider (family) - only rebuilds when this specific player changes.
final hostPlayerProvider = Provider.family<Player?, String>((ref, playerId) {
  ref.watch(hostSessionTickProvider);
  final hostState = ref.watch(hostSessionProvider);
  return hostState?.engine.getPlayer(playerId);
});

/// Computed total power (Level + Gear) for a player.
final hostPowerProvider = Provider.family<int, String>((ref, playerId) {
  final player = ref.watch(hostPlayerProvider(playerId));
  return player?.totalPower ?? 0;
});

/// Latest active level change for the table banner.
final hostLatestChangeProvider = Provider<LevelApplied?>((ref) {
  ref.watch(hostSessionTickProvider);
  final hostState = ref.watch(hostSessionProvider);
  return hostState?.engine.eventLog.latestActiveChange;
});

/// Indicates whether undo can be performed (stack not empty).
final hostUndoAvailableProvider = Provider<bool>((ref) {
  ref.watch(hostSessionTickProvider);
  final hostState = ref.watch(hostSessionProvider);
  return hostState?.engine.eventLog.undoCandidate != null;
});

/// Pending requests queue (awaiting host approve/deny).
final hostPendingRequestsProvider = Provider<List<PendingLevelRequest>>((ref) {
  ref.watch(hostSessionTickProvider);
  final hostState = ref.watch(hostSessionProvider);
  return hostState?.engine.pendingRequests ?? const [];
});

/// Join approval requests queue.
final hostPendingApprovalsProvider = Provider<List<JoinApprovalRequest>>((ref) {
  ref.watch(hostSessionTickProvider);
  final hostState = ref.watch(hostSessionProvider);
  return hostState?.engine.pendingJoinApprovals ?? const [];
});

/// Full history entries in reverse chronological order.
final hostHistoryEntriesProvider = Provider<List<HistoryEntry>>((ref) {
  ref.watch(hostSessionTickProvider);
  final hostState = ref.watch(hostSessionProvider);
  return hostState?.engine.eventLog.getHistory() ?? const [];
});

/// Host connection IPs for QR code and manual connection.
final hostIpsProvider = Provider<List<String>>((ref) {
  return ref.watch(hostSessionProvider.select((s) => s?.hostIps ?? const []));
});

/// Host port for QR code and manual connection.
final hostPortProvider = Provider<int>((ref) {
  return ref.watch(hostSessionProvider.select((s) => s?.port ?? 8787));
});

/// Detects if the host is running via hotspot while a VPN tunnel is active.
final hostHotspotVpnWarningProvider = FutureProvider.autoDispose<bool>((ref) async {
  return await HostWebSocketServer.isHotspotWithVpnActive();
});
