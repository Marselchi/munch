import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../features/rules/domain/rules_entities.dart';
import '../../features/rules/domain/rules_category.dart';

class SafeTraitsPickerSheet extends StatefulWidget {
  final String playerName;
  final List<RuleEntity> allEntities;
  final List<String> initialSelected;
  final ValueChanged<List<String>> onSave;

  const SafeTraitsPickerSheet({
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
      useSafeArea: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeTraitsPickerSheet(
        playerName: playerName,
        allEntities: allEntities,
        initialSelected: initialSelected,
        onSave: onSave,
      ),
    );
  }

  @override
  State<SafeTraitsPickerSheet> createState() => _SafeTraitsPickerSheetState();
}

class _SafeTraitsPickerSheetState extends State<SafeTraitsPickerSheet> {
  late final Set<String> _selected;
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'all';

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

  List<String> _getAvailableCategories() {
    final kinds = widget.allEntities
        .map((e) => e.kind.toLowerCase().trim())
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList();

    // Standard ordering
    const priority = [
      'class',
      'race',
      'mojo',
      'power',
      'style',
      'training',
      'accent',
      'steed',
      'ship',
      'hireling',
      'dungeon',
      'enhancer',
      'seal',
      'disaster',
      'madness',
    ];

    kinds.sort((a, b) {
      final idxA = priority.indexOf(a);
      final idxB = priority.indexOf(b);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return a.compareTo(b);
    });

    return ['all', ...kinds];
  }

  List<RuleEntity> _getFilteredEntities() {
    final query = _searchCtrl.text.trim().toLowerCase();

    return widget.allEntities.where((e) {
      final kind = e.kind.toLowerCase().trim();

      // Category filter
      if (_selectedCategory != 'all' && kind != _selectedCategory) {
        return false;
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

  String _getKindTitle(String kind) {
    if (kind == 'all') return 'Все';
    final cat = RuleCategoryType.fromKind(kind);
    return cat.title;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredEntities();
    final categories = _getAvailableCategories();
    final viewInsets = MediaQuery.of(context).viewInsets;
    final padding = MediaQuery.of(context).padding;
    final bottomSafePadding = math.max(16.0, padding.bottom + 12.0);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.darkCardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Классы и свойства: ${widget.playerName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Search Bar
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primaryGold),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                hintText: 'Поиск (воин, эльф, вампир, мутант, моджо...)',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),

            // Concrete Category Filter Chips (not just "other")
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildCategoryChip(cat, _getKindTitle(cat)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Selected traits preview chips
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
              const SizedBox(height: 6),
            ],

            const Divider(color: AppColors.darkCardBorder, height: 1),

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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          title: Text(
                            entity.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                          subtitle: Text(
                            '${_getKindTitle(entity.kind)} • Набор: ${entity.setId}',
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

            // Safe Bottom Action Bar (Save & Cancel never overlapped by phone bar)
            Container(
              padding: EdgeInsets.only(top: 10, bottom: bottomSafePadding),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.darkCardBorder, width: 1)),
              ),
              child: Row(
                children: [
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selected.clear();
                        });
                      },
                      child: const Text(
                        'Сбросить всё',
                        style: TextStyle(color: AppColors.accentCrimson, fontSize: 13),
                      ),
                    ),
                  const Spacer(),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(96, 44),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(110, 44),
                    ),
                    onPressed: () {
                      widget.onSave(_selected.toList());
                      Navigator.of(context).pop();
                    },
                    child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
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
        fontSize: 11,
        color: isCurrent ? AppColors.textPrimary : AppColors.textSecondary,
        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isCurrent ? AppColors.primaryGold : AppColors.darkCardBorder,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
