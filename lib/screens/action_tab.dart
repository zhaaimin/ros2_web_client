import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rosbridge_service.dart';
import '../services/history_service.dart';
import '../widgets/history_selector.dart';

class ActionTab extends StatefulWidget {
  const ActionTab({super.key});

  @override
  State<ActionTab> createState() => _ActionTabState();
}

class _ActionTabState extends State<ActionTab> {
  final _actionController = TextEditingController(text: '/fibonacci');
  final _typeController = TextEditingController(text: 'action_tutorials_interfaces/action/Fibonacci');
  final _goalController = TextEditingController(text: '{"order": 5}');
  final List<String> _feedbacks = [];
  String? _result;
  bool _loading = false;

  @override
  void dispose() {
    _actionController.dispose();
    _typeController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _sendGoal() async {
    final service = context.read<RosbridgeService>();
    if (!service.connected) {
      _showSnackBar('请先连接服务器');
      return;
    }

    final actionName = _actionController.text.trim();
    final actionType = _typeController.text.trim();
    final goalStr = _goalController.text.trim();

    if (actionName.isEmpty || actionType.isEmpty) {
      _showSnackBar('请输入 Action 名称和类型');
      return;
    }

    Map<String, dynamic> goal = {};
    if (goalStr.isNotEmpty) {
      try {
        goal = jsonDecode(goalStr) as Map<String, dynamic>;
      } catch (e) {
        _showSnackBar('JSON 格式错误: $e');
        return;
      }
    }

    setState(() {
      _loading = true;
      _result = null;
      _feedbacks.clear();
    });

    try {
      // Save to history
      context.read<HistoryService>().addEntry(
        HistoryService.actionCategory,
        HistoryEntry(fields: {
          'action': actionName,
          'type': actionType,
          'goal': goalStr,
        }),
      );

      final result = await service.sendActionGoal(
        actionName,
        actionType,
        goal,
        onFeedback: (feedback) {
          setState(() {
            final ts = DateTime.now().toIso8601String().substring(11, 23);
            _feedbacks.add('[$ts] ${const JsonEncoder.withIndent('  ').convert(feedback)}');
          });
        },
      );
      setState(() {
        _result = const JsonEncoder.withIndent('  ').convert(result);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _result = '错误: $e';
        _loading = false;
      });
    }
  }

  void _cancelGoal() {
    final actionName = _actionController.text.trim();
    if (actionName.isNotEmpty) {
      context.read<RosbridgeService>().cancelActionGoal(actionName);
      setState(() => _loading = false);
      _showSnackBar('已发送取消请求');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Action 测试', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      HistorySelector(
                        category: HistoryService.actionCategory,
                        onSelect: (fields) {
                          _actionController.text = fields['action'] ?? '';
                          _typeController.text = fields['type'] ?? '';
                          if (fields.containsKey('goal')) {
                            _goalController.text = fields['goal']!;
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _actionController,
                          decoration: const InputDecoration(
                            labelText: 'Action 名称',
                            hintText: '/fibonacci',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _typeController,
                          decoration: const InputDecoration(
                            labelText: 'Action 类型',
                            hintText: 'action_tutorials_interfaces/action/Fibonacci',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _goalController,
                    decoration: const InputDecoration(
                      labelText: 'Goal (JSON)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _loading ? null : _sendGoal,
                        icon: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.rocket_launch),
                        label: Text(_loading ? '执行中…' : '发送 Goal'),
                      ),
                      const SizedBox(width: 8),
                      if (_loading)
                        OutlinedButton.icon(
                          onPressed: _cancelGoal,
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text('取消', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Feedback and Result
          Expanded(
            child: Row(
              children: [
                // Feedback
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Feedback (${_feedbacks.length})', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Card(
                          color: const Color(0xFF1E1E1E),
                          child: _feedbacks.isEmpty
                              ? const Center(child: Text('等待 Feedback…', style: TextStyle(color: Colors.white38)))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _feedbacks.length,
                                  itemBuilder: (context, index) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      _feedbacks[index],
                                      style: const TextStyle(fontFamily: 'Menlo', fontSize: 12, color: Colors.amberAccent),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Result
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Result', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Card(
                          color: const Color(0xFF1E1E1E),
                          child: _result == null
                              ? const Center(child: Text('等待 Result…', style: TextStyle(color: Colors.white38)))
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: SelectableText(
                                    _result!,
                                    style: TextStyle(
                                      fontFamily: 'Menlo',
                                      fontSize: 13,
                                      color: _result!.startsWith('错误') ? Colors.redAccent : Colors.greenAccent,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
