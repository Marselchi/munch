import 'package:flutter_test/flutter_test.dart';
import 'package:munchkin_companion/sync/protocol/models.dart';
import 'package:munchkin_companion/sync/server/host_session_engine.dart';

void main() {
  group('HostSessionEngine Unit Tests', () {
    late HostSessionEngine engine;

    setUp(() {
      engine = HostSessionEngine(
        hostPlayerName: 'Ведущий',
        sessionName: 'Тестовый стол',
        settings: const SessionSettings(maxLevel: 20),
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('Initializes with host player and monotonic seq 1', () {
      expect(engine.players.length, 1);
      final host = engine.players.first;
      expect(host.name, 'Ведущий');
      expect(host.level, 1);
      expect(host.gearPower, 0);
      expect(engine.currentSeq, 1);
      expect(engine.eventLog.length, 1);
    });

    test('Applies valid level change and produces LevelApplied event', () {
      final hostId = engine.hostPlayerId;
      final applied = engine.applyLevelChange(
        targetPlayerId: hostId,
        initiator: const HostInitiated(),
        delta: 1,
        reason: const LevelReason.monsterKill(),
      );

      expect(applied, isTrue);
      expect(engine.getPlayer(hostId)?.level, 2);
      expect(engine.currentSeq, 2);

      final latest = engine.eventLog.latestActiveChange;
      expect(latest, isNotNull);
      expect(latest!.newLevel, 2);
      expect(latest.prevLevel, 1);
      expect(latest.reason.kind, ReasonKind.monsterKill);
    });

    test('Rejects no-op changes at boundaries without adding history events', () {
      final hostId = engine.hostPlayerId;

      // At level 1, trying to decrement
      final rejectedDecrement = engine.applyLevelChange(
        targetPlayerId: hostId,
        initiator: const HostInitiated(),
        delta: -1,
        reason: const LevelReason.other('Спад'),
      );

      expect(rejectedDecrement, isFalse);
      expect(engine.getPlayer(hostId)?.level, 1);
      expect(engine.currentSeq, 1); // seq didn't increase
      expect(engine.eventLog.length, 1); // no event was recorded

      // Move to max level
      engine.applyLevelChange(
        targetPlayerId: hostId,
        initiator: const HostInitiated(),
        setValue: 20,
        reason: const LevelReason.other('Максимум'),
      );
      expect(engine.getPlayer(hostId)?.level, 20);

      // Now at 20, +1 should be rejected as no-op
      final rejectedIncrement = engine.applyLevelChange(
        targetPlayerId: hostId,
        initiator: const HostInitiated(),
        delta: 1,
        reason: const LevelReason.monsterKill(),
      );
      expect(rejectedIncrement, isFalse);
      expect(engine.getPlayer(hostId)?.level, 20);
    });

    test('Clamps setValue beyond maxLevel', () {
      final hostId = engine.hostPlayerId;
      engine.applyLevelChange(
        targetPlayerId: hostId,
        initiator: const HostInitiated(),
        setValue: 50,
        reason: const LevelReason.other('Чит'),
      );

      expect(engine.getPlayer(hostId)?.level, 20);
    });

    test('Undo reverts the most recent active change and restores prevLevel', () {
      final hostId = engine.hostPlayerId;

      // 1 -> 2
      engine.applyLevelChange(
        targetPlayerId: hostId,
        initiator: const HostInitiated(),
        delta: 1,
        reason: const LevelReason.monsterKill(),
      );
      // 2 -> 4
      engine.applyLevelChange(
        targetPlayerId: hostId,
        initiator: const HostInitiated(),
        delta: 2,
        reason: const LevelReason.sell(),
      );

      expect(engine.getPlayer(hostId)?.level, 4);

      // Undo the +2 change -> should revert to 2
      final undone = engine.undoLastLevelChange();
      expect(undone, isTrue);
      expect(engine.getPlayer(hostId)?.level, 2);

      // Now latest active change should be the first (+1)
      final latest = engine.eventLog.latestActiveChange;
      expect(latest, isNotNull);
      expect(latest!.newLevel, 2);
      expect(latest.prevLevel, 1);

      // Undo again -> reverts the first change back to 1
      final undoneFirst = engine.undoLastLevelChange();
      expect(undoneFirst, isTrue);
      expect(engine.getPlayer(hostId)?.level, 1);

      // Now undo stack is empty
      expect(engine.eventLog.undoCandidate, isNull);
      final undoneEmpty = engine.undoLastLevelChange();
      expect(undoneEmpty, isFalse);
    });

    test('Gear power updates without affecting level', () {
      final hostId = engine.hostPlayerId;
      engine.updateGearPower(hostId, 15);

      final host = engine.getPlayer(hostId)!;
      expect(host.gearPower, 15);
      expect(host.level, 1);
      expect(host.totalPower, 16);
    });

    test('History entries correctly represent applied and undone states', () {
      final hostId = engine.hostPlayerId;

      engine.applyLevelChange(
        targetPlayerId: hostId,
        initiator: const HostInitiated(),
        delta: 1,
        reason: const LevelReason.monsterKill(),
      );
      engine.applyLevelChange(
        targetPlayerId: hostId,
        initiator: const HostInitiated(),
        delta: 2,
        reason: const LevelReason.sell(),
      );
      engine.undoLastLevelChange();

      final history = engine.eventLog.getHistory();
      expect(history.length, 2);

      // Newest first:
      expect(history[0].delta, 2);
      expect(history[0].isUndone, isTrue);
      expect(history[0].undoneEvent, isNotNull);

      expect(history[1].delta, 1);
      expect(history[1].isUndone, isFalse);
    });
  });
}
