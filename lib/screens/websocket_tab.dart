import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/history_service.dart';
import '../widgets/history_selector.dart';
import 'package:provider/provider.dart';

class WebSocketTab extends StatefulWidget {
  const WebSocketTab({super.key});

  @override
  State<WebSocketTab> createState() => _WebSocketTabState();
}

class _WebSocketTabState extends State<WebSocketTab> with AutomaticKeepAliveClientMixin {
  final _urlController = TextEditingController(text: 'ws://localhost:8080');
  final _msgController = TextEditingController();
  final List<_WsMessage> _messages = [];
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _connected = false;
  String _statusMessage = '未连接';
  final List<String> _logs = [];

  static String get historyCategory => HistoryService.websocketCategory;

  @override
  void dispose() {
    _disconnect();
    _urlController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('请输入 WebSocket URL');
      return;
    }
    _disconnect();
    try {
      _addLog('开始连接 $url');
      setState(() {
        _statusMessage = '正在连接 $url …';
      });
      final uri = Uri.parse(url);
      _addLog('解析 URI: $uri');
      _channel = WebSocketChannel.connect(uri);
      _addLog('等待 WebSocket ready...');
      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('连接超时 (10秒)');
        },
      );
      _addLog('连接成功');

      setState(() {
        _connected = true;
        _statusMessage = '已连接 $url';
      });

      _subscription = _channel!.stream.listen(
        (data) {
          if (!mounted) return;
          _addLog('← 收到数据 (${data.toString().length} 字符)');
          setState(() {
            _messages.insert(0, _WsMessage(
              direction: _MsgDirection.received,
              content: data.toString(),
              time: DateTime.now(),
            ));
            if (_messages.length > 100) _messages.removeLast();
          });
        },
        onError: (error) {
          if (!mounted) return;
          _addLog('错误: $error');
          setState(() {
            _connected = false;
            _statusMessage = '连接错误: $error';
          });
        },
        onDone: () {
          if (!mounted) return;
          _addLog('连接关闭');
          setState(() {
            _connected = false;
            _statusMessage = '连接已关闭';
          });
        },
      );
    } catch (e) {
      _addLog('连接失败: $e');
      // Clean up on failure
      _subscription?.cancel();
      _subscription = null;
      _channel?.sink.close();
      _channel = null;
      setState(() {
        _connected = false;
        _statusMessage = '连接失败: $e';
      });
    }
  }

  void _disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    if (_connected) {
      setState(() {
        _connected = false;
        _statusMessage = '已断开';
      });
    }
  }

  void _sendMessage() {
    if (!_connected || _channel == null) {
      _showSnackBar('请先连接 WebSocket 服务器');
      return;
    }
    final msg = _msgController.text.trim();
    if (msg.isEmpty) {
      _showSnackBar('请输入要发送的消息');
      return;
    }
    _channel!.sink.add(msg);
    setState(() {
      _messages.insert(0, _WsMessage(
        direction: _MsgDirection.sent,
        content: msg,
        time: DateTime.now(),
      ));
      if (_messages.length > 100) _messages.removeLast();
    });
    // Save to history
    context.read<HistoryService>().addEntry(
      historyCategory,
      HistoryEntry(fields: {
        'url': _urlController.text.trim(),
        'msg': msg,
      }),
    );
  }

  void _addLog(String msg) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    setState(() {
      _logs.insert(0, '[$ts] $msg');
      if (_logs.length > 200) _logs.removeLast();
    });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
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
          // Connection card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WebSocket 测试', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: HistoryTextField(
                          controller: _urlController,
                          category: historyCategory,
                          fieldKey: 'url',
                          decoration: const InputDecoration(
                            labelText: 'WebSocket URL',
                            hintText: 'ws://192.168.1.100:8080',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                            isDense: true,
                          ),
                          enabled: !_connected,
                          onEntrySelected: (fields) {
                            _urlController.text = fields['url'] ?? '';
                            if (fields.containsKey('msg')) {
                              _msgController.text = fields['msg']!;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          if (_connected) {
                            _disconnect();
                          } else {
                            _connect();
                          }
                        },
                        icon: Icon(_connected ? Icons.link_off : Icons.link),
                        label: Text(_connected ? '断开' : '连接'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _connected ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _connected ? Icons.circle : Icons.circle_outlined,
                        color: _connected ? Colors.green : Colors.grey,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _connected ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: HistoryTextField(
                          controller: _msgController,
                          category: historyCategory,
                          fieldKey: 'msg',
                          decoration: const InputDecoration(
                            labelText: '发送数据',
                            hintText: '输入要发送的消息',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 3,
                          minLines: 1,
                          onSubmitted: (_) => _sendMessage(),
                          onEntrySelected: (fields) {
                            _urlController.text = fields['url'] ?? '';
                            _msgController.text = fields['msg'] ?? '';
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _connected ? _sendMessage : null,
                        icon: const Icon(Icons.send),
                        label: const Text('发送'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('消息记录 (${_messages.length})', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _messages.clear()),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: Card(
              color: const Color(0xFF1E1E1E),
              child: _messages.isEmpty
                  ? const Center(
                      child: Text('暂无消息', style: TextStyle(color: Colors.white38)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isSent = msg.direction == _MsgDirection.sent;
                        final ts = msg.time.toIso8601String().substring(11, 23);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isSent ? Icons.arrow_upward : Icons.arrow_downward,
                                    size: 14,
                                    color: isSent ? Colors.cyanAccent : Colors.greenAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${isSent ? "发送" : "收到"} $ts',
                                    style: TextStyle(
                                      fontFamily: 'Menlo',
                                      fontSize: 11,
                                      color: isSent ? Colors.cyanAccent.withValues(alpha: 0.7) : Colors.greenAccent.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              SelectableText(
                                msg.content,
                                style: TextStyle(
                                  fontFamily: 'Menlo',
                                  fontSize: 12,
                                  color: isSent ? Colors.cyanAccent : Colors.greenAccent,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('连接日志 (${_logs.length})', style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _logs.clear()),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('清空', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 200,
            child: Card(
              color: const Color(0xFF1E1E1E),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text('暂无日志', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                              fontFamily: 'Menlo',
                              fontSize: 11,
                              color: Colors.white70,
                            ),
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

enum _MsgDirection { sent, received }

class _WsMessage {
  final _MsgDirection direction;
  final String content;
  final DateTime time;

  _WsMessage({required this.direction, required this.content, required this.time});
}
