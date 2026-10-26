import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:munchkin_companion/core/constants/app_constants.dart';
import 'package:munchkin_companion/core/theme/app_colors.dart';
import 'package:munchkin_companion/core/widgets/latest_change_banner.dart';
import 'package:munchkin_companion/core/widgets/traits_picker_sheet.dart';
import 'package:munchkin_companion/features/host_session/application/host_session_controller.dart';
import 'package:munchkin_companion/features/player_session/application/player_session_controller.dart';
import 'package:munchkin_companion/features/player_session/presentation/player_game_screen.dart';
import 'package:munchkin_companion/sync/common/connection_status.dart';
import 'package:munchkin_companion/features/level_history/presentation/history_screen.dart';
import 'package:munchkin_companion/features/rules/application/rules_controller.dart';
import 'package:munchkin_companion/features/rules/presentation/rules_search_screen.dart';
import 'package:munchkin_companion/sync/protocol/models.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'widgets/host_player_card.dart';
import 'widgets/pending_requests_card.dart';

class HostGameScreen extends ConsumerStatefulWidget {
  const HostGameScreen({super.key});

  @override
  ConsumerState<HostGameScreen> createState() => _HostGameScreenState();
}

class _HostGameScreenState extends ConsumerState<HostGameScreen> {
  @override
  void initState() {
    super.initState();
    try {
      WakelockPlus.enable();
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

  void _showAddPlayerDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить игрока за стол'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Имя игрока',
            hintText: 'Например: Вася',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              Navigator.of(ctx).pop();
              ref.read(hostSessionProvider.notifier).addLocalPlayer(
                    name.isEmpty ? 'Игрок' : name,
                  );
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _openHistory() {
    final entries = ref.read(hostHistoryEntriesProvider);
    final engine = ref.read(hostSessionProvider)?.engine;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          entries: entries,
          getPlayerName: (id) => engine?.getPlayer(id)?.name ?? 'Игрок',
        ),
      ),
    );
  }

  void _confirmTransferHost(String playerId, String playerName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Передать стол?'),
        content: Text(
          'Вы действительно хотите сделать игрока "$playerName" новым ведущим стола? Роль хоста и управление сессией перейдут к нему.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(hostSessionProvider.notifier).transferHost(playerId);
            },
            child: const Text('Передать'),
          ),
        ],
      ),
    );
  }

  void _nominateDeputy(String playerId, String playerName) {
    ref.read(hostSessionProvider.notifier).nominateDeputy(playerId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$playerName назначен заместителем ведущего')),
    );
  }

  void _showTraitsPicker(String playerId) {
    final allEntities = ref.read(allRuleEntitiesProvider);
    final engine = ref.read(hostSessionProvider)?.engine;
    final player = engine?.getPlayer(playerId);
    if (player == null) return;

    TraitsPickerSheet.show(
      context: context,
      playerName: player.name,
      allEntities: allEntities,
      initialSelected: player.traitIds,
      onSave: (newTraits) {
        ref.read(hostSessionProvider.notifier).updateTraits(playerId, newTraits);
      },
    );
  }

  void _showQrCodeDialog() {
    final hostState = ref.read(hostSessionProvider);
    if (hostState == null) return;
    final ips = ref.read(hostIpsProvider);
    final port = ref.read(hostPortProvider);
    final engine = hostState.engine;

    final qrPayload = QrPayload(
      marker: AppConstants.appMarker,
      version: AppConstants.protocolVersion,
      sessionId: engine.sessionId,
      sessionName: engine.sessionName,
      hostIps: ips,
      port: port,
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
                  'Порт: $port • IP: ${ips.join(", ")}',
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

  Future<void> _confirmEndSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Завершить игру?'),
        content: const Text(
          'Игра будет завершена для всех участников. Сохранение будет удалено.',
        ),
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
            child: const Text('Завершить'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(hostSessionProvider.notifier).endSession();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ClientSessionState?>(clientSessionProvider, (prev, next) {
      if (next?.connectionStatus == SyncConnectionStatus.connected && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/table'),
            builder: (_) => const PlayerGameScreen(),
          ),
        );
      }
    });

    final hostState = ref.watch(hostSessionProvider);
    if (hostState == null) {
      return const Scaffold(
        body: Center(child: Text('Сессия завершена.')),
      );
    }

    final engine = hostState.engine;
    final playerIds = ref.watch(hostPlayerIdsProvider);
    final pendingRequests = ref.watch(hostPendingRequestsProvider);
    final latestChange = ref.watch(hostLatestChangeProvider);
    final isUndoAvailable = ref.watch(hostUndoAvailableProvider);

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: PopupMenuButton<String>(
        tooltip: 'Меню управления',
        offset: const Offset(0, -290),
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
            case 'undo':
              final ok = ref
                  .read(hostSessionProvider.notifier)
                  .undoLastLevelChange();
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Изменение уровня отменено.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              break;
            case 'add_player':
              _showAddPlayerDialog();
              break;
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
            case 'end':
              _confirmEndSession();
              break;
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'undo',
            enabled: isUndoAvailable,
            child: Row(
              children: [
                Icon(
                  Icons.undo,
                  size: 18,
                  color: isUndoAvailable ? AppColors.textPrimary : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Text(
                  'Отменить изменение',
                  style: TextStyle(
                    color: isUndoAvailable ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'add_player',
            child: Row(
              children: [
                Icon(Icons.person_add, size: 18, color: AppColors.textPrimary),
                SizedBox(width: 12),
                Text('Добавить игрока', style: TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
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
            value: 'end',
            child: Row(
              children: [
                Icon(Icons.exit_to_app, size: 18, color: AppColors.accentCrimson),
                SizedBox(width: 12),
                Text('Завершить стол', style: TextStyle(color: AppColors.accentCrimson)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
        children: [
          // Latest Change Banner
          LatestChangeBanner(
            latestChange: latestChange,
            targetPlayerName: latestChange != null
                ? engine.getPlayer(latestChange.targetPlayerId)?.name
                : null,
            onTap: _openHistory,
          ),
          // Pending Requests Queue
          PendingRequestsCard(
            requests: pendingRequests,
            getPlayerName: (id) => engine.getPlayer(id)?.name ?? 'Игрок',
            onApprove: (id) =>
                ref.read(hostSessionProvider.notifier).approveRequest(id),
            onDeny: (id) =>
                ref.read(hostSessionProvider.notifier).denyRequest(id),
          ),
          // Player Cards Grid / List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24, top: 4),
              itemCount: playerIds.length,
              itemBuilder: (context, idx) {
                final playerId = playerIds[idx];
                final player = engine.getPlayer(playerId);
                if (player == null) return const SizedBox.shrink();

                final isHost = player.id == engine.hostPlayerId;
                final clientConn = engine.registry.get(player.id);
                final isDisconnected = !isHost && (clientConn == null || !clientConn.isConnected);

                return HostPlayerCard(
                  key: ValueKey(player.id),
                  player: player,
                  isHostPlayer: isHost,
                  isDisconnected: isDisconnected,
                  maxLevel: engine.settings.maxLevel,
                  onApplyLevelChange: ({delta, setValue, required reason}) {
                    ref.read(hostSessionProvider.notifier).applyLevelChange(
                          targetPlayerId: player.id,
                          initiator: const HostInitiated(),
                          delta: delta,
                          setValue: setValue,
                          reason: reason,
                        );
                  },
                  onUpdateGear: (newGear) {
                    ref
                        .read(hostSessionProvider.notifier)
                        .updateGearPower(player.id, newGear);
                  },
                  onEditTraits: () => _showTraitsPicker(player.id),
                  onTransferHost: !isHost && !isDisconnected
                      ? () => _confirmTransferHost(player.id, player.name)
                      : null,
                  onNominateDeputy: !isHost
                      ? () => _nominateDeputy(player.id, player.name)
                      : null,
                  onKickPlayer: !isHost
                      ? () => ref
                          .read(hostSessionProvider.notifier)
                          .kickPlayer(player.id)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
}
