import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cc_tcp_service.dart';
import '../services/history_service.dart';
import '../widgets/history_selector.dart';

class CcTcpTab extends StatefulWidget {
  const CcTcpTab({super.key});

  @override
  State<CcTcpTab> createState() => _CcTcpTabState();
}

class _CcTcpTabState extends State<CcTcpTab> with AutomaticKeepAliveClientMixin {
  final _hostController = TextEditingController(text: '192.168.11.3');
  final _portController = TextEditingController(text: '51000');
  final _apiIdController = TextEditingController(text: 'walker.ae');
  final _tokenController = TextEditingController();
  final _msgController = TextEditingController();

  static const String historyCategory = 'cc_tcp';

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _apiIdController.dispose();
    _tokenController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _connect() {
    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    final apiId = _apiIdController.text.trim();
    final token = _tokenController.text.trim();

    if (host.isEmpty || portStr.isEmpty) {
      _showSnackBar('请输入主机地址和端口');
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null) {
      _showSnackBar('端口号无效');
      return;
    }

    // Save connection info to history
    context.read<HistoryService>().addEntry(
      historyCategory,
      HistoryEntry(fields: {
        'host': host,
        'port': portStr,
        'api_id': apiId,
        'token': token,
      }),
    );

    context.read<CcTcpService>().connect(
      host: host,
      port: port,
      apiId: apiId,
      token: token,
    );
  }

  void _disconnect() {
    context.read<CcTcpService>().disconnect();
  }

  void _sendMessage() {
    final msg = _msgController.text.trim();
    if (msg.isEmpty) {
      _showSnackBar('请输入要发送的消息');
      return;
    }
    context.read<CcTcpService>().sendMessage(msg);
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
    final service = context.watch<CcTcpService>();
    final isConnected = service.state == CcConnectionState.connected;
    final isDisconnected = service.state == CcConnectionState.disconnected;

    return Padding(
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
                  Row(
                    children: [
                      Text('CC TCP 客户端', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      HistorySelector(
                        category: historyCategory,
                        onSelect: (fields) {
                          _hostController.text = fields['host'] ?? '';
                          _portController.text = fields['port'] ?? '';
                          _apiIdController.text = fields['api_id'] ?? '';
                          if (fields.containsKey('token')) {
                            _tokenController.text = fields['token']!;
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: '主机地址',
                            hintText: '192.168.11.3',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          enabled: isDisconnected,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: '端口',
                            hintText: '51000',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          enabled: isDisconnected,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _apiIdController,
                          decoration: const InputDecoration(
                            labelText: 'API ID',
                            hintText: 'walker.ae',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          enabled: isDisconnected,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _tokenController,
                          decoration: const InputDecoration(
                            labelText: 'Token',
                            hintText: '输入 Token',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          obscureText: true,
                          enabled: isDisconnected,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: isDisconnected ? _connect : _disconnect,
                        icon: Icon(isDisconnected ? Icons.link : Icons.link_off),
                        label: Text(isDisconnected ? '连接' : '断开'),
                        style: FilledButton.styleFrom(
                          backgroundColor: isDisconnected ? null : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        isConnected ? Icons.circle : Icons.circle_outlined,
                        color: isConnected
                            ? Colors.green
                            : service.state == CcConnectionState.authenticating
                                ? Colors.orange
                                : Colors.grey,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          service.statusMessage,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isConnected
                                ? Colors.green
                                : service.state == CcConnectionState.authenticating
                                    ? Colors.orange
                                    : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isConnected) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _msgController,
                            decoration: const InputDecoration(
                              labelText: '发送数据 (JSON)',
                              hintText: '{"jsonrpc":"2.0","method":"...","params":{}}',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            maxLines: 2,
                            minLines: 1,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send),
                          label: const Text('发送'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Messages section
          Row(
            children: [
              Text('收到的消息 (${service.receivedMessages.length})',
                  style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () => service.clearMessages(),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('清空', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            flex: 2,
            child: Card(
              color: const Color(0xFF1E1E1E),
              child: service.receivedMessages.isEmpty
                  ? const Center(
                      child: Text('暂无消息', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: service.receivedMessages.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: SelectableText(
                            service.receivedMessages[index],
                            style: const TextStyle(
                              fontFamily: 'Menlo',
                              fontSize: 11,
                              color: Colors.greenAccent,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // Log section
          Row(
            children: [
              Text('连接日志 (${service.logs.length})', style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () => service.clearLogs(),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('清空', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            flex: 1,
            child: Card(
              color: const Color(0xFF1E1E1E),
              child: service.logs.isEmpty
                  ? const Center(
                      child: Text('暂无日志', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: service.logs.length,
                      itemBuilder: (context, index) {
                        final log = service.logs[index];
                        final isOutgoing = log.contains('→');
                        final isIncoming = log.contains('←');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: SelectableText(
                            log,
                            style: TextStyle(
                              fontFamily: 'Menlo',
                              fontSize: 11,
                              color: isIncoming
                                  ? Colors.greenAccent
                                  : isOutgoing
                                      ? Colors.cyanAccent
                                      : Colors.white70,
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
