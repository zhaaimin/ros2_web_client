import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rosbridge_service.dart';
import '../utils/log_export.dart';

class ConnectionTab extends StatefulWidget {
  const ConnectionTab({super.key});

  @override
  State<ConnectionTab> createState() => _ConnectionTabState();
}

class _ConnectionTabState extends State<ConnectionTab> with AutomaticKeepAliveClientMixin {
  final _urlController = TextEditingController(text: 'ws://localhost:9090');

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final service = context.watch<RosbridgeService>();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('连接设置', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: 'WebSocket URL',
                            hintText: 'ws://192.168.1.100:9090',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                          ),
                          enabled: !service.connected,
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () {
                          if (service.connected) {
                            service.disconnect();
                          } else {
                            service.connect(_urlController.text.trim());
                          }
                        },
                        icon: Icon(service.connected ? Icons.link_off : Icons.link),
                        label: Text(service.connected ? '断开' : '连接'),
                        style: FilledButton.styleFrom(
                          backgroundColor: service.connected ? Colors.red : null,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        service.connected ? Icons.circle : Icons.circle_outlined,
                        color: service.connected ? Colors.green : Colors.grey,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          service.statusMessage,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: service.connected ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Logs
          Row(
            children: [
              Text('通信日志', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => LogExport.showExportOptions(context, service.logs, 'rosbridge'),
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('导出'),
              ),
              TextButton.icon(
                onPressed: () => service.clearLogs(),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 350,
            child: Card(
              color: const Color(0xFF1E1E1E),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ListView.builder(
                  reverse: true,
                  itemCount: service.logs.length,
                  itemBuilder: (context, index) {
                    final logIndex = service.logs.length - 1 - index;
                    final log = service.logs[logIndex];
                    final isIncoming = log.contains('←');
                    final isOutgoing = log.contains('→');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: SelectableText(
                        log,
                        style: TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 12,
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
          ),
        ],
      ),
    );
  }
}
