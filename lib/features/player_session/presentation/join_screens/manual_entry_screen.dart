import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../persistence/settings_store.dart';
import '../../../../sync/protocol/models.dart';

class ManualEntryScreen extends StatefulWidget {
  final ValueChanged<QrPayload> onComplete;

  const ManualEntryScreen({super.key, required this.onComplete});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '${AppConstants.defaultPort}');
  final _tokenController = TextEditingController();
  List<String> _recentIps = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final recent = await SettingsStore.getRecentHostIps();
    if (mounted) {
      setState(() {
        _recentIps = recent;
        if (_recentIps.isNotEmpty && _ipController.text.isEmpty) {
          _ipController.text = _recentIps.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _submit() {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? AppConstants.defaultPort;
    final token = _tokenController.text.trim();

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите IP адрес ведущего.')),
      );
      return;
    }

    SettingsStore.addRecentHostIp(ip);

    final payload = QrPayload(
      marker: AppConstants.appMarker,
      version: AppConstants.protocolVersion,
      sessionId: '',
      sessionName: 'Игра',
      hostIps: [ip],
      port: port,
      token: token.isNotEmpty ? token : null,
    );

    widget.onComplete(payload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подключение вручную'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Укажите сетевые данные ведущего стола:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'IP адрес ведущего',
                hintText: 'например, 192.168.1.25',
                prefixIcon: Icon(Icons.wifi),
              ),
            ),
            if (_recentIps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _recentIps.map((ip) {
                  return ActionChip(
                    label: Text(ip),
                    backgroundColor: AppColors.darkCard,
                    onPressed: () {
                      setState(() {
                        _ipController.text = ip;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Порт (по умолчанию 8787)',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Токен переподключения (необязательно)',
                hintText: 'Если вы переподключаетесь к прошлой игре',
                prefixIcon: Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Подключиться'),
            ),
          ],
        ),
      ),
    );
  }
}
