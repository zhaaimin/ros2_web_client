import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single history entry containing field values.
class HistoryEntry {
  final Map<String, String> fields;
  final DateTime createdAt;

  HistoryEntry({required this.fields, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'fields': fields,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      fields: Map<String, String>.from(json['fields'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Display label for the history list.
  String get label {
    final name = fields.values.first;
    return name.length > 50 ? '${name.substring(0, 50)}…' : name;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryEntry &&
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality().equals(fields, other.fields);

  @override
  int get hashCode => const DeepCollectionEquality().hash(fields);
}

/// Manages persistent history records for topic, service, and action tabs.
class HistoryService extends ChangeNotifier {
  static const int maxHistoryPerCategory = 50;

  final Map<String, List<HistoryEntry>> _histories = {};
  SharedPreferences? _prefs;

  /// Categories
  static const String topicCategory = 'topic';
  static const String serviceCategory = 'service';
  static const String actionCategory = 'action';

  /// Initialize the service by loading persisted data.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadAll();
  }

  void _loadAll() {
    for (final category in [topicCategory, serviceCategory, actionCategory]) {
      _loadCategory(category);
    }
  }

  void _loadCategory(String category) {
    final key = 'history_$category';
    final jsonStr = _prefs?.getString(key);
    if (jsonStr != null) {
      try {
        final list = jsonDecode(jsonStr) as List;
        _histories[category] = list
            .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _histories[category] = [];
      }
    } else {
      _histories[category] = [];
    }
  }

  Future<void> _saveCategory(String category) async {
    final key = 'history_$category';
    final list = _histories[category] ?? [];
    final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs?.setString(key, jsonStr);
  }

  /// Get history entries for a category.
  List<HistoryEntry> getHistory(String category) {
    return List.unmodifiable(_histories[category] ?? []);
  }

  /// Add a history entry. Duplicates (same fields) are moved to the top.
  Future<void> addEntry(String category, HistoryEntry entry) async {
    final list = _histories.putIfAbsent(category, () => []);
    // Remove duplicate if exists
    list.removeWhere((e) => e == entry);
    // Insert at the beginning
    list.insert(0, entry);
    // Trim to max size
    if (list.length > maxHistoryPerCategory) {
      list.removeRange(maxHistoryPerCategory, list.length);
    }
    await _saveCategory(category);
    notifyListeners();
  }

  /// Delete a specific history entry.
  Future<void> deleteEntry(String category, int index) async {
    final list = _histories[category];
    if (list != null && index >= 0 && index < list.length) {
      list.removeAt(index);
      await _saveCategory(category);
      notifyListeners();
    }
  }

  /// Clear all history for a category.
  Future<void> clearCategory(String category) async {
    _histories[category] = [];
    await _saveCategory(category);
    notifyListeners();
  }
}

/// Helper for deep equality on maps.
class DeepCollectionEquality {
  const DeepCollectionEquality();

  bool equals(Map? a, Map? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  int hash(Map? map) {
    if (map == null) return 0;
    int result = 0;
    for (final entry in map.entries) {
      result ^= entry.key.hashCode ^ entry.value.hashCode;
    }
    return result;
  }
}
