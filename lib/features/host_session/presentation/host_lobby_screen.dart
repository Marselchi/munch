import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../sync/protocol/models.dart';
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
                        title: Text(player.name),
                        subtitle: Text(
                          isHost ? 'Ведущий стола' : 'В игре',
                          style: TextStyle(
                            fontSize: 12,
                            color: isHost ? AppColors.textSecondary : AppColors.accentGreen,
                          ),
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
