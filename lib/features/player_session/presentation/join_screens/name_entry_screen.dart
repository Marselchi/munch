import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../persistence/settings_store.dart';
import '../../../../sync/client/ws_client.dart';
import '../../../../sync/protocol/envelope.dart';
import '../../../../sync/protocol/messages.dart';

class NameEntryScreen extends StatefulWidget {
  final ValueChanged<String> onNameSubmitted;
  final ValueChanged<ClaimableSeat>? onSeatClaimed;
  final List<String>? hostIps;
  final int? port;
  final List<ClaimableSeat>? initialClaimableSeats;

  const NameEntryScreen({
    super.key,
    required this.onNameSubmitted,
    this.onSeatClaimed,
    this.hostIps,
    this.port,
    this.initialClaimableSeats,
  });

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  final _nameController = TextEditingController();
  bool _isValid = false;
  List<ClaimableSeat> _claimableSeats = [];
  bool _isLoadingSeats = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialClaimableSeats != null) {
      _claimableSeats = widget.initialClaimableSeats!;
    }
    _loadLastName();
    _nameController.addListener(_validate);
    _fetchClaimableSeats();
  }

  Future<void> _loadLastName() async {
    final lastName = await SettingsStore.getLastPlayerName();
    if (mounted && lastName != null && lastName.isNotEmpty) {
      _nameController.text = lastName;
      _validate();
    }
  }

  Future<void> _fetchClaimableSeats() async {
    if (widget.hostIps == null || widget.hostIps!.isEmpty) return;

    setState(() => _isLoadingSeats = true);
    final client = WebSocketClient();

    try {
      final (channel, _) = await client.raceCandidates(
        widget.hostIps!,
        widget.port ?? AppConstants.defaultPort,
        timeout: const Duration(seconds: 1),
      );

      final completer = Completer<List<ClaimableSeat>>();
      channel.stream.listen(
        (msg) {
          if (msg is String) {
            try {
              final env = Envelope.decode(msg);
              if (env.type == MessageType.seatsListResponse) {
                final resp = SeatsListResponse.fromJson(env.data);
                if (!completer.isCompleted) completer.complete(resp.seats);
              }
            } catch (_) {}
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(const []);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(const []);
        },
      );

      final req = Envelope.create(
        type: MessageType.seatsListRequest,
        sessionId: '',
      );
      channel.sink.add(req.encode());

      final seats = await completer.future.timeout(const Duration(seconds: 2));
      client.disconnect();

      if (mounted) {
        setState(() {
          _claimableSeats = seats;
          _isLoadingSeats = false;
        });
      }
    } catch (_) {
      client.disconnect();
      if (mounted) {
        setState(() => _isLoadingSeats = false);
      }
    }
  }

  void _validate() {
    final text = _nameController.text.trim();
    final valid = text.length >= AppConstants.minNameLength &&
        text.length <= AppConstants.maxNameLength;
    if (_isValid != valid) {
      setState(() => _isValid = valid);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_validate);
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_isValid) return;
    final name = _nameController.text.trim();
    SettingsStore.setLastPlayerName(name);
    widget.onNameSubmitted(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор персонажа'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Claimable seats section if any exist
            if (_claimableSeats.isNotEmpty) ...[
              const Text(
                'Свободные места за столом:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Вы можете занять уже созданного персонажа:',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ..._claimableSeats.map((seat) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      seat.isLocal ? Icons.chair : Icons.person_off,
                      color: AppColors.primaryGold,
                    ),
                    title: Text(
                      seat.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Уровень ${seat.level} • Сила ${seat.gearPower + seat.level} '
                      '${seat.isLocal ? "(Создан ведущим)" : "(Свободно)"}',
                    ),
                    trailing: const ElevatedButton(
                      onPressed: null,
                      child: Text('Занять'),
                    ),
                    onTap: () {
                      if (widget.onSeatClaimed != null) {
                        widget.onSeatClaimed!(seat);
                      } else {
                        widget.onNameSubmitted(seat.name);
                      }
                    },
                  ),
                );
              }),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'ИЛИ',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
            ],

            if (_isLoadingSeats) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ],

            const Text(
              'Создать нового манчкина',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Имя будет отображаться всем игрокам за столом.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: _claimableSeats.isEmpty,
              maxLength: AppConstants.maxNameLength,
              decoration: const InputDecoration(
                labelText: 'Имя манчкина',
                hintText: 'Конан, Суперманчкин и т.д.',
                prefixIcon: Icon(Icons.person),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isValid ? _submit : null,
              child: const Text('Присоединиться к столу'),
            ),
          ],
        ),
      ),
    );
  }
}
