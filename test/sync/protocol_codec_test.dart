import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:munchkin_companion/sync/protocol/envelope.dart';
import 'package:munchkin_companion/sync/protocol/messages.dart';
import 'package:munchkin_companion/sync/protocol/models.dart';

void main() {
  group('Protocol Codec and Envelope Tests', () {
    test('Envelope round-trip encoding and decoding', () {
      final env = Envelope.create(
        type: MessageType.joinRequest,
        sessionId: 'session-123',
        data: {'name': 'Манчкин', 'appVersion': 1},
      );

      final encoded = env.encode();
      final decoded = Envelope.decode(encoded);

      expect(decoded.v, 1);
      expect(decoded.type, MessageType.joinRequest);
      expect(decoded.sid, 'session-123');
      expect(decoded.data['name'], 'Манчкин');
      expect(decoded.data['appVersion'], 1);
    });

    test('JoinRequest and RejoinRequest serialize and deserialize', () {
      const join = JoinRequest(name: 'Конан', appVersion: 1);
      final joinJson = join.toJson();
      final joinRestored = JoinRequest.fromJson(joinJson);
      expect(joinRestored.name, 'Конан');
      expect(joinRestored.appVersion, 1);

      const rejoin = RejoinRequest(playerId: 'p1', token: 'tok123', lastSeq: 5);
      final rejoinJson = rejoin.toJson();
      final rejoinRestored = RejoinRequest.fromJson(rejoinJson);
      expect(rejoinRestored.playerId, 'p1');
      expect(rejoinRestored.token, 'tok123');
      expect(rejoinRestored.lastSeq, 5);
    });

    test('LevelRequest with reasons serialize and deserialize', () {
      const req = LevelRequest(
        reqId: 'r-1',
        delta: 1,
        reason: LevelReason.monsterKill(),
      );
      final jsonMap = req.toJson();
      final restored = LevelRequest.fromJson(jsonMap);
      expect(restored.reqId, 'r-1');
      expect(restored.delta, 1);
      expect(restored.reason.kind, ReasonKind.monsterKill);

      const customReq = LevelRequest(
        reqId: 'r-2',
        setValue: 10,
        reason: LevelReason.other('Проклятие потери уровня'),
      );
      final customRestored = LevelRequest.fromJson(customReq.toJson());
      expect(customRestored.setValue, 10);
      expect(customRestored.reason.kind, ReasonKind.other);
      expect(customRestored.reason.customText, 'Проклятие потери уровня');
    });

    test('SyncEvents serialize and deserialize accurately', () {
      final now = DateTime.now();

      final levelApplied = LevelApplied(
        seq: 1,
        eventId: 'ev-1',
        ts: now,
        targetPlayerId: 'p1',
        initiator: const HostInitiated(),
        delta: 2,
        prevLevel: 3,
        newLevel: 5,
        reason: const LevelReason.sell(),
      );
      final levelAppliedJson = levelApplied.toJson();
      final levelAppliedRestored =
          SyncEvent.fromJson(levelAppliedJson) as LevelApplied;
      expect(levelAppliedRestored.seq, 1);
      expect(levelAppliedRestored.newLevel, 5);
      expect(levelAppliedRestored.initiator is HostInitiated, isTrue);

      final levelUndone = LevelUndone(
        seq: 2,
        eventId: 'ev-2',
        ts: now,
        targetChangeId: 'ev-1',
        restoredLevel: 3,
      );
      final undoneRestored =
          SyncEvent.fromJson(levelUndone.toJson()) as LevelUndone;
      expect(undoneRestored.targetChangeId, 'ev-1');
      expect(undoneRestored.restoredLevel, 3);
    });

    test('SessionSnapshot full serialize and deserialize', () {
      final now = DateTime.now();
      final snapshot = SessionSnapshot(
        sessionId: 's-100',
        name: 'Ночной турнир',
        protocolVersion: 1,
        hostPlayerId: 'host-1',
        settings: const SessionSettings(maxLevel: 22),
        seq: 3,
        players: const [
          Player(id: 'host-1', name: 'Ведущий', level: 5, gearPower: 12),
          Player(id: 'p-2', name: 'Эльф-Вор', level: 4, gearPower: 7),
        ],
        events: [
          PlayerJoined(
            seq: 1,
            eventId: 'e-1',
            ts: now,
            player: const Player(id: 'host-1', name: 'Ведущий'),
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final jsonStr = jsonEncode(snapshot.toJson());
      final decoded =
          SessionSnapshot.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      expect(decoded.sessionId, 's-100');
      expect(decoded.name, 'Ночной турнир');
      expect(decoded.settings.maxLevel, 22);
      expect(decoded.players.length, 2);
      expect(decoded.players[0].totalPower, 17);
      expect(decoded.events.length, 1);
    });
  });
}
