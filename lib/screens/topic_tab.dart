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

class _TopicTabState extends State<TopicTab> with AutomaticKeepAliveClientMixin {
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
      if (!mounted) return;
      setState(() {
        _receivedMessages.insert(0, {
          'time': DateTime.now().toIso8601String().substring(11, 23),
          'data': msg,
        });
        if (_receivedMessages.length > 10) _receivedMessages.removeLast();
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

  Future<void> _discoverTopics() async {
    final service = context.read<RosbridgeService>();
    if (!service.connected) {
      _showSnackBar('请先连接服务器');
      return;
    }
    _showSnackBar('正在获取 Topic 列表…');
    List<String> topics;
    try {
      topics = await service.getTopics();
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('发现失败'),
          content: Text('$e'),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('确定'))],
        ),
      );
      return;
    }
    if (!mounted) return;
    if (topics.isEmpty) {
      _showSnackBar('未发现可用 Topic');
      return;
    }
    topics.sort();
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _TopicDiscoveryDialog(topics: topics),
    );
    if (selected != null && mounted) {
      _topicController.text = selected;
      final type = await service.getTopicType(selected);
      if (type.isNotEmpty && mounted) {
        _typeController.text = type;
      }
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return SingleChildScrollView(
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
                      TextButton.icon(
                        onPressed: _discoverTopics,
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('发现'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: HistoryTextField(
                          controller: _topicController,
                          category: HistoryService.topicCategory,
                          fieldKey: 'topic',
                          decoration: const InputDecoration(
                            labelText: 'Topic',
                            hintText: '/chatter',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onEntrySelected: (fields) {
                            _topicController.text = fields['topic'] ?? '';
                            _typeController.text = fields['type'] ?? '';
                            if (fields.containsKey('msg')) {
                              _msgController.text = fields['msg']!;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: HistoryTextField(
                          controller: _typeController,
                          category: HistoryService.topicCategory,
                          fieldKey: 'type',
                          decoration: const InputDecoration(
                            labelText: '消息类型',
                            hintText: 'std_msgs/String',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onEntrySelected: (fields) {
                            _topicController.text = fields['topic'] ?? '';
                            _typeController.text = fields['type'] ?? '';
                            if (fields.containsKey('msg')) {
                              _msgController.text = fields['msg']!;
                            }
                          },
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
          SizedBox(
            height: 350,
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

class _TopicDiscoveryDialog extends StatefulWidget {
  final List<String> topics;
  const _TopicDiscoveryDialog({required this.topics});

  @override
  State<_TopicDiscoveryDialog> createState() => _TopicDiscoveryDialogState();
}

class _TopicDiscoveryDialogState extends State<_TopicDiscoveryDialog> {
  final _searchController = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.topics;
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.topics
          : widget.topics.where((t) => t.toLowerCase().contains(query)).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('可用 Topics (${widget.topics.length})'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '搜索 Topic…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text('无匹配结果'))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        return ListTile(
                          dense: true,
                          title: Text(_filtered[i], style: const TextStyle(fontSize: 13)),
                          leading: const Icon(Icons.topic, size: 18),
                          onTap: () => Navigator.of(ctx).pop(_filtered[i]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
      ],
    );
  }
}
