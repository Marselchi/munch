import '../common/event_log.dart';
import '../protocol/models.dart';
import 'host_role.dart';
import 'session_reducer.dart';

/// Single unified state container keeping the authoritative or replica session state.
/// Runs on every participant device (client, host, or migrating node).
/// Pure Dart (no Flutter imports).
class SessionNode {
  SessionSnapshot _snapshot;
  final EventLog eventLog;
  HostRole? _hostRole;

  void Function(SessionSnapshot snapshot)? onSnapshotChanged;
  void Function()? onStateUpdated;

  SessionNode({
    required SessionSnapshot initialSnapshot,
    HostRole? initialHostRole,
  })  : _snapshot = initialSnapshot,
        eventLog = EventLog(initialSnapshot.events),
        _hostRole = initialHostRole {
    _hostRole?.attach(this);
  }

  SessionSnapshot get snapshot => _snapshot;
  bool get isHost => _hostRole != null;
  HostRole? get hostRole => _hostRole;

  // Snapshot property shortcuts
  int get currentSeq => _snapshot.seq;
  int get epoch => _snapshot.epoch;
  String get sessionId => _snapshot.sessionId;
  String get sessionName => _snapshot.name;
  String get hostPlayerId => _snapshot.hostPlayerId;
  SessionSettings get settings => _snapshot.settings;
  List<Player> get players => _snapshot.players;
  List<Seat> get seats => _snapshot.seats;
  List<RosterEntry> get roster => _snapshot.roster;

  Player? getPlayer(String id) {
    for (final p in _snapshot.players) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Pure deterministic state transition: applies [event] via [SessionReducer],
  /// appends to event log, and notifies observers.
  void apply(SyncEvent event) {
    _snapshot = SessionReducer.reduce(_snapshot, event);
    eventLog.append(event);
    onSnapshotChanged?.call(_snapshot);
    onStateUpdated?.call();
  }

  /// Replaces the snapshot state completely (e.g. upon join acceptance or full resync).
  void resetSnapshot(SessionSnapshot newSnapshot) {
    _snapshot = newSnapshot;
    eventLog.clear();
    for (final ev in newSnapshot.events) {
      eventLog.append(ev);
    }
    onSnapshotChanged?.call(_snapshot);
    onStateUpdated?.call();
  }

  /// Updates the seat table directly.
  void updateSeats(List<Seat> newSeats) {
    _snapshot = _snapshot.copyWith(
      seats: newSeats,
      updatedAt: DateTime.now(),
    );
    onSnapshotChanged?.call(_snapshot);
    onStateUpdated?.call();
  }

  /// Updates the roster table directly.
  void updateRoster(List<RosterEntry> newRoster) {
    _snapshot = _snapshot.copyWith(
      roster: newRoster,
      updatedAt: DateTime.now(),
    );
    onSnapshotChanged?.call(_snapshot);
    onStateUpdated?.call();
  }

  /// Attaches a host role to this node (e.g. initial hosting or promotion after migration).
  void attachHostRole(HostRole role) {
    _hostRole?.detach();
    _hostRole = role;
    role.attach(this);
    onStateUpdated?.call();
  }

  /// Detaches the host role from this node (e.g. demotion during handoff).
  void detachHostRole() {
    _hostRole?.detach();
    _hostRole = null;
    onStateUpdated?.call();
  }

  void dispose() {
    _hostRole?.dispose();
    _hostRole = null;
  }
}
