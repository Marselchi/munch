import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:munchkin_companion/core/constants/app_constants.dart';
import 'package:munchkin_companion/core/theme/app_colors.dart';
import 'package:munchkin_companion/core/widgets/latest_change_banner.dart';
import 'package:munchkin_companion/core/widgets/status_chip.dart';
import 'package:munchkin_companion/core/widgets/traits_picker_sheet.dart';
import 'package:munchkin_companion/features/level_history/presentation/history_screen.dart';
import 'package:munchkin_companion/features/player_session/application/player_session_controller.dart';
import 'package:munchkin_companion/features/rules/application/rules_controller.dart';
import 'package:munchkin_companion/features/rules/presentation/rules_search_screen.dart';
import 'package:munchkin_companion/sync/common/connection_status.dart';
import 'package:munchkin_companion/sync/protocol/models.dart';
import 'widgets/level_request_sheet.dart';
import 'widgets/player_power_card.dart';

class PlayerGameScreen extends ConsumerStatefulWidget {
  const PlayerGameScreen({super.key});

  @override
  ConsumerState<PlayerGameScreen> createState() => _PlayerGameScreenState();
}

class _PlayerGameScreenState extends ConsumerState<PlayerGameScreen>
    with WidgetsBindingObserver {
  String? _activeReqId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Immediate reconnect on app foreground (crucial for iOS background socket drops)
      ref.read(clientSessionProvider.notifier).retryReconnect();
    }
  }

  void _openHistory() {
    final entries = ref.read(clientHistoryEntriesProvider);
    final engine = ref.read(clientSessionProvider)?.engine;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          entries: entries,
          getPlayerName: (id) =>
              engine?.snapshot?.players.firstWhere((p) => p.id == id, orElse: () => Player(id: id, name: 'Игрок')).name ??
              'Игрок',
        ),
      ),
    );
  }

  void _showQrCodeDialog() {
    final clientState = ref.read(clientSessionProvider);
    final engine = clientState?.engine;
    if (engine == null || engine.snapshot == null) return;

    final snap = engine.snapshot!;
    final qrPayload = QrPayload(
      marker: AppConstants.appMarker,
      version: snap.protocolVersion,
      sessionId: snap.sessionId,
      sessionName: snap.name,
      hostIps: engine.hostIps,
      port: engine.port,
    );
    final qrString = jsonEncode(qrPayload.toJson());

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E2127),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkCardBorder),
        ),
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Подключение к столу',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: qrString,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Порт: ${engine.port} • IP: ${engine.hostIps.join(", ")}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Скопировать код стола'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: qrString));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Код стола скопирован в буфер обмена')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTraitsPicker(Player selfPlayer) {
    final allEntities = ref.read(allRuleEntitiesProvider);

    TraitsPickerSheet.show(
      context: context,
      playerName: selfPlayer.name,
      allEntities: allEntities,
      initialSelected: selfPlayer.traitIds,
      onSave: (newTraits) {
        ref.read(clientSessionProvider.notifier).updateSelfTraits(newTraits);
      },
    );
  }

  Future<void> _leaveTable() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Покинуть стол?'),
        content: const Text('Вы отключитесь от текущей игровой сессии.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCrimson,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Покинуть'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ref.read(clientSessionProvider.notifier).leaveSession();
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientState = ref.watch(clientSessionProvider);
    if (clientState == null) {
      return const Scaffold(
        body: Center(child: Text('Подключение закрыто.')),
      );
    }

    final connectionStatus = ref.watch(clientConnectionStatusProvider);
    final selfPlayer = ref.watch(clientSelfPlayerProvider);
    final playerIds = ref.watch(clientPlayerIdsProvider);
    final latestChange = ref.watch(clientLatestChangeProvider);
    final engine = clientState.engine;
    final maxLevel = engine.snapshot?.settings.maxLevel ?? AppConstants.defaultMaxLevel;

    // Convert connection enum to chip status
    final chipStatus = switch (connectionStatus) {
      SyncConnectionStatus.connected => ConnectionStateStatus.connected,
      SyncConnectionStatus.reconnecting => ConnectionStateStatus.reconnecting,
      SyncConnectionStatus.disconnected => ConnectionStateStatus.disconnected,
    };

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: PopupMenuButton<String>(
        tooltip: 'Меню управления',
        offset: const Offset(0, -250),
        color: const Color(0xFF1E2127),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkCardBorder),
        ),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF262932),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF434856), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.more_horiz,
            size: 26,
            color: AppColors.textPrimary,
          ),
        ),
        onSelected: (val) {
          switch (val) {
            case 'qr':
              _showQrCodeDialog();
              break;
            case 'rules':
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RulesSearchScreen()),
              );
              break;
            case 'history':
              _openHistory();
              break;
            case 'leave':
              _leaveTable();
              break;
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(
            value: 'qr',
            child: Row(
              children: [
                Icon(Icons.qr_code, size: 18, color: AppColors.textPrimary),
                SizedBox(width: 12),
                Text('QR-код / Код стола', style: TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'rules',
            child: Row(
              children: [
                Icon(Icons.menu_book, size: 18, color: AppColors.textPrimary),
                SizedBox(width: 12),
                Text('Справочник правил', style: TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'history',
            child: Row(
              children: [
                Icon(Icons.history, size: 18, color: AppColors.textPrimary),
                SizedBox(width: 12),
                Text('История изменений', style: TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'leave',
            child: Row(
              children: [
                Icon(Icons.exit_to_app, size: 18, color: AppColors.accentCrimson),
                SizedBox(width: 12),
                Text('Покинуть стол', style: TextStyle(color: AppColors.accentCrimson)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  StatusChip(
                    status: chipStatus,
                    onTap: () {
                      if (connectionStatus != SyncConnectionStatus.connected) {
                        ref.read(clientSessionProvider.notifier).retryReconnect();
                      }
                    },
                  ),
                ],
              ),
            ),
          // Reconnection banner if reconnecting
          if (connectionStatus == SyncConnectionStatus.reconnecting) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: AppColors.secondaryAmber.withOpacity(0.2),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.secondaryAmber,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Связь потеряна. Автоматическое переподключение…',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryAmber,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Latest Change Banner
          LatestChangeBanner(
            latestChange: latestChange,
            targetPlayerName: latestChange != null
                ? engine.snapshot?.players
                    .firstWhere((p) => p.id == latestChange.targetPlayerId,
                        orElse: () => Player(id: '', name: 'Игрок'))
                    .name
                : null,
            onTap: _openHistory,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: [
                // Own Dominating Power Card
                if (selfPlayer != null) ...[
                  PlayerPowerCard(
                    player: selfPlayer,
                    maxLevel: maxLevel,
                    isPendingRequest: _activeReqId != null &&
                        engine.isRequestPending(_activeReqId!),
                    onGearChanged: (newGear) {
                      ref
                          .read(clientSessionProvider.notifier)
                          .updateSelfGearPower(newGear);
                    },
                    onRequestLevel: () {
                      LevelRequestSheet.show(
                        context: context,
                        player: selfPlayer,
                        maxLevel: maxLevel,
                        onConfirm: ({delta, setValue, required reason}) {
                          try {
                            final reqId = ref
                                .read(clientSessionProvider.notifier)
                                .requestLevelChange(
                                  delta: delta,
                                  setValue: setValue,
                                  reason: reason,
                                );
                            setState(() => _activeReqId = reqId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Запрос отправлен ведущему стола.'),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppColors.accentCrimson,
                              ),
                            );
                          }
                        },
                      );
                    },
                    onEditTraits: () => _showTraitsPicker(selfPlayer),
                  ),
                ],
                const SizedBox(height: 16),
                // Other Players Section
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'Другие игроки за столом',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ...playerIds
                    .where((id) => id != selfPlayer?.id)
                    .map((otherId) {
                  final other = ref.watch(clientPlayerProvider(otherId));
                  if (other == null) return const SizedBox.shrink();

                  return Card(
                    color: AppColors.darkCard,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.darkSurface,
                            child: Text(
                              other.name.isNotEmpty
                                  ? other.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  other.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (other.traitIds.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    other.traitIds.join(', '),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Ур. ${other.level} (+${other.gearPower})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                'Сила: ${other.totalPower}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
