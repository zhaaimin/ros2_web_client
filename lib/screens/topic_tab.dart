import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rosbridge_service.dart';
import '../services/history_service.dart';
import '../widgets/history_selector.dart';

class TopicTab extends StatefulWidget {
  const TopicTab({super.key});

  @override
  State<TopicTab> createState() => _TopicTabState();
}

class _TopicTabState extends State<TopicTab> {
  final _topicController = TextEditingController(text: '/chatter');
  final _typeController = TextEditingController(text: 'std_msgs/String');
  final _msgController = TextEditingController(text: '{"data": "hello from flutter"}');
  final List<Map<String, dynamic>> _receivedMessages = [];
  bool _subscribed = false;
  String? _subscribedTopic;
  bool _isPublishMode = false;

  @override
  void dispose() {
    _topicController.dispose();
    _typeController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _subscribe() {
    final service = context.read<RosbridgeService>();
    if (!service.connected) {
      _showSnackBar('请先连接服务器');
      return;
    }
    final topic = _topicController.text.trim();
    final type = _typeController.text.trim();
    if (topic.isEmpty || type.isEmpty) {
      _showSnackBar('请输入 Topic 名称和类型');
      return;
    }
    service.subscribe(topic, type, (msg) {
      setState(() {
        _receivedMessages.insert(0, {
          'time': DateTime.now().toIso8601String().substring(11, 23),
          'data': msg,
        });
        if (_receivedMessages.length > 100) _receivedMessages.removeLast();
      });
    });
    // Save to history
    context.read<HistoryService>().addEntry(
      HistoryService.topicCategory,
      HistoryEntry(fields: {'topic': topic, 'type': type}),
    );
    setState(() {
      _subscribed = true;
      _subscribedTopic = topic;
    });
  }

  void _unsubscribe() {
    if (_subscribedTopic != null) {
      context.read<RosbridgeService>().unsubscribe(_subscribedTopic!);
    }
    setState(() {
      _subscribed = false;
      _subscribedTopic = null;
    });
  }

  void _publish() {
    final service = context.read<RosbridgeService>();
    if (!service.connected) {
      _showSnackBar('请先连接服务器');
      return;
    }
    final topic = _topicController.text.trim();
    final type = _typeController.text.trim();
    final msgStr = _msgController.text.trim();
    if (topic.isEmpty || type.isEmpty) {
      _showSnackBar('请输入 Topic 名称和类型');
      return;
    }
    try {
      final msg = jsonDecode(msgStr) as Map<String, dynamic>;
      service.publish(topic, type, msg);
      // Save to history
      context.read<HistoryService>().addEntry(
        HistoryService.topicCategory,
        HistoryEntry(fields: {'topic': topic, 'type': type, 'msg': msgStr}),
      );
      _showSnackBar('已发布消息到 $topic');
    } catch (e) {
      _showSnackBar('JSON 格式错误: $e');
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
                      Text('Topic 测试', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      HistorySelector(
                        category: HistoryService.topicCategory,
                        onSelect: (fields) {
                          _topicController.text = fields['topic'] ?? '';
                          _typeController.text = fields['type'] ?? '';
                          if (fields.containsKey('msg')) {
                            _msgController.text = fields['msg']!;
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _topicController,
                          decoration: const InputDecoration(
                            labelText: 'Topic',
                            hintText: '/chatter',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _typeController,
                          decoration: const InputDecoration(
                            labelText: '消息类型',
                            hintText: 'std_msgs/String',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('订阅'), icon: Icon(Icons.notifications_active)),
                          ButtonSegment(value: true, label: Text('发布'), icon: Icon(Icons.send)),
                        ],
                        selected: {_isPublishMode},
                        onSelectionChanged: (selected) {
                          setState(() => _isPublishMode = selected.first);
                        },
                      ),
                      const Spacer(),
                      if (!_isPublishMode)
                        TextButton.icon(
                          onPressed: () => setState(() => _receivedMessages.clear()),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('清空'),
                        ),
                    ],
                  ),
                  if (_isPublishMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(
                        labelText: '发布消息 (JSON)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_isPublishMode)
                    FilledButton.icon(
                      onPressed: _publish,
                      icon: const Icon(Icons.send),
                      label: const Text('发布'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _subscribed ? _unsubscribe : _subscribe,
                      icon: Icon(_subscribed ? Icons.notifications_off : Icons.notifications_active),
                      label: Text(_subscribed ? '取消订阅' : '订阅'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _subscribed ? Colors.orange : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '收到的消息 (${_receivedMessages.length})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              color: const Color(0xFF1E1E1E),
              child: _receivedMessages.isEmpty
                  ? const Center(
                      child: Text('暂无消息，请先订阅 Topic', style: TextStyle(color: Colors.white38)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _receivedMessages.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                      itemBuilder: (context, index) {
                        final item = _receivedMessages[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['time'] as String,
                                style: const TextStyle(fontFamily: 'Menlo', fontSize: 11, color: Colors.white38),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                const JsonEncoder.withIndent('  ').convert(item['data']),
                                style: const TextStyle(fontFamily: 'Menlo', fontSize: 12, color: Colors.greenAccent),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
