import '../protocol/models.dart';

/// Pure reducer for Munchkin session state.
/// Contains NO side effects, NO networking, and NO Flutter dependencies.
abstract final class SessionReducer {
  /// Applies a [SyncEvent] to the current [SessionSnapshot] and returns
  /// the new immutable [SessionSnapshot].
  static SessionSnapshot reduce(SessionSnapshot state, SyncEvent event) {
    final updatedEvents = [...state.events, event];
    final updatedSeq = event.seq > state.seq ? event.seq : state.seq;
    final now = DateTime.now();

    switch (event) {
      case LevelApplied(:final targetPlayerId, :final newLevel):
        final updatedPlayers = state.players.map((p) {
          return p.id == targetPlayerId ? p.copyWith(level: newLevel) : p;
        }).toList();
        return state.copyWith(
          seq: updatedSeq,
          players: updatedPlayers,
          events: updatedEvents,
          updatedAt: now,
        );

      case LevelUndone(:final targetChangeId, :final restoredLevel):
        final appliedCandidate = state.events
            .whereType<LevelApplied>()
            .where((e) => e.eventId == targetChangeId)
            .firstOrNull;

        if (appliedCandidate != null) {
          final updatedPlayers = state.players.map((p) {
            return p.id == appliedCandidate.targetPlayerId
                ? p.copyWith(level: restoredLevel)
                : p;
          }).toList();
          return state.copyWith(
            seq: updatedSeq,
            players: updatedPlayers,
            events: updatedEvents,
            updatedAt: now,
          );
        }
        return state.copyWith(
          seq: updatedSeq,
          events: updatedEvents,
          updatedAt: now,
        );

      case PlayerJoined(:final player):
        final existingIndex = state.players.indexWhere((p) => p.id == player.id);
        List<Player> updatedPlayers;
        if (existingIndex >= 0) {
          updatedPlayers = List<Player>.of(state.players)..[existingIndex] = player;
        } else {
          updatedPlayers = [...state.players, player];
        }
        return state.copyWith(
          seq: updatedSeq,
          players: updatedPlayers,
          events: updatedEvents,
          updatedAt: now,
        );

      case PlayerLeft(:final playerId):
        final updatedPlayers = state.players.where((p) => p.id != playerId).toList();
        final updatedRoster = state.roster.where((r) => r.playerId != playerId).toList();
        return state.copyWith(
          seq: updatedSeq,
          players: updatedPlayers,
          roster: updatedRoster,
          events: updatedEvents,
          updatedAt: now,
        );

      case PlayerUpdated(
          :final playerId,
          :final gearPower,
          :final traitIds,
          :final name
        ):
        final updatedPlayers = state.players.map((p) {
          if (p.id != playerId) return p;
          return p.copyWith(
            gearPower: gearPower ?? p.gearPower,
            traitIds: traitIds ?? p.traitIds,
            name: name ?? p.name,
          );
        }).toList();
        return state.copyWith(
          seq: updatedSeq,
          players: updatedPlayers,
          events: updatedEvents,
          updatedAt: now,
        );

      case SessionUpdated(:final name, :final settings):
        return state.copyWith(
          seq: updatedSeq,
          name: name ?? state.name,
          settings: settings ?? state.settings,
          events: updatedEvents,
          updatedAt: now,
        );

      case SessionEnded():
        return state.copyWith(
          seq: updatedSeq,
          events: updatedEvents,
          updatedAt: now,
        );

      case HostChanged(
          :final epoch,
          :final newHostPlayerId,
          :final ips,
          :final port
        ):
        return state.copyWith(
          seq: updatedSeq,
          epoch: epoch,
          hostPlayerId: newHostPlayerId,
          lastPort: port,
          events: updatedEvents,
          updatedAt: now,
        );

      case SeatClaimed(:final playerId):
        final updatedPlayers = state.players.map((p) {
          if (p.id == playerId) {
            return p.copyWith(clearOwnerId: true);
          }
          return p;
        }).toList();
        return state.copyWith(
          seq: updatedSeq,
          players: updatedPlayers,
          events: updatedEvents,
          updatedAt: now,
        );
    }
  }
}
