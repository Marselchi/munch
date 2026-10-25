import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:munchkin_companion/sync/client/client_session_engine.dart';
import 'package:munchkin_companion/sync/common/connection_status.dart';
import 'package:munchkin_companion/sync/protocol/models.dart';
import 'package:munchkin_companion/sync/server/host_session_engine.dart';
import 'package:munchkin_companion/sync/server/ws_server.dart';

void main() {
  group('Loopback Integration Tests (Real WebSocket Transport)', () {
    late HostSessionEngine hostEngine;
    late HostWebSocketServer hostServer;
    late int serverPort;

    setUp(() async {
      hostEngine = HostSessionEngine(
        hostPlayerName: 'Ведущий',
        sessionName: 'Турнирный стол',
        settings: const SessionSettings(maxLevel: 20),
      );

      hostServer = HostWebSocketServer(
        onClientConnected: (channel) {
          hostEngine.handleIncomingConnection(channel);
        },
      );

      // Start on dynamic ephemeral port
      serverPort = await hostServer.start(startPort: 18787);
    });

    tearDown(() async {
      hostEngine.dispose();
      await hostServer.stop();
    });

    test('Full join, level sync, request approval, and undo over real WebSockets', () async {
      // 1. Client connects and joins
      final client = ClientSessionEngine(
        playerName: 'Манчкин Вася',
        hostIps: ['127.0.0.1'],
        port: serverPort,
      );

      final connectedCompleter = Completer<void>();
      client.onStatusChanged = (status) {
        if (status == SyncConnectionStatus.connected && !connectedCompleter.isCompleted) {
          connectedCompleter.complete();
        }
      };

      await client.start();
      await connectedCompleter.future.timeout(const Duration(seconds: 4));

      expect(client.status, SyncConnectionStatus.connected);
      expect(client.playerId, isNotNull);
      expect(client.snapshot, isNotNull);
      expect(client.players.length, 2); // Host + Вася
      expect(hostEngine.players.length, 2);

      // 2. Host applies level change to Вася (+1)
      final clientLevelUpdated = Completer<int>();
      client.onStateUpdated = () {
        final val = client.selfPlayer?.level;
        if (val == 2 && !clientLevelUpdated.isCompleted) {
          clientLevelUpdated.complete(val!);
        }
      };

      hostEngine.applyLevelChange(
        targetPlayerId: client.playerId!,
        initiator: const HostInitiated(),
        delta: 1,
        reason: const LevelReason.monsterKill(),
      );

      final newLevel = await clientLevelUpdated.future.timeout(const Duration(seconds: 3));
      expect(newLevel, 2);
      expect(client.selfPlayer?.level, 2);

      // 3. Player requests level change (+1 for sell)
      final hostReqReceived = Completer<void>();
      hostEngine.onStateUpdated = () {
        if (hostEngine.pendingRequests.isNotEmpty && !hostReqReceived.isCompleted) {
          hostReqReceived.complete();
        }
      };

      final reqId = client.requestLevelChange(
        delta: 1,
        reason: const LevelReason.sell(),
      );
      expect(client.isRequestPending(reqId), isTrue);

      await hostReqReceived.future.timeout(const Duration(seconds: 3));
      expect(hostEngine.pendingRequests.length, 1);
      expect(hostEngine.pendingRequests.first.reqId, reqId);

      // 4. Host approves the request
      final clientApproved = Completer<int>();
      client.onStateUpdated = () {
        final val = client.selfPlayer?.level;
        if (val == 3 && !clientApproved.isCompleted) {
          clientApproved.complete(val!);
        }
      };

      hostEngine.approveRequest(reqId);
      final approvedLevel = await clientApproved.future.timeout(const Duration(seconds: 3));
      expect(approvedLevel, 3);
      expect(client.isRequestPending(reqId), isFalse);

      // 5. Host undos the most recent change (3 -> 2)
      final clientUndone = Completer<int>();
      client.onStateUpdated = () {
        final val = client.selfPlayer?.level;
        if (val == 2 && !clientUndone.isCompleted) {
          clientUndone.complete(val!);
        }
      };

      hostEngine.undoLastLevelChange();
      final restoredLevel = await clientUndone.future.timeout(const Duration(seconds: 3));
      expect(restoredLevel, 2);

      // 6. Player updates gear power
      final hostGearUpdated = Completer<int>();
      hostEngine.onStateUpdated = () {
        final g = hostEngine.getPlayer(client.playerId!)?.gearPower;
        if (g == 8 && !hostGearUpdated.isCompleted) {
          hostGearUpdated.complete(g!);
        }
      };

      client.updateGearPower(8);
      final receivedGear = await hostGearUpdated.future.timeout(const Duration(seconds: 3));
      expect(receivedGear, 8);

      client.dispose();
    });
  });
}
