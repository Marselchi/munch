import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../application/rules_controller.dart';
import '../data/pack_registry.dart';

class RulesSettingsScreen extends ConsumerStatefulWidget {
  const RulesSettingsScreen({super.key});

  @override
  ConsumerState<RulesSettingsScreen> createState() => _RulesSettingsScreenState();
}

class _RulesSettingsScreenState extends ConsumerState<RulesSettingsScreen> {
  List<InstalledPackInfo> _packs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  Future<void> _loadPacks() async {
    setState(() => _isLoading = true);
    final list = await PackRegistry.getInstalledPacksList();
    if (mounted) {
      setState(() {
        _packs = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _importFromFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final content = await File(files.first.path!).readAsString();

        await ref.read(rulesProvider.notifier).importPack(content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пакет правил успешно импортирован!')),
          );
        }
        await _loadPacks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка импорта: $e'),
            backgroundColor: AppColors.accentCrimson,
          ),
        );
      }
    }
  }

  void _showPasteJsonDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Вставить JSON пакета'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Вставьте содержимое JSON пакета правил…',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await ref.read(rulesProvider.notifier).importPack(text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Пакет успешно импортирован!')),
                  );
                }
                await _loadPacks();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка импорта: $e'),
                      backgroundColor: AppColors.accentCrimson,
                    ),
                  );
                }
              }
            },
            child: const Text('Импортировать'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePack(String contentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Удалить пакет?'),
        content: Text('Вы действительно хотите удалить пакет "$contentId"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCrimson),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(rulesProvider.notifier).removePack(contentId);
      await _loadPacks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пакет удален.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пакеты правил'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _packs.isEmpty
              ? EmptyState(
                  icon: Icons.library_books,
                  title: 'Нет установленных пакетов',
                  action: ElevatedButton.icon(
                    onPressed: _importFromFile,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Импортировать JSON'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    ..._packs.map((pack) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: pack.isBundled
                                      ? AppColors.primaryGold.withOpacity(0.15)
                                      : AppColors.accentBlue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  pack.isBundled ? Icons.verified : Icons.extension,
                                  color: pack.isBundled
                                      ? AppColors.primaryGold
                                      : AppColors.accentBlue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            pack.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'v${pack.contentVersion}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${pack.entityCount} сущностей • ${pack.ruleBlockCount} статей правил'
                                      '${pack.isBundled ? " • Встроенный" : " • Пользовательский"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!pack.isBundled)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.accentCrimson),
                                  onPressed: () => _deletePack(pack.contentId),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _importFromFile,
                            icon: const Icon(Icons.file_upload),
                            label: const Text('Файл JSON'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showPasteJsonDialog,
                            icon: const Icon(Icons.paste),
                            label: const Text('Вставить текст'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
