import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../persistence/settings_store.dart';
import '../../../sync/client/client_session_engine.dart';
import '../../../sync/common/connection_status.dart';
import '../../../sync/common/discovery_beacon.dart';
import '../../../sync/common/event_log.dart';
import '../../../sync/common/network_binder.dart';
import '../../../sync/protocol/messages.dart';
import '../../../sync/protocol/models.dart';
import '../../../sync/server/ws_server.dart';
import '../../host_session/application/host_session_controller.dart';

class ClientSessionState {
  final ClientSessionEngine engine;
  final SyncConnectionStatus connectionStatus;
  final int updateTick;
  final String? lastErrorMessage;
  final List<ClaimableSeat> claimableSeats;

  const ClientSessionState({
    required this.engine,
    required this.connectionStatus,
    this.updateTick = 0,
    this.lastErrorMessage,
    this.claimableSeats = const [],
  });

  ClientSessionState copyWith({
    ClientSessionEngine? engine,
    SyncConnectionStatus? connectionStatus,
    int? updateTick,
    String? lastErrorMessage,
    List<ClaimableSeat>? claimableSeats,
  }) {
    return ClientSessionState(
      engine: engine ?? this.engine,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      updateTick: updateTick ?? this.updateTick,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      claimableSeats: claimableSeats ?? this.claimableSeats,
    );
  }
}

class ClientSessionNotifier extends Notifier<ClientSessionState?> {
  ClientBeaconListener? _beaconListener;

  @override
  ClientSessionState? build() {
    ref.onDispose(() {
      _beaconListener?.stop();
      state?.engine.dispose();
      NetworkBinder.unbindFromNetwork();
    });
    return null;
  }

  Future<void> joinSession({
    required String playerName,
    required List<String> hostIps,
    required int port,
    String? token,
    String? playerId,
    String? claimPlayerId,
  }) async {
    // Bind Android process to physical Wi-Fi (excluding VPN)
    await NetworkBinder.bindToPhysicalWifi();

    state?.engine.dispose();
    _beaconListener?.stop();

    final myIps = await HostWebSocketServer.getHostIpAddresses();

    final engine = ClientSessionEngine(
      playerName: playerName,
      hostIps: hostIps,
      port: port,
      initialToken: token,
      initialPlayerId: playerId,
      claimPlayerId: claimPlayerId,
      listenIps: myIps,
    );

    engine.onStartLocalServer = () async {
      final server = HostWebSocketServer(onClientConnected: (channel) {
        engine.node?.hostRole?.handleIncomingConnection(channel);
      });
      await server.start();
      return server;
    };

    engine.onPromotedToHost = (server, hostRole) {
      ref.read(hostSessionProvider.notifier).adoptPromotedHost(
        clientEngine: engine,
        server: server,
        hostRole: hostRole,
      );
    };

    final beaconListener = ClientBeaconListener();
    beaconListener.onBeaconReceived = (beacon) {
      engine.handleDiscoveredBeacon(beacon);
    };
    await beaconListener.start();
    _beaconListener = beaconListener;

    state = ClientSessionState(
      engine: engine,
      connectionStatus: SyncConnectionStatus.reconnecting,
      updateTick: 0,
    );

    engine.onStatusChanged = (status) {
      if (state != null) {
        state = state!.copyWith(
          connectionStatus: status,
          updateTick: state!.updateTick + 1,
        );
      }
    };

    engine.onStateUpdated = () {
      if (state != null) {
        // Save session state to disk for background recovery
        if (engine.snapshot != null && engine.playerId != null && engine.token != null) {
          SettingsStore.saveActiveReconnectSession(ReconnectSessionData(
            sessionId: engine.snapshot!.sessionId,
            playerId: engine.playerId!,
            token: engine.token!,
            hostIps: hostIps,
            port: port,
            playerName: playerName,
            sessionName: engine.snapshot!.name,
          ));
        }

        state = state!.copyWith(updateTick: state!.updateTick + 1);
      }
    };

    engine.onJoinRejected = (code, message) {
      if (state != null) {
        state = state!.copyWith(
          lastErrorMessage: '[$code] $message',
          updateTick: state!.updateTick + 1,
        );
      }
    };

    engine.onSeatTakeoverOffered = (seats) {
      if (state != null) {
        state = state!.copyWith(
          claimableSeats: seats,
          updateTick: state!.updateTick + 1,
        );
      }
    };

    engine.onClaimableSeatsReceived = (seats) {
      if (state != null) {
        state = state!.copyWith(
          claimableSeats: seats,
          updateTick: state!.updateTick + 1,
        );
      }
    };

    engine.onSessionEnded = (reason) {
      SettingsStore.clearActiveReconnectSession();
      if (state != null) {
        state = state!.copyWith(
          lastErrorMessage: 'Игра завершена: $reason',
          updateTick: state!.updateTick + 1,
        );
      }
    };

    await engine.start();
  }

  void claimSeat(String playerId, [String? newName]) {
    state?.engine.claimSeat(playerId: playerId, newName: newName);
  }

  void fetchClaimableSeats() {
    state?.engine.fetchClaimableSeats();
  }

  String requestLevelChange({
    int? delta,
    int? setValue,
    required LevelReason reason,
  }) {
    if (state == null) throw StateError('Нет активной игровой сессии.');
    return state!.engine.requestLevelChange(
      delta: delta,
      setValue: setValue,
      reason: reason,
    );
  }

  void updateSelfGearPower(int power) {
    state?.engine.updateGearPower(power);
  }

  void updateSelfTraits(List<String> traitIds) {
    state?.engine.updateTraits(traitIds);
  }

  void retryReconnect() {
    state?.engine.triggerImmediateReconnect();
  }

  void leaveSession() {
    SettingsStore.clearActiveReconnectSession();
    _beaconListener?.stop();
    _beaconListener = null;
    state?.engine.leave();
    NetworkBinder.unbindFromNetwork();
    state = null;
  }
}

final clientSessionProvider =
    NotifierProvider<ClientSessionNotifier, ClientSessionState?>(
  ClientSessionNotifier.new,
);

// --- Sliced Providers for Granular Client UI Rebuilds ---

final clientSessionTickProvider = Provider<int>((ref) {
  return ref.watch(clientSessionProvider.select((s) => s?.updateTick ?? 0));
});

final clientConnectionStatusProvider = Provider<SyncConnectionStatus>((ref) {
  return ref.watch(clientSessionProvider
          .select((s) => s?.connectionStatus ?? SyncConnectionStatus.disconnected));
});

final clientPlayerIdsProvider = Provider<List<String>>((ref) {
  ref.watch(clientSessionTickProvider);
  final clientState = ref.watch(clientSessionProvider);
  return clientState?.engine.players.map((p) => p.id).toList() ?? const [];
});

final clientPlayerProvider = Provider.family<Player?, String>((ref, playerId) {
  ref.watch(clientSessionTickProvider);
  final clientState = ref.watch(clientSessionProvider);
  if (clientState == null) return null;
  final players = clientState.engine.players;
  try {
    return players.firstWhere((p) => p.id == playerId);
  } catch (_) {
    return null;
  }
});

final clientSelfPlayerProvider = Provider<Player?>((ref) {
  ref.watch(clientSessionTickProvider);
  final clientState = ref.watch(clientSessionProvider);
  return clientState?.engine.selfPlayer;
});

final clientPowerProvider = Provider.family<int, String>((ref, playerId) {
  final player = ref.watch(clientPlayerProvider(playerId));
  return player?.totalPower ?? 0;
});

final clientLatestChangeProvider = Provider<LevelApplied?>((ref) {
  ref.watch(clientSessionTickProvider);
  final clientState = ref.watch(clientSessionProvider);
  return clientState?.engine.eventLog.latestActiveChange;
});

final clientHistoryEntriesProvider = Provider<List<HistoryEntry>>((ref) {
  ref.watch(clientSessionTickProvider);
  final clientState = ref.watch(clientSessionProvider);
  return clientState?.engine.eventLog.getHistory() ?? const [];
});

final clientLastErrorMessageProvider = Provider<String?>((ref) {
  return ref.watch(clientSessionProvider.select((s) => s?.lastErrorMessage));
});

final clientClaimableSeatsProvider = Provider<List<ClaimableSeat>>((ref) {
  return ref.watch(clientSessionProvider.select((s) => s?.claimableSeats ?? const []));
});
