import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/history_service.dart';

/// A button that shows a popup menu of history entries for a given category.
/// When an entry is selected, [onSelect] is called with the entry's fields.
class HistorySelector extends StatelessWidget {
  final String category;
  final void Function(Map<String, String> fields) onSelect;

  const HistorySelector({
    super.key,
    required this.category,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final historyService = context.watch<HistoryService>();
    final entries = historyService.getHistory(category);

    return PopupMenuButton<int>(
      icon: Badge(
        isLabelVisible: entries.isNotEmpty,
        label: Text('${entries.length}'),
        child: const Icon(Icons.history),
      ),
      tooltip: '历史记录',
      enabled: entries.isNotEmpty,
      itemBuilder: (context) {
        final items = <PopupMenuEntry<int>>[];

        // Clear all option
        items.add(
          PopupMenuItem<int>(
            value: -1,
            child: Row(
              children: [
                const Icon(Icons.delete_sweep, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                Text('清空全部历史', style: TextStyle(color: Colors.red.shade300)),
              ],
            ),
          ),
        );
        items.add(const PopupMenuDivider());

        // History entries
        for (int i = 0; i < entries.length; i++) {
          final entry = entries[i];
          items.add(
            PopupMenuItem<int>(
              value: i,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _truncate(entry.fields.values.first, 40),
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (entry.fields.length > 1)
                          Text(
                            entry.fields.entries.skip(1).map((e) => _truncate(e.value, 25)).join(' | '),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      historyService.deleteEntry(category, i);
                      Navigator.of(context).pop();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return items;
      },
      onSelected: (index) {
        if (index == -1) {
          historyService.clearCategory(category);
        } else if (index >= 0 && index < entries.length) {
          onSelect(entries[index].fields);
        }
      },
    );
  }

  String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}…';
  }
}

/// A TextField with an inline dropdown showing history values for a specific field.
/// When an entry is selected, [onEntrySelected] is called with the full entry's fields,
/// allowing related fields to also be filled.
class HistoryTextField extends StatelessWidget {
  final TextEditingController controller;
  final String category;
  final String fieldKey;
  final InputDecoration? decoration;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final void Function(Map<String, String> fields)? onEntrySelected;

  const HistoryTextField({
    super.key,
    required this.controller,
    required this.category,
    required this.fieldKey,
    this.decoration,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.onSubmitted,
    this.onEntrySelected,
  });

  @override
  Widget build(BuildContext context) {
    final historyService = context.watch<HistoryService>();
    final entries = historyService.getHistory(category);

    // Get unique values for this field, preserving order
    final uniqueEntries = <String, HistoryEntry>{};
    for (final entry in entries) {
      final value = entry.fields[fieldKey];
      if (value != null && value.isNotEmpty && !uniqueEntries.containsKey(value)) {
        uniqueEntries[value] = entry;
      }
    }

    final hasHistory = uniqueEntries.isNotEmpty;

    final effectiveDecoration = (decoration ?? const InputDecoration()).copyWith(
      suffixIcon: hasHistory
          ? _HistoryDropdownButton(
              category: category,
              uniqueEntries: uniqueEntries,
              onSelected: (entry) {
                controller.text = entry.fields[fieldKey] ?? '';
                onEntrySelected?.call(entry.fields);
              },
            )
          : null,
    );

    return TextField(
      controller: controller,
      decoration: effectiveDecoration,
      maxLines: maxLines,
      minLines: minLines,
      enabled: enabled,
      onSubmitted: onSubmitted,
    );
  }
}

class _HistoryDropdownButton extends StatelessWidget {
  final String category;
  final Map<String, HistoryEntry> uniqueEntries;
  final void Function(HistoryEntry entry) onSelected;

  const _HistoryDropdownButton({
    required this.category,
    required this.uniqueEntries,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.arrow_drop_down, size: 22),
      tooltip: '历史记录',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(maxHeight: 350),
      position: PopupMenuPosition.under,
      itemBuilder: (context) {
        final historyService = context.read<HistoryService>();
        final allEntries = historyService.getHistory(category);

        return uniqueEntries.entries.map((e) {
          final display = e.key.length > 60 ? '${e.key.substring(0, 60)}…' : e.key;
          return PopupMenuItem<String>(
            value: e.key,
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    display,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final idx = allEntries.indexOf(e.value);
                    if (idx >= 0) {
                      historyService.deleteEntry(category, idx);
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      onSelected: (value) {
        final entry = uniqueEntries[value];
        if (entry != null) {
          onSelected(entry);
        }
      },
    );
  }
}
