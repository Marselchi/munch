import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';
import '../common/event_log.dart';
import '../node/host_role.dart';
import '../node/session_node.dart';
import '../protocol/messages.dart';
import '../protocol/models.dart';
import 'connection_registry.dart';

export '../node/host_role.dart' show PendingLevelRequest, JoinApprovalRequest;

/// Authoritative Host Game Session Engine.
/// Pure Dart (no Flutter imports).
/// Backed by a unified SessionNode and attached HostRole.
class HostSessionEngine {
  final String hostPlayerName;
  final String sessionName;
  late final SessionNode node;
  late final HostRole hostRole;

  void Function(SessionSnapshot snapshot)? onSnapshotChanged;
  void Function()? onStateUpdated;

  HostSessionEngine({
    required this.hostPlayerName,
    this.sessionName = 'Манчкин За Столом',
    SessionSettings settings = const SessionSettings(),
    SessionSnapshot? resumeFromSnapshot,
  }) {
    hostRole = HostRole();

    if (resumeFromSnapshot != null) {
      _resumeFrom(resumeFromSnapshot);
    } else {
      _createNew(settings);
    }

    node.onSnapshotChanged = (snap) => onSnapshotChanged?.call(snap);
    node.onStateUpdated = () => onStateUpdated?.call();
  }

  HostSessionEngine.fromNode(this.node, this.hostRole)
      : hostPlayerName = node.getPlayer(node.hostPlayerId)?.name ?? 'Ведущий',
        sessionName = node.sessionName {
    node.onSnapshotChanged = (snap) => onSnapshotChanged?.call(snap);
    node.onStateUpdated = () => onStateUpdated?.call();
  }

  void _createNew(SessionSettings settings) {
    final uuid = const Uuid();
    final sid = uuid.v4();
    final hPlayerId = uuid.v4();
    final hostToken = uuid.v4().replaceAll('-', '');

    final hostPlayer = Player(
      id: hPlayerId,
      name: hostPlayerName.trim().isEmpty ? 'Ведущий' : hostPlayerName.trim(),
      level: 1,
      gearPower: 0,
      ownerId: hPlayerId,
    );

    final joinEvent = PlayerJoined(
      seq: 1,
      eventId: uuid.v4(),
      ts: DateTime.now(),
      player: hostPlayer,
    );

    final hostSeat = Seat(playerId: hPlayerId, token: hostToken);

    final initialSnapshot = SessionSnapshot(
      sessionId: sid,
      name: sessionName,
      protocolVersion: AppConstants.protocolVersion,
      hostPlayerId: hPlayerId,
      settings: settings,
      seq: 1,
      players: [hostPlayer],
      events: [joinEvent],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      epoch: 0,
      seats: [hostSeat],
      roster: const [],
    );

    node = SessionNode(
      initialSnapshot: initialSnapshot,
      initialHostRole: hostRole,
    );
  }

  void _resumeFrom(SessionSnapshot snapshot) {
    node = SessionNode(
      initialSnapshot: snapshot,
      initialHostRole: hostRole,
    );
  }

  // --- Delegation Getters ---
  ConnectionRegistry get registry => hostRole.registry;
  EventLog get eventLog => node.eventLog;
  String get sessionId => node.sessionId;
  String get hostPlayerId => node.hostPlayerId;
  int get currentSeq => node.currentSeq;
  SessionSettings get settings => node.settings;
  List<Player> get players => node.players;
  Player? getPlayer(String id) => node.getPlayer(id);
  SessionSnapshot get snapshot => node.snapshot;

  bool get requireJoinApproval => hostRole.requireJoinApproval;
  set requireJoinApproval(bool value) => hostRole.requireJoinApproval = value;

  List<PendingLevelRequest> get pendingRequests => hostRole.pendingRequests;
  List<JoinApprovalRequest> get pendingJoinApprovals =>
      hostRole.pendingJoinApprovals;

  // --- Operations ---
  bool applyLevelChange({
    required String targetPlayerId,
    required Initiator initiator,
    int? delta,
    int? setValue,
    required LevelReason reason,
  }) {
    return hostRole.applyLevelChange(
      targetPlayerId: targetPlayerId,
      initiator: initiator,
      delta: delta,
      setValue: setValue,
      reason: reason,
    );
  }

  bool undoLastLevelChange() => hostRole.undoLastLevelChange();

  void updateGearPower(String playerId, int newGearPower) {
    hostRole.updateGearPower(playerId, newGearPower);
  }

  void updateTraits(String playerId, List<String> traitIds) {
    hostRole.updateTraits(playerId, traitIds);
  }

  void updateMaxLevel(int newMaxLevel) {
    hostRole.updateMaxLevel(newMaxLevel);
  }

  void handleLevelRequest(String playerId, LevelRequest request) {
    hostRole.handleLevelRequest(playerId, request);
  }

  void approveRequest(String reqId) => hostRole.approveRequest(reqId);
  void denyRequest(String reqId, [String? message]) =>
      hostRole.denyRequest(reqId, message);

  void handleIncomingConnection(WebSocketChannel channel) {
    hostRole.handleIncomingConnection(channel);
  }

  void approveJoinRequest(String reqId) => hostRole.approveJoinRequest(reqId);
  void denyJoinRequest(String reqId) => hostRole.denyJoinRequest(reqId);

  void updateHostNetworkInfo(List<String> ips, int port) {
    hostRole.updateHostNetworkInfo(ips, port);
  }

  void nominateDeputy(String playerId) {
    hostRole.nominateDeputy(playerId);
  }

  void transferHost(String targetPlayerId) {
    hostRole.transferHost(targetPlayerId);
  }

  void Function(HostChanged event)? get onHostDemoted => hostRole.onHostDemoted;
  set onHostDemoted(void Function(HostChanged event)? callback) =>
      hostRole.onHostDemoted = callback;

  Player addLocalPlayer(String rawName) => hostRole.addLocalPlayer(rawName);
  void removePlayer(String playerId, {String reason = 'removed'}) {
    hostRole.removePlayer(playerId, reason: reason);
  }

  void endSession({String reason = 'Ведущий завершил игру.'}) {
    hostRole.endSession(reason: reason);
  }

  void dispose() {
    node.dispose();
  }
}
