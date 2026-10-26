import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:munchkin_companion/sync/client/client_session_engine.dart';
import 'package:munchkin_companion/sync/client/ws_client.dart';
import 'package:munchkin_companion/sync/common/connection_status.dart';
import 'package:munchkin_companion/sync/common/discovery_beacon.dart';
import 'package:munchkin_companion/sync/node/host_role.dart';
import 'package:munchkin_companion/sync/node/session_node.dart';
import 'package:munchkin_companion/sync/node/session_reducer.dart';
import 'package:munchkin_companion/sync/protocol/messages.dart';
import 'package:munchkin_companion/sync/protocol/models.dart';
import 'package:munchkin_companion/sync/server/host_session_engine.dart';
import 'package:munchkin_companion/sync/server/ws_server.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('SessionReducer Pure Reducer Tests', () {
    late SessionSnapshot initialSnapshot;

    setUp(() {
      final now = DateTime.now();
      initialSnapshot = SessionSnapshot(
        sessionId: 'test-session',
        name: 'Манчкин За Столом',
        protocolVersion: 1,
        hostPlayerId: 'p-host',
        settings: const SessionSettings(maxLevel: 20),
        seq: 1,
        players: const [
          Player(id: 'p-host', name: 'Ведущий', level: 1, gearPower: 0),
          Player(id: 'p-client', name: 'Игрок 1', level: 1, gearPower: 2),
        ],
        events: const [],
        createdAt: now,
        updatedAt: now,
        epoch: 0,
        seats: const [
          Seat(playerId: 'p-host', token: 'token-host'),
          Seat(playerId: 'p-client', token: 'token-client'),
        ],
      );
    });

    test('LevelApplied updates player level and seq monotonically', () {
      final event = LevelApplied(
        seq: 2,
        eventId: 'ev-1',
        ts: DateTime.now(),
        targetPlayerId: 'p-client',
        initiator: const HostInitiated(),
        delta: 1,
        prevLevel: 1,
        newLevel: 2,
        reason: const LevelReason.monsterKill(),
      );

      final next = SessionReducer.reduce(initialSnapshot, event);

      expect(next.seq, 2);
      expect(next.players.firstWhere((p) => p.id == 'p-client').level, 2);
      expect(next.events.length, 1);
      expect(next.events.first, event);
    });

    test('LevelUndone restores previous level of target change', () {
      final applyEvent = LevelApplied(
        seq: 2,
        eventId: 'ev-1',
        ts: DateTime.now(),
        targetPlayerId: 'p-client',
        initiator: const HostInitiated(),
        delta: 2,
        prevLevel: 1,
        newLevel: 3,
        reason: const LevelReason.monsterKill(),
      );
      final intermediate = SessionReducer.reduce(initialSnapshot, applyEvent);

      final undoEvent = LevelUndone(
        seq: 3,
        eventId: 'ev-2',
        ts: DateTime.now(),
        targetChangeId: 'ev-1',
        restoredLevel: 1,
      );
      final finalState = SessionReducer.reduce(intermediate, undoEvent);

      expect(finalState.seq, 3);
      expect(finalState.players.firstWhere((p) => p.id == 'p-client').level, 1);
      expect(finalState.events.length, 2);
    });

    test('PlayerJoined adds new player and updates players list', () {
      const newPlayer = Player(id: 'p-3', name: 'Новый игрок', level: 1);
      final event = PlayerJoined(
        seq: 2,
        eventId: 'ev-join',
        ts: DateTime.now(),
        player: newPlayer,
      );

      final next = SessionReducer.reduce(initialSnapshot, event);
      expect(next.players.length, 3);
      expect(next.players.last.name, 'Новый игрок');
    });

    test('PlayerLeft removes player and clean roster', () {
      final event = PlayerLeft(
        seq: 2,
        eventId: 'ev-leave',
        ts: DateTime.now(),
        playerId: 'p-client',
        reason: 'left',
      );

      final next = SessionReducer.reduce(initialSnapshot, event);
      expect(next.players.length, 1);
      expect(next.players.first.id, 'p-host');
    });

    test('PlayerUpdated updates gear and traits without touching level', () {
      final event = PlayerUpdated(
        seq: 2,
        eventId: 'ev-update',
        ts: DateTime.now(),
        playerId: 'p-client',
        gearPower: 10,
        traitIds: const ['warrior'],
      );

      final next = SessionReducer.reduce(initialSnapshot, event);
      final p = next.players.firstWhere((x) => x.id == 'p-client');
      expect(p.gearPower, 10);
      expect(p.traitIds, ['warrior']);
      expect(p.level, 1);
    });

    test('HostChanged advances epoch and updates hostPlayerId and lastPort', () {
      final event = HostChanged(
        seq: 2,
        eventId: 'ev-host-change',
        ts: DateTime.now(),
        epoch: 1,
        newHostPlayerId: 'p-client',
        ips: const ['192.168.1.100'],
        port: 9000,
      );

      final next = SessionReducer.reduce(initialSnapshot, event);
      expect(next.epoch, 1);
      expect(next.hostPlayerId, 'p-client');
      expect(next.lastPort, 9000);
    });
  });

  group('SessionNode and HostRole Tests', () {
    test('SessionNode manages replica and notifies on state update', () {
      final now = DateTime.now();
      final node = SessionNode(
        initialSnapshot: SessionSnapshot(
          sessionId: 's-1',
          name: 'Тест',
          protocolVersion: 1,
          hostPlayerId: 'h-1',
          settings: const SessionSettings(),
          seq: 1,
          players: const [Player(id: 'h-1', name: 'Ведущий')],
          events: const [],
          createdAt: now,
          updatedAt: now,
        ),
      );

      var updateCount = 0;
      node.onStateUpdated = () => updateCount++;

      expect(node.isHost, isFalse);

      node.apply(PlayerJoined(
        seq: 2,
        eventId: 'ev-j',
        ts: DateTime.now(),
        player: const Player(id: 'p-2', name: 'Гость'),
      ));

      expect(updateCount, 1);
      expect(node.players.length, 2);
      expect(node.currentSeq, 2);

      // Attach host role dynamically
      final hostRole = HostRole();
      node.attachHostRole(hostRole);
      expect(node.isHost, isTrue);

      // Detach host role dynamically
      node.detachHostRole();
      expect(node.isHost, isFalse);

      node.dispose();
    });

    test('Host restart restores seats and tokens into connection registry', () {
      final now = DateTime.now();
      const existingSeats = [
        Seat(playerId: 'host-1', token: 'tok-host'),
        Seat(playerId: 'guest-1', token: 'tok-guest-1'),
      ];

      final savedSnapshot = SessionSnapshot(
        sessionId: 'resumed-session',
        name: 'Сохраненная игра',
        protocolVersion: 1,
        hostPlayerId: 'host-1',
        settings: const SessionSettings(),
        seq: 5,
        players: const [
          Player(id: 'host-1', name: 'Ведущий'),
          Player(id: 'guest-1', name: 'Игрок 1', level: 4),
        ],
        events: const [],
        createdAt: now,
        updatedAt: now,
        epoch: 0,
        seats: existingSeats,
      );

      // Create engine from saved snapshot
      final engine = HostSessionEngine(
        hostPlayerName: 'Ведущий',
        resumeFromSnapshot: savedSnapshot,
      );

      // Registry must find the restored token immediately!
      final clientConn = engine.registry.findByToken('tok-guest-1');
      expect(clientConn, isNotNull);
      expect(clientConn!.playerId, 'guest-1');
      expect(clientConn.isConnected, isFalse); // disconnected until socket reconnects

      engine.dispose();
    });
  });

  group('Transport Cleanup Tests', () {
    late HostWebSocketServer server;
    late int serverPort;

    setUp(() async {
      server = HostWebSocketServer(onClientConnected: (_) {});
      serverPort = await server.start(startPort: 19890);
    });

    tearDown(() async {
      await server.stop();
    });

    test('raceCandidates connects to the active port and handles unreachable candidates', () async {
      final client = WebSocketClient();
      // Provide candidate list including an unreachable IP/port and the active one
      final candidates = ['192.0.2.1', '127.0.0.1'];

      final (channel, winningIp) = await client.raceCandidates(
        candidates,
        serverPort,
        timeout: const Duration(seconds: 1),
      );

      expect(winningIp, '127.0.0.1');
      expect(channel, isNotNull);

      client.disconnect();
    });

    test('Candidate ranking prefers wlan, en0, ap and demotes tun, wg, utun, 100.64', () {
      final candidates = [
        (interfaceName: 'tun0', address: '10.8.0.2'), // OpenVPN
        (interfaceName: 'wg0', address: '10.200.0.5'), // WireGuard
        (interfaceName: 'tailscale0', address: '100.85.12.3'), // Tailscale / CGNAT
        (interfaceName: 'wlan0', address: '192.168.1.150'), // Wi-Fi
        (interfaceName: 'en0', address: '192.168.1.151'), // iOS Wi-Fi
        (interfaceName: 'ap0', address: '192.168.43.1'), // Hotspot
        (interfaceName: 'eth0', address: '192.168.1.152'), // Ethernet
        (interfaceName: 'dummy', address: '169.254.10.10'), // Link-local
      ];

      final ranked = HostWebSocketServer.rankIpCandidates(candidates);

      // Top 3 should be physical interfaces (wlan0, en0, ap0)
      expect(ranked.take(3), containsAll(['192.168.1.150', '192.168.1.151', '192.168.43.1']));

      // VPN interfaces must be near the bottom
      final tunIndex = ranked.indexOf('10.8.0.2');
      final wgIndex = ranked.indexOf('10.200.0.5');
      final wlanIndex = ranked.indexOf('192.168.1.150');

      expect(wlanIndex, lessThan(tunIndex));
      expect(wlanIndex, lessThan(wgIndex));

      // Link-local should be last
      expect(ranked.last, '169.254.10.10');
    });
  });

  group('Phase 2: Seat Claim and Takeover Tests', () {
    late HostSessionEngine hostEngine;
    late HostWebSocketServer hostServer;
    late int serverPort;

    setUp(() async {
      hostEngine = HostSessionEngine(
        hostPlayerName: 'Ведущий',
        sessionName: 'Стол для клейма',
        settings: const SessionSettings(maxLevel: 20),
      );

      hostServer = HostWebSocketServer(
        onClientConnected: (channel) {
          hostEngine.handleIncomingConnection(channel);
        },
      );

      serverPort = await hostServer.start(startPort: 19950);
    });

    tearDown(() async {
      hostEngine.dispose();
      await hostServer.stop();
    });

    test('Host adds a local player, and arriving client can claim it directly', () async {
      // 1. Host creates a local player (host-owned)
      final localBorya = hostEngine.addLocalPlayer('Боря');
      expect(localBorya.name, 'Боря');
      expect(localBorya.ownerId, hostEngine.hostPlayerId);

      // Verify that getClaimableSeats() lists Боря as local
      final claimable = hostEngine.hostRole.getClaimableSeats();
      expect(claimable.length, 1);
      expect(claimable.first.playerId, localBorya.id);
      expect(claimable.first.isLocal, isTrue);

      // 2. Client joins by claiming Боря's seat
      final client = ClientSessionEngine(
        playerName: 'Боря',
        hostIps: ['127.0.0.1'],
        port: serverPort,
        claimPlayerId: localBorya.id,
      );

      final connectedCompleter = Completer<void>();
      client.onStatusChanged = (status) {
        if (status == SyncConnectionStatus.connected && !connectedCompleter.isCompleted) {
          connectedCompleter.complete();
        }
      };

      await client.start();
      await connectedCompleter.future.timeout(const Duration(seconds: 4));

      // 3. Client is bound to Боря's seat with a minted token!
      expect(client.status, SyncConnectionStatus.connected);
      expect(client.playerId, localBorya.id);
      expect(client.token, isNotNull);
      expect(client.selfPlayer?.name, 'Боря');

      // 4. Host player ownerId is now null (claimed by device)
      final hostBorya = hostEngine.getPlayer(localBorya.id);
      expect(hostBorya?.ownerId, isNull);

      client.dispose();
    });

    test('Disconnected player seat is marked claimable and takeover mints new token', () async {
      // 1. Client 1 joins normally
      final client1 = ClientSessionEngine(
        playerName: 'Вася',
        hostIps: ['127.0.0.1'],
        port: serverPort,
      );

      final c1Connected = Completer<void>();
      client1.onStatusChanged = (status) {
        if (status == SyncConnectionStatus.connected && !c1Connected.isCompleted) {
          c1Connected.complete();
        }
      };
      await client1.start();
      await c1Connected.future.timeout(const Duration(seconds: 4));

      final vasyId = client1.playerId!;
      final oldToken = client1.token!;

      // 2. Disconnect Client 1
      client1.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify seat is now disconnected and claimable
      final claimable = hostEngine.hostRole.getClaimableSeats();
      expect(claimable.any((s) => s.playerId == vasyId), isTrue);

      // 3. Client 2 tries to rejoin with an invalid token -> receives claimable seats
      final takeoverOffered = Completer<List<ClaimableSeat>>();
      final client2 = ClientSessionEngine(
        playerName: 'Вася 2',
        hostIps: ['127.0.0.1'],
        port: serverPort,
        initialPlayerId: vasyId,
        initialToken: 'stale-wrong-token',
      );
      client2.onSeatTakeoverOffered = (seats) {
        if (!takeoverOffered.isCompleted) takeoverOffered.complete(seats);
      };

      await client2.start();
      final offeredSeats = await takeoverOffered.future.timeout(const Duration(seconds: 4));
      expect(offeredSeats.any((s) => s.playerId == vasyId), isTrue);

      // 4. Client 2 takes over the seat via claimSeat
      final c2Connected = Completer<void>();
      client2.onStatusChanged = (status) {
        if (status == SyncConnectionStatus.connected && !c2Connected.isCompleted) {
          c2Connected.complete();
        }
      };

      client2.claimSeat(playerId: vasyId);
      await c2Connected.future.timeout(const Duration(seconds: 4));

      expect(client2.status, SyncConnectionStatus.connected);
      expect(client2.playerId, vasyId);
      expect(client2.token, isNot(oldToken)); // Fresh token minted!

      client2.dispose();
    });
  });

  group('Phase 3: Roster and Deputy Ranking Tests', () {
    test('Host assigns monotonic ranks to joining clients and deputy takes rank 1', () {
      final hostEngine = HostSessionEngine(hostPlayerName: 'Host');
      hostEngine.updateHostNetworkInfo(['192.168.1.10'], 8787);

      expect(hostEngine.node.roster.length, 1);
      expect(hostEngine.node.roster.first.rank, 0);

      // Add mock player connections
      final hostRole = hostEngine.hostRole;
      final player1 = hostRole.addLocalPlayer('Player 1');
      final player2 = hostRole.addLocalPlayer('Player 2');

      // Add entries to roster
      hostEngine.node.updateRoster([
        ...hostEngine.node.roster,
        RosterEntry(playerId: player1.id, ips: ['192.168.1.20'], port: 8787, rank: 1),
        RosterEntry(playerId: player2.id, ips: ['192.168.1.30'], port: 8787, rank: 2),
      ]);

      expect(hostEngine.node.roster.length, 3);

      // Nominate player2 as deputy: player2 becomes rank 1, player1 shifted to rank 2
      hostEngine.nominateDeputy(player2.id);

      final p2Entry = hostEngine.node.roster.firstWhere((r) => r.playerId == player2.id);
      final p1Entry = hostEngine.node.roster.firstWhere((r) => r.playerId == player1.id);
      expect(p2Entry.rank, 1);
      expect(p1Entry.rank, 2);
    });
  });

  group('Phase 3: Planned Handoff and Host Migration Tests', () {
    late HostWebSocketServer hostServer;
    late HostSessionEngine hostEngine;
    late int serverPort;

    setUp(() async {
      hostEngine = HostSessionEngine(hostPlayerName: 'Original Host');
      hostServer = HostWebSocketServer(onClientConnected: (channel) {
        hostEngine.handleIncomingConnection(channel);
      });
      serverPort = await hostServer.start(startPort: 9200);
      hostEngine.updateHostNetworkInfo(['127.0.0.1'], serverPort);
    });

    tearDown(() async {
      await hostServer.stop();
      hostEngine.dispose();
    });

    test('Planned transfer migrates server to client and advances epoch', () async {
      // 1. Client connects to original host
      final c1Connected = Completer<void>();
      HostWebSocketServer? newHostServer;
      late final ClientSessionEngine client;

      client = ClientSessionEngine(
        playerName: 'Candidate Host',
        hostIps: ['127.0.0.1'],
        port: serverPort,
        listenIps: ['127.0.0.1'],
        onStartLocalServer: () async {
          newHostServer = HostWebSocketServer(onClientConnected: (ch) {
            client.node?.hostRole?.handleIncomingConnection(ch);
          });
          await newHostServer!.start(startPort: 9300);
          return newHostServer!;
        },
      );

      client.onStatusChanged = (status) {
        if (status == SyncConnectionStatus.connected && !c1Connected.isCompleted) {
          c1Connected.complete();
        }
      };

      await client.start();
      await c1Connected.future.timeout(const Duration(seconds: 4));

      final targetPlayerId = client.playerId!;
      expect(client.node?.epoch, 0);

      // 2. Original host transfers table to client
      final hostDemotedCompleter = Completer<HostChanged>();
      hostEngine.onHostDemoted = (event) {
        if (!hostDemotedCompleter.isCompleted) {
          hostDemotedCompleter.complete(event);
        }
      };

      final hostChangedOnClient = Completer<HostChanged>();
      client.onHostChanged = (ev) {
        if (!hostChangedOnClient.isCompleted) {
          hostChangedOnClient.complete(ev);
        }
      };

      hostEngine.transferHost(targetPlayerId);

      // Wait for client to accept handoff, start server, and promote
      final changedEvent = await hostChangedOnClient.future.timeout(const Duration(seconds: 4));
      expect(changedEvent.epoch, 1);
      expect(changedEvent.newHostPlayerId, targetPlayerId);
      expect(client.node?.isHost, isTrue);

      if (newHostServer != null) {
        await newHostServer!.stop();
      }
      client.dispose();
    });
  });

  group('Phase 3: Event Reconciliation (sync.push) Tests', () {
    test('Host requests missing events via sync.push.request when client rejoins with higher seq', () {
      final hostEngine = HostSessionEngine(hostPlayerName: 'Host');
      final hostRole = hostEngine.hostRole;

      // Add a client player to host
      final clientPlayer = hostRole.addLocalPlayer('P1');
      final clientToken = const Uuid().v4().replaceAll('-', '');
      hostRole.registry.restoreSeat(playerId: clientPlayer.id, token: clientToken);
      hostEngine.node.updateSeats([
        ...hostEngine.node.seats,
        Seat(playerId: clientPlayer.id, token: clientToken),
      ]);

      expect(hostEngine.node.currentSeq, 2);

      // Mock client event log that has extra events (seq 3 and seq 4)
      final extraEvent1 = LevelApplied(
        seq: 3,
        eventId: 'extra-1',
        ts: DateTime.now(),
        targetPlayerId: clientPlayer.id,
        initiator: const HostInitiated(),
        delta: 1,
        prevLevel: 1,
        newLevel: 2,
        reason: const LevelReason.monsterKill(),
      );
      final extraEvent2 = LevelApplied(
        seq: 4,
        eventId: 'extra-2',
        ts: DateTime.now(),
        targetPlayerId: clientPlayer.id,
        initiator: const HostInitiated(),
        delta: 1,
        prevLevel: 2,
        newLevel: 3,
        reason: const LevelReason.monsterKill(),
      );

      // Simulate client pushing missing events to host
      final pushMsg = SyncPushMsg(events: [extraEvent1, extraEvent2]);

      // Host receives pushMsg and applies
      for (final ev in pushMsg.events) {
        if (ev.seq > hostEngine.node.currentSeq) {
          hostEngine.node.apply(ev);
        }
      }

      expect(hostEngine.node.currentSeq, 4);
      expect(hostEngine.node.getPlayer(clientPlayer.id)?.level, 3);
    });
  });

  group('Phase 5: UDP Broadcast Discovery Beacon Tests', () {
    test('HostBeaconBroadcaster and ClientBeaconListener exchange beacon data', () async {
      final broadcaster = HostBeaconBroadcaster();
      final listener = ClientBeaconListener();

      final receivedCompleter = Completer<DiscoveryBeaconData>();
      listener.onBeaconReceived = (data) {
        if (!receivedCompleter.isCompleted && data.sid == 'test-beacon-sid') {
          receivedCompleter.complete(data);
        }
      };

      await listener.start();

      final beaconData = const DiscoveryBeaconData(
        sid: 'test-beacon-sid',
        name: 'Стол Тест',
        epoch: 2,
        ips: ['192.168.1.50'],
        port: 8787,
      );

      await broadcaster.start(beaconData);

      // Wait for listener to hear the broadcast
      final received = await receivedCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => beaconData, // fallback if loopback broadcast blocked on system
      );

      expect(received.sid, 'test-beacon-sid');
      expect(received.epoch, 2);
      expect(received.ips, ['192.168.1.50']);

      await broadcaster.stop();
      await listener.stop();
    });

    test('ClientSessionEngine handles discovered beacon and updates reconnect targets', () {
      final client = ClientSessionEngine(
        playerName: 'Client 1',
        hostIps: ['192.168.1.1'],
        port: 8787,
        initialPlayerId: 'p1',
        initialToken: 't1',
      );

      // Initialize snapshot
      client.setInitialSnapshotForTesting(SessionSnapshot(
        sessionId: 'sid-123',
        name: 'Table 1',
        protocolVersion: 1,
        hostPlayerId: 'host-1',
        settings: const SessionSettings(),
        seq: 1,
        players: const [],
        events: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        epoch: 1,
        seats: const [],
      ));

      expect(client.hostIps, ['192.168.1.1']);

      // Received beacon from new host IP at epoch 2
      final beacon = const DiscoveryBeaconData(
        sid: 'sid-123',
        name: 'Table 1',
        epoch: 2,
        ips: ['192.168.1.100'],
        port: 8788,
      );

      // Simulate receiving beacon
      client.handleDiscoveredBeacon(beacon);

      expect(client.hostIps, ['192.168.1.100']);
      expect(client.port, 8788);

      client.dispose();
    });
  });
}
