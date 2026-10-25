import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:munchkin_companion/core/theme/app_colors.dart';
import 'package:munchkin_companion/features/host_session/application/host_session_controller.dart';
import 'package:munchkin_companion/features/host_session/presentation/host_game_screen.dart';
import 'package:munchkin_companion/features/host_session/presentation/host_lobby_screen.dart';
import 'package:munchkin_companion/features/player_session/application/player_session_controller.dart';
import 'package:munchkin_companion/features/player_session/presentation/join_screens/manual_entry_screen.dart';
import 'package:munchkin_companion/features/player_session/presentation/join_screens/name_entry_screen.dart';
import 'package:munchkin_companion/features/player_session/presentation/join_screens/qr_scanner_screen.dart';
import 'package:munchkin_companion/features/player_session/presentation/player_game_screen.dart';
import 'package:munchkin_companion/features/rules/presentation/rules_search_screen.dart';
import 'package:munchkin_companion/persistence/session_snapshot_store.dart';
import 'package:munchkin_companion/persistence/settings_store.dart';
import 'package:munchkin_companion/sync/protocol/models.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  SessionSnapshot? _resumableHostSnapshot;
  ReconnectSessionData? _resumablePlayerSession;

  @override
  void initState() {
    super.initState();
    _checkResumableSessions();
  }

  Future<void> _checkResumableSessions() async {
    try {
      final hostSnap = await SessionSnapshotStore.getLatestActiveSnapshot();
      final playerSnap = await SettingsStore.getActiveReconnectSession();

      if (mounted) {
        setState(() {
          _resumableHostSnapshot = hostSnap;
          _resumablePlayerSession = playerSnap;
        });
      }
    } catch (_) {}
  }

  void _startHostFlow() {
    final nameController = TextEditingController(text: 'Ведущий');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Создание стола'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Ваше имя'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final hostName = nameController.text.trim();
              Navigator.of(ctx).pop();

              try {
                await ref.read(hostSessionProvider.notifier).startSession(
                      hostName: hostName.isEmpty ? 'Ведущий' : hostName,
                      sessionName: 'Манчкин',
                    );

                if (mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HostLobbyScreen()),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Не удалось создать стол: $e'),
                      backgroundColor: AppColors.accentCrimson,
                    ),
                  );
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _resumeHostSession(SessionSnapshot snapshot) async {
    try {
      await ref.read(hostSessionProvider.notifier).startSession(
            hostName: snapshot.players
                .firstWhere(
                  (p) => p.id == snapshot.hostPlayerId,
                  orElse: () => const Player(id: '', name: 'Ведущий'),
                )
                .name,
            sessionName: snapshot.name,
            resumeFromSnapshot: snapshot,
          );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HostGameScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка возобновления стола: $e'),
            backgroundColor: AppColors.accentCrimson,
          ),
        );
      }
    }
  }

  void _startJoinFlow() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Подключение к столу',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: const Text('Сканировать QR-код стола'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openQrScanner();
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.keyboard, size: 20),
                label: const Text('Ввести адрес вручную'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openManualEntry();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQrScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          onPayloadReceived: (payload) {
            Navigator.of(context).pop();
            _proceedToNameEntry(payload);
          },
          onManualEntry: () {
            Navigator.of(context).pop();
            _openManualEntry();
          },
        ),
      ),
    );
  }

  void _openManualEntry() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualEntryScreen(
          onComplete: (payload) {
            Navigator.of(context).pop();
            _proceedToNameEntry(payload);
          },
        ),
      ),
    );
  }

  void _proceedToNameEntry(QrPayload payload) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NameEntryScreen(
          onNameSubmitted: (name) async {
            Navigator.of(context).pop();
            _connectToSession(
              playerName: name,
              hostIps: payload.hostIps,
              port: payload.port,
              token: payload.token,
            );
          },
        ),
      ),
    );
  }

  Future<void> _connectToSession({
    required String playerName,
    required List<String> hostIps,
    required int port,
    String? token,
    String? playerId,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(width: 20),
            Text('Подключение к столу…'),
          ],
        ),
      ),
    );

    try {
      await ref.read(clientSessionProvider.notifier).joinSession(
            playerName: playerName,
            hostIps: hostIps,
            port: port,
            token: token,
            playerId: playerId,
          );

      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PlayerGameScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка подключения: $e'),
            backgroundColor: AppColors.accentCrimson,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  // Minimalist Clean Title
                  const Text(
                    'МАНЧКИН',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),

                  // Resumable session card
                  if (_resumableHostSnapshot != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.history, color: AppColors.textSecondary, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Сохраненная сессия стола',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Игроков за столом: ${_resumableHostSnapshot!.players.length}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await SessionSnapshotStore.deleteSnapshot(
                                      _resumableHostSnapshot!.sessionId,
                                    );
                                    setState(() => _resumableHostSnapshot = null);
                                  },
                                  child: const Text('Удалить', style: TextStyle(color: AppColors.accentCrimson)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _resumeHostSession(_resumableHostSnapshot!),
                                  child: const Text('Возобновить'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Resume player session if any
                  if (_resumablePlayerSession != null && _resumableHostSnapshot == null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.wifi, color: AppColors.textSecondary, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Предыдущая сессия игрока',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Персонаж: ${_resumablePlayerSession!.playerName}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await SettingsStore.clearActiveReconnectSession();
                                    setState(() => _resumablePlayerSession = null);
                                  },
                                  child: const Text('Сбросить', style: TextStyle(color: AppColors.textMuted)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    _connectToSession(
                                      playerName: _resumablePlayerSession!.playerName,
                                      hostIps: _resumablePlayerSession!.hostIps,
                                      port: _resumablePlayerSession!.port,
                                      token: _resumablePlayerSession!.token,
                                      playerId: _resumablePlayerSession!.playerId,
                                    );
                                  },
                                  child: const Text('Вернуться'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Actions
                  ElevatedButton.icon(
                    icon: const Icon(Icons.table_restaurant, size: 20),
                    label: const Text('Создать стол'),
                    onPressed: _startHostFlow,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.group_add, size: 20),
                    label: const Text('Подключиться к столу'),
                    onPressed: _startJoinFlow,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.menu_book, size: 20),
                    label: const Text('Справочник правил'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RulesSearchScreen()),
                      );
                    },
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
