import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../sync/server/host_session_engine.dart';

class PendingRequestsCard extends StatelessWidget {
  final List<PendingLevelRequest> requests;
  final String Function(String playerId) getPlayerName;
  final void Function(String reqId) onApprove;
  final void Function(String reqId) onDeny;

  const PendingRequestsCard({
    super.key,
    required this.requests,
    required this.getPlayerName,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: const Color(0xFF2E241E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.secondaryAmber, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: AppColors.secondaryAmber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Запросы на изменение уровня (${requests.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const Divider(
                color: AppColors.darkCardBorder,
                height: 16,
              ),
              itemBuilder: (context, index) {
                final req = requests[index];
                final name = getPlayerName(req.playerId);
                final deltaStr = req.delta != null
                    ? (req.delta! > 0 ? '+${req.delta}' : '${req.delta}')
                    : '→ Ур. ${req.setValue}';

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGold.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  deltaStr,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${req.reason.localizedTitle} • осталось ${req.remainingSeconds}с',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.check_circle,
                        color: AppColors.accentGreen,
                        size: 28,
                      ),
                      onPressed: () => onApprove(req.reqId),
                      tooltip: 'Принять',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.cancel,
                        color: AppColors.accentCrimson,
                        size: 28,
                      ),
                      onPressed: () => onDeny(req.reqId),
                      tooltip: 'Отклонить',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
