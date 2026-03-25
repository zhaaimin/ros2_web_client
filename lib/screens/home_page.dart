import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rosbridge_service.dart';
import '../services/cc_tcp_service.dart';
import 'rosbridge_page.dart';
import 'websocket_page.dart';
import 'cc_tcp_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rosbridgeConnected =
        context.select<RosbridgeService, bool>((s) => s.connected);
    final ccTcpState =
        context.select<CcTcpService, CcConnectionState>((s) => s.state);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Header
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.smart_toy, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Walker 助手', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        '机器人通信调试工具',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Text('服务入口', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
              const SizedBox(height: 16),
              // Service cards
              _ServiceCard(
                icon: Icons.hub,
                title: 'ROS 测试',
                subtitle: '通过 WebSocket 连接 ROS2，支持 Topic 订阅/发布、Service 调用、Action 目标发送。',
                gradient: const [Color(0xFF00BFA5), Color(0xFF26A69A)],
                connected: rosbridgeConnected,
                features: const ['Topic 订阅发布', 'Service 调用', 'Action 控制'],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RosbridgePage()),
                ),
              ),
              const SizedBox(height: 16),
              _ServiceCard(
                icon: Icons.electrical_services,
                title: 'WebSocket 测试',
                subtitle: '原始 WebSocket 通信调试，发送和接收自定义消息。',
                gradient: const [Color(0xFF5C6BC0), Color(0xFF3F51B5)],
                connected: false,
                features: const ['自由连接', '收发消息', '日志记录'],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WebSocketPage()),
                ),
              ),
              const SizedBox(height: 16),
              _ServiceCard(
                icon: Icons.terminal,
                title: 'CC TCP 客户端',
                subtitle: '连接 CC TCP 服务端，支持 Token 认证和 JSON-RPC 通信。',
                gradient: const [Color(0xFFFF7043), Color(0xFFE64A19)],
                connected: ccTcpState == CcConnectionState.connected,
                features: const ['Token 认证', 'JSON-RPC', '心跳维持'],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CcTcpPage()),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final bool connected;
  final List<String> features;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.connected,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon with gradient background
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradient[0].withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, size: 32, color: Colors.white),
              ),
              const SizedBox(width: 20),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: connected
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: connected ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                connected ? '已连接' : '未连接',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: connected ? Colors.green : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: features.map((f) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}
