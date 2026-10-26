import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:munchkin_companion/core/constants/app_constants.dart';
import 'package:munchkin_companion/core/theme/app_colors.dart';
import 'package:munchkin_companion/sync/protocol/models.dart';
import '../application/host_session_controller.dart';
import 'host_game_screen.dart';

class HostLobbyScreen extends ConsumerStatefulWidget {
  const HostLobbyScreen({super.key});

  @override
  ConsumerState<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends ConsumerState<HostLobbyScreen> {
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

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showAddPlayerDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить игрока'),
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

  void _confirmTransferHost(String playerId, String playerName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Передать стол?'),
        content: Text(
          'Вы действительно хотите сделать игрока "$playerName" новым ведущим стола? Ваши локальные персонажи перейдут под его управление.',
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

  @override
  Widget build(BuildContext context) {
    final hostState = ref.watch(hostSessionProvider);
    if (hostState == null) {
      return const Scaffold(
        body: Center(child: Text('Сессия не запущена.')),
      );
    }

    final ips = ref.watch(hostIpsProvider);
    final port = ref.watch(hostPortProvider);
    final playerIds = ref.watch(hostPlayerIdsProvider);
    final pendingApprovals = ref.watch(hostPendingApprovalsProvider);
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

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Закрыть стол',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Закрыть стол?'),
                  content: const Text('Текущая сессия будет завершена.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Назад'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCrimson,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Закрыть'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await ref.read(hostSessionProvider.notifier).endSession();
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                // Hotspot + VPN Warning Banner
                Consumer(
                  builder: (context, ref, _) {
                    final warningAsync = ref.watch(hostHotspotVpnWarningProvider);
                    if (warningAsync.value == true) {
                      return Card(
                        color: AppColors.darkCard,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: AppColors.accentCrimson),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppColors.accentCrimson, size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Внимание: Обнаружен активный VPN при раздаче точки доступа Wi-Fi. '
                                  'Игроки могут не видеть этот стол. Включите «LAN bypass / Разрешить локальную сеть» в настройках VPN или отключите VPN.',
                                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // QR Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Подключение по QR-коду',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        RepaintBoundary(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: qrString,
                              version: QrVersions.auto,
                              size: 180,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Порт: $port • IP: ${ips.join(", ")}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: 'Скопировать код подключения',
                              onPressed: () => _copyToClipboard(
                                qrString,
                                'Код стола скопирован в буфер обмена',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Join Approval Switch
                SwitchListTile(
                  title: const Text('Ручное одобрение игроков'),
                  subtitle: const Text('Запрашивать подтверждение ведущего при входе'),
                  value: engine.requireJoinApproval,
                  onChanged: (val) {
                    ref.read(hostSessionProvider.notifier).setRequireJoinApproval(val);
                  },
                ),

                // Pending Approvals
                if (pendingApprovals.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Заявки на подключение:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          ...pendingApprovals.map((req) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(req.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: AppColors.accentGreen),
                                    onPressed: () {
                                      ref
                                          .read(hostSessionProvider.notifier)
                                          .approveJoin(req.reqId);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: AppColors.accentCrimson),
                                    onPressed: () {
                                      ref
                                          .read(hostSessionProvider.notifier)
                                          .denyJoin(req.reqId);
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Players Header with Add Player button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Игроки за столом (${playerIds.length}):',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Добавить игрока'),
                      onPressed: _showAddPlayerDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Players List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: playerIds.length,
                  itemBuilder: (context, idx) {
                    final playerId = playerIds[idx];
                    final player = engine.getPlayer(playerId);
                    if (player == null) return const SizedBox.shrink();

                    final isHost = player.id == engine.hostPlayerId;

                    final rosterEntry = engine.node.roster.where((r) => r.playerId == playerId).firstOrNull;
                    final isDeputy = rosterEntry != null && rosterEntry.rank == 1 && !isHost;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF333742),
                          child: Text(
                            player.name.isNotEmpty
                                ? player.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(player.name),
                            if (isDeputy) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.statusReconnecting.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Заместитель',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.statusReconnecting,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          isHost ? 'Ведущий стола' : 'В игре',
                          style: TextStyle(
                            fontSize: 12,
                            color: isHost ? AppColors.textSecondary : AppColors.accentGreen,
                          ),
                        ),
                        trailing: isHost
                            ? null
                            : PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (val) {
                                  if (val == 'transfer') {
                                    _confirmTransferHost(player.id, player.name);
                                  } else if (val == 'deputy') {
                                    ref.read(hostSessionProvider.notifier).nominateDeputy(player.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${player.name} назначен заместителем ведущего')),
                                    );
                                  } else if (val == 'kick') {
                                    ref.read(hostSessionProvider.notifier).kickPlayer(player.id);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'deputy',
                                    child: Row(
                                      children: [
                                        Icon(Icons.star_outline, size: 18),
                                        SizedBox(width: 8),
                                        Text('Назначить заместителем'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'transfer',
                                    child: Row(
                                      children: [
                                        Icon(Icons.swap_horiz, size: 18),
                                        SizedBox(width: 8),
                                        Text('Сделать ведущим'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'kick',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove, size: 18, color: AppColors.accentCrimson),
                                        SizedBox(width: 8),
                                        Text('Исключить', style: TextStyle(color: AppColors.accentCrimson)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('Открыть стол'),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/table'),
                          builder: (_) => const HostGameScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
