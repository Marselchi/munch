import '../protocol/models.dart';

/// Presentation-ready level history entry computed from the event log.
class HistoryEntry {
  final LevelApplied appliedEvent;
  final bool isUndone;
  final LevelUndone? undoneEvent;

  const HistoryEntry({
    required this.appliedEvent,
    this.isUndone = false,
    this.undoneEvent,
  });

  String get eventId => appliedEvent.eventId;
  String get targetPlayerId => appliedEvent.targetPlayerId;
  Initiator get initiator => appliedEvent.initiator;
  int? get delta => appliedEvent.delta;
  int? get setValue => appliedEvent.setValue;
  int get prevLevel => appliedEvent.prevLevel;
  int get newLevel => appliedEvent.newLevel;
  LevelReason get reason => appliedEvent.reason;
  DateTime get timestamp => appliedEvent.ts;
}

/// Append-only ordered event log with monotonic sequence numbers.
/// Pure Dart (no Flutter imports).
class EventLog {
  final List<SyncEvent> _events = [];

  EventLog([List<SyncEvent>? initialEvents]) {
    if (initialEvents != null) {
      _events.addAll(initialEvents);
      _events.sort((a, b) => a.seq.compareTo(b.seq));
    }
  }

  List<SyncEvent> get events => List.unmodifiable(_events);

  int get lastSeq => _events.isEmpty ? 0 : _events.last.seq;

  int get length => _events.length;

  /// Appends an event to the log. Ensures sequence ordering.
  void append(SyncEvent event) {
    if (_events.isNotEmpty && event.seq <= _events.last.seq) {
      // Ignore duplicates or strictly out of order events if already applied
      if (_events.any((e) => e.seq == event.seq || e.eventId == event.eventId)) {
        return;
      }
    }
    _events.add(event);
  }

  /// Returns events with sequence number strictly greater than [sinceSeq].
  List<SyncEvent> eventsAfter(int sinceSeq) {
    return _events.where((e) => e.seq > sinceSeq).toList(growable: false);
  }

  /// History entries in reverse-chronological order (newest first).
  List<HistoryEntry> getHistory() {
    final undoneMap = <String, LevelUndone>{};
    for (final event in _events) {
      if (event is LevelUndone) {
        undoneMap[event.targetChangeId] = event;
      }
    }

    final entries = <HistoryEntry>[];
    for (final event in _events) {
      if (event is LevelApplied) {
        final undone = undoneMap[event.eventId];
        entries.add(HistoryEntry(
          appliedEvent: event,
          isUndone: undone != null,
          undoneEvent: undone,
        ));
      }
    }

    // Newest first
    return entries.reversed.toList(growable: false);
  }

  /// The single most recent LevelApplied change that has NOT been undone.
  LevelApplied? get latestActiveChange {
    final undoneIds = <String>{};
    for (final event in _events) {
      if (event is LevelUndone) {
        undoneIds.add(event.targetChangeId);
      }
    }

    for (var i = _events.length - 1; i >= 0; i--) {
      final event = _events[i];
      if (event is LevelApplied && !undoneIds.contains(event.eventId)) {
        return event;
      }
    }
    return null;
  }

  /// Returns the target change for an undo operation (the most recent active change).
  LevelApplied? get undoCandidate => latestActiveChange;

  void clear() {
    _events.clear();
  }
}
