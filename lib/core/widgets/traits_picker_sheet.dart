import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../features/rules/domain/rules_entities.dart';

class TraitsPickerSheet extends StatefulWidget {
  final String playerName;
  final List<RuleEntity> allEntities;
  final List<String> initialSelected;
  final ValueChanged<List<String>> onSave;

  const TraitsPickerSheet({
    super.key,
    required this.playerName,
    required this.allEntities,
    required this.initialSelected,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required String playerName,
    required List<RuleEntity> allEntities,
    required List<String> initialSelected,
    required ValueChanged<List<String>> onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TraitsPickerSheet(
        playerName: playerName,
        allEntities: allEntities,
        initialSelected: initialSelected,
        onSave: onSave,
      ),
    );
  }

  @override
  State<TraitsPickerSheet> createState() => _TraitsPickerSheetState();
}

class _TraitsPickerSheetState extends State<TraitsPickerSheet> {
  late final Set<String> _selected;
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'all'; // 'all', 'class', 'race', 'other'

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<RuleEntity> _getFilteredEntities() {
    final query = _searchCtrl.text.trim().toLowerCase();

    return widget.allEntities.where((e) {
      // Category filter
      if (_selectedCategory == 'class' && e.kind.toLowerCase() != 'class') {
        return false;
      }
      if (_selectedCategory == 'race' && e.kind.toLowerCase() != 'race') {
        return false;
      }
      if (_selectedCategory == 'other') {
        final k = e.kind.toLowerCase();
        if (k == 'class' || k == 'race') return false;
      }

      // Search query filter
      if (query.isEmpty) return true;

      if (e.title.toLowerCase().contains(query)) return true;
      for (final alias in e.aliases) {
        if (alias.toLowerCase().contains(query)) return true;
      }
      return false;
    }).toList();
  }

  String _getKindLabel(String kind) {
    switch (kind.toLowerCase()) {
      case 'class':
        return 'Класс';
      case 'race':
        return 'Раса';
      case 'accent':
        return 'Акцент';
      case 'mojo':
        return 'Моджо';
      case 'style':
        return 'Стиль';
      case 'power':
        return 'Сила';
      default:
        return 'Свойство';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredEntities();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Классы и Расы: ${widget.playerName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Search Bar
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                hintText: 'Поиск (воин, эльф, вампир, мутант...)',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('all', 'Все'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('class', 'Классы'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('race', 'Расы'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('other', 'Акценты / Моджо / Силы'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Selected traits chips preview
            if (_selected.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _selected.map((t) {
                  return Chip(
                    label: Text(t, style: const TextStyle(fontSize: 12)),
                    backgroundColor: const Color(0xFF2C3038),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() {
                        _selected.remove(t);
                      });
                    },
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            const Divider(color: AppColors.darkCardBorder),

            // List of items
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _searchCtrl.text.isNotEmpty
                            ? 'Ничего не найдено по запросу «${_searchCtrl.text}»'
                            : 'Список характеристик пуст',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final entity = filtered[i];
                        final isSelected = _selected.contains(entity.title);

                        return CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: Text(
                            entity.title,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                          subtitle: Text(
                            '${_getKindLabel(entity.kind)} • Набор: ${entity.setId}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          value: isSelected,
                          activeColor: AppColors.primaryGold,
                          checkColor: Colors.black,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selected.add(entity.title);
                              } else {
                                _selected.remove(entity.title);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),

            // Save / Reset Actions
            const SizedBox(height: 8),
            Row(
              children: [
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selected.clear();
                      });
                    },
                    child: const Text('Сбросить всё', style: TextStyle(color: AppColors.accentCrimson)),
                  ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    widget.onSave(_selected.toList());
                    Navigator.of(context).pop();
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label) {
    final isCurrent = _selectedCategory == id;
    return FilterChip(
      label: Text(label),
      selected: isCurrent,
      onSelected: (_) {
        setState(() {
          _selectedCategory = id;
        });
      },
      selectedColor: const Color(0xFF383C48),
      backgroundColor: const Color(0xFF22252C),
      labelStyle: TextStyle(
        fontSize: 12,
        color: isCurrent ? AppColors.textPrimary : AppColors.textSecondary,
        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isCurrent ? const Color(0xFF6B7280) : AppColors.darkCardBorder,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
