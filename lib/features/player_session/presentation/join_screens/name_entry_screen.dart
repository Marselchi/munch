import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../persistence/settings_store.dart';

class NameEntryScreen extends StatefulWidget {
  final ValueChanged<String> onNameSubmitted;

  const NameEntryScreen({super.key, required this.onNameSubmitted});

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  final _nameController = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _loadLastName();
    _nameController.addListener(_validate);
  }

  Future<void> _loadLastName() async {
    final lastName = await SettingsStore.getLastPlayerName();
    if (mounted && lastName != null && lastName.isNotEmpty) {
      _nameController.text = lastName;
      _validate();
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
        title: const Text('Ваш персонаж'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Как зовут вашего манчкина?',
              style: TextStyle(
                fontSize: 20,
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
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: AppConstants.maxNameLength,
              decoration: const InputDecoration(
                labelText: 'Имя манчкина',
                hintText: 'Конан, Суперманчкин и т.д.',
                prefixIcon: Icon(Icons.person),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
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
