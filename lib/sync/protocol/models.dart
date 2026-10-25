/// Pure Dart models for Munchkin game state and synchronization.
/// No Flutter dependencies.
library;

sealed class Initiator {
  const Initiator();

  Map<String, dynamic> toJson();

  static Initiator fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == 'player') {
      return PlayerRequested(json['playerId'] as String);
    }
    return const HostInitiated();
  }
}

final class HostInitiated extends Initiator {
  const HostInitiated();

  @override
  Map<String, dynamic> toJson() => {'type': 'host'};

  @override
  bool operator ==(Object other) => other is HostInitiated;

  @override
  int get hashCode => 0;
}

final class PlayerRequested extends Initiator {
  final String playerId;

  const PlayerRequested(this.playerId);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'player',
        'playerId': playerId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerRequested &&
          runtimeType == other.runtimeType &&
          playerId == other.playerId;

  @override
  int get hashCode => playerId.hashCode;
}

enum ReasonKind {
  sell,
  monsterKill,
  other;

  static ReasonKind fromString(String val) {
    return switch (val) {
      'sell' => ReasonKind.sell,
      'monsterKill' => ReasonKind.monsterKill,
      _ => ReasonKind.other,
    };
  }
}

class LevelReason {
  final ReasonKind kind;
  final String? customText;

  const LevelReason({
    required this.kind,
    this.customText,
  });

  const LevelReason.sell() : this(kind: ReasonKind.sell);
  const LevelReason.monsterKill() : this(kind: ReasonKind.monsterKill);
  const LevelReason.other(String text) : this(kind: ReasonKind.other, customText: text);

  String get localizedTitle {
    return switch (kind) {
      ReasonKind.sell => 'Продажа шмоток',
      ReasonKind.monsterKill => 'Убийство монстра',
      ReasonKind.other => (customText != null && customText!.isNotEmpty)
          ? customText!
          : 'Другое',
    };
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        if (customText != null) 'customText': customText,
      };

  factory LevelReason.fromJson(Map<String, dynamic> json) {
    return LevelReason(
      kind: ReasonKind.fromString(json['kind'] as String? ?? 'other'),
      customText: json['customText'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LevelReason &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          customText == other.customText;

  @override
  int get hashCode => Object.hash(kind, customText);
}

class Player {
  final String id;
  final String name;
  final int level;
  final int gearPower;
  final List<String> traitIds;
  final List<String> customTraits;

  const Player({
    required this.id,
    required this.name,
    this.level = 1,
    this.gearPower = 0,
    this.traitIds = const [],
    this.customTraits = const [],
  });

  int get totalPower => level + gearPower;

  Player copyWith({
    String? id,
    String? name,
    int? level,
    int? gearPower,
    List<String>? traitIds,
    List<String>? customTraits,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      gearPower: gearPower ?? this.gearPower,
      traitIds: traitIds ?? this.traitIds,
      customTraits: customTraits ?? this.customTraits,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'level': level,
        'gearPower': gearPower,
        'traitIds': traitIds,
        'customTraits': customTraits,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      level: json['level'] as int? ?? 1,
      gearPower: json['gearPower'] as int? ?? 0,
      traitIds: (json['traitIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      customTraits: (json['customTraits'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          level == other.level &&
          gearPower == other.gearPower;

  @override
  int get hashCode => Object.hash(id, name, level, gearPower);
}

class SessionSettings {
  final int maxLevel;

  const SessionSettings({this.maxLevel = 20});

  SessionSettings copyWith({int? maxLevel}) {
    return SessionSettings(maxLevel: maxLevel ?? this.maxLevel);
  }

  Map<String, dynamic> toJson() => {'maxLevel': maxLevel};

  factory SessionSettings.fromJson(Map<String, dynamic> json) {
    return SessionSettings(
      maxLevel: json['maxLevel'] as int? ?? 20,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionSettings && maxLevel == other.maxLevel;

  @override
  int get hashCode => maxLevel.hashCode;
}

sealed class SyncEvent {
  final int seq;
  final String eventId;
  final DateTime ts;

  const SyncEvent({
    required this.seq,
    required this.eventId,
    required this.ts,
  });

  Map<String, dynamic> toJson();

  static SyncEvent fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final seq = json['seq'] as int;
    final eventId = json['eventId'] as String;
    final ts = DateTime.fromMillisecondsSinceEpoch(json['ts'] as int);

    return switch (type) {
      'LevelApplied' => LevelApplied(
          seq: seq,
          eventId: eventId,
          ts: ts,
          targetPlayerId: json['targetPlayerId'] as String,
          initiator: Initiator.fromJson(json['initiator'] as Map<String, dynamic>),
          delta: json['delta'] as int?,
          setValue: json['setValue'] as int?,
          prevLevel: json['prevLevel'] as int,
          newLevel: json['newLevel'] as int,
          reason: LevelReason.fromJson(json['reason'] as Map<String, dynamic>),
        ),
      'LevelUndone' => LevelUndone(
          seq: seq,
          eventId: eventId,
          ts: ts,
          targetChangeId: json['targetChangeId'] as String,
          restoredLevel: json['restoredLevel'] as int,
        ),
      'PlayerJoined' => PlayerJoined(
          seq: seq,
          eventId: eventId,
          ts: ts,
          player: Player.fromJson(json['player'] as Map<String, dynamic>),
        ),
      'PlayerLeft' => PlayerLeft(
          seq: seq,
          eventId: eventId,
          ts: ts,
          playerId: json['playerId'] as String,
          reason: json['reason'] as String? ?? 'left',
        ),
      'PlayerUpdated' => PlayerUpdated(
          seq: seq,
          eventId: eventId,
          ts: ts,
          playerId: json['playerId'] as String,
          gearPower: json['gearPower'] as int?,
          traitIds: (json['traitIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
          name: json['name'] as String?,
        ),
      'SessionUpdated' => SessionUpdated(
          seq: seq,
          eventId: eventId,
          ts: ts,
          name: json['name'] as String?,
          settings: json['settings'] != null
              ? SessionSettings.fromJson(json['settings'] as Map<String, dynamic>)
              : null,
        ),
      'SessionEnded' => SessionEnded(
          seq: seq,
          eventId: eventId,
          ts: ts,
          reason: json['reason'] as String? ?? 'ended',
        ),
      _ => throw FormatException('Unknown SyncEvent type: $type'),
    };
  }
}

final class LevelApplied extends SyncEvent {
  final String targetPlayerId;
  final Initiator initiator;
  final int? delta;
  final int? setValue;
  final int prevLevel;
  final int newLevel;
  final LevelReason reason;

  const LevelApplied({
    required super.seq,
    required super.eventId,
    required super.ts,
    required this.targetPlayerId,
    required this.initiator,
    this.delta,
    this.setValue,
    required this.prevLevel,
    required this.newLevel,
    required this.reason,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'LevelApplied',
        'seq': seq,
        'eventId': eventId,
        'ts': ts.millisecondsSinceEpoch,
        'targetPlayerId': targetPlayerId,
        'initiator': initiator.toJson(),
        if (delta != null) 'delta': delta,
        if (setValue != null) 'setValue': setValue,
        'prevLevel': prevLevel,
        'newLevel': newLevel,
        'reason': reason.toJson(),
      };
}

final class LevelUndone extends SyncEvent {
  final String targetChangeId;
  final int restoredLevel;

  const LevelUndone({
    required super.seq,
    required super.eventId,
    required super.ts,
    required this.targetChangeId,
    required this.restoredLevel,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'LevelUndone',
        'seq': seq,
        'eventId': eventId,
        'ts': ts.millisecondsSinceEpoch,
        'targetChangeId': targetChangeId,
        'restoredLevel': restoredLevel,
      };
}

final class PlayerJoined extends SyncEvent {
  final Player player;

  const PlayerJoined({
    required super.seq,
    required super.eventId,
    required super.ts,
    required this.player,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PlayerJoined',
        'seq': seq,
        'eventId': eventId,
        'ts': ts.millisecondsSinceEpoch,
        'player': player.toJson(),
      };
}

final class PlayerLeft extends SyncEvent {
  final String playerId;
  final String reason;

  const PlayerLeft({
    required super.seq,
    required super.eventId,
    required super.ts,
    required this.playerId,
    required this.reason,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PlayerLeft',
        'seq': seq,
        'eventId': eventId,
        'ts': ts.millisecondsSinceEpoch,
        'playerId': playerId,
        'reason': reason,
      };
}

final class PlayerUpdated extends SyncEvent {
  final String playerId;
  final int? gearPower;
  final List<String>? traitIds;
  final String? name;

  const PlayerUpdated({
    required super.seq,
    required super.eventId,
    required super.ts,
    required this.playerId,
    this.gearPower,
    this.traitIds,
    this.name,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PlayerUpdated',
        'seq': seq,
        'eventId': eventId,
        'ts': ts.millisecondsSinceEpoch,
        'playerId': playerId,
        if (gearPower != null) 'gearPower': gearPower,
        if (traitIds != null) 'traitIds': traitIds,
        if (name != null) 'name': name,
      };
}

final class SessionUpdated extends SyncEvent {
  final String? name;
  final SessionSettings? settings;

  const SessionUpdated({
    required super.seq,
    required super.eventId,
    required super.ts,
    this.name,
    this.settings,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SessionUpdated',
        'seq': seq,
        'eventId': eventId,
        'ts': ts.millisecondsSinceEpoch,
        if (name != null) 'name': name,
        if (settings != null) 'settings': settings!.toJson(),
      };
}

final class SessionEnded extends SyncEvent {
  final String reason;

  const SessionEnded({
    required super.seq,
    required super.eventId,
    required super.ts,
    required this.reason,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SessionEnded',
        'seq': seq,
        'eventId': eventId,
        'ts': ts.millisecondsSinceEpoch,
        'reason': reason,
      };
}

class SessionSnapshot {
  final String sessionId;
  final String name;
  final int protocolVersion;
  final String hostPlayerId;
  final SessionSettings settings;
  final int seq;
  final List<Player> players;
  final List<SyncEvent> events;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SessionSnapshot({
    required this.sessionId,
    required this.name,
    required this.protocolVersion,
    required this.hostPlayerId,
    required this.settings,
    required this.seq,
    required this.players,
    required this.events,
    required this.createdAt,
    required this.updatedAt,
  });

  SessionSnapshot copyWith({
    String? sessionId,
    String? name,
    int? protocolVersion,
    String? hostPlayerId,
    SessionSettings? settings,
    int? seq,
    List<Player>? players,
    List<SyncEvent>? events,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionSnapshot(
      sessionId: sessionId ?? this.sessionId,
      name: name ?? this.name,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      hostPlayerId: hostPlayerId ?? this.hostPlayerId,
      settings: settings ?? this.settings,
      seq: seq ?? this.seq,
      players: players ?? this.players,
      events: events ?? this.events,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'name': name,
        'protocolVersion': protocolVersion,
        'hostPlayerId': hostPlayerId,
        'settings': settings.toJson(),
        'seq': seq,
        'players': players.map((p) => p.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory SessionSnapshot.fromJson(Map<String, dynamic> json) {
    return SessionSnapshot(
      sessionId: json['sessionId'] as String,
      name: json['name'] as String,
      protocolVersion: json['protocolVersion'] as int? ?? 1,
      hostPlayerId: json['hostPlayerId'] as String,
      settings: SessionSettings.fromJson(json['settings'] as Map<String, dynamic>),
      seq: json['seq'] as int,
      players: (json['players'] as List<dynamic>)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      events: (json['events'] as List<dynamic>)
          .map((e) => SyncEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
    );
  }
}

class QrPayload {
  final String marker;
  final int version;
  final String sessionId;
  final String sessionName;
  final List<String> hostIps;
  final int port;
  final String? token;

  const QrPayload({
    required this.marker,
    required this.version,
    required this.sessionId,
    required this.sessionName,
    required this.hostIps,
    required this.port,
    this.token,
  });

  Map<String, dynamic> toJson() => {
        'a': marker,
        'v': version,
        'sid': sessionId,
        'n': sessionName,
        'ips': hostIps,
        'p': port,
        if (token != null) 't': token,
      };

  factory QrPayload.fromJson(Map<String, dynamic> json) {
    return QrPayload(
      marker: json['a'] as String? ?? '',
      version: json['v'] as int? ?? 1,
      sessionId: json['sid'] as String? ?? '',
      sessionName: json['n'] as String? ?? '',
      hostIps: (json['ips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      port: json['p'] as int? ?? 8787,
      token: json['t'] as String?,
    );
  }
}
