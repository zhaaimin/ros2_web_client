import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rosbridge_service.dart';
import 'connection_tab.dart';
import 'topic_tab.dart';
import 'service_tab.dart';
import 'action_tab.dart';

class RosbridgePage extends StatelessWidget {
  const RosbridgePage({super.key});

  @override
  Widget build(BuildContext context) {
    final connected =
        context.select<RosbridgeService, bool>((s) => s.connected);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.hub, size: 24),
              const SizedBox(width: 8),
              const Text('ROS 测试'),
              const SizedBox(width: 12),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? Colors.greenAccent : Colors.grey,
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.link), text: '连接'),
              Tab(icon: Icon(Icons.topic), text: 'Topic'),
              Tab(icon: Icon(Icons.miscellaneous_services), text: 'Service'),
              Tab(icon: Icon(Icons.rocket_launch), text: 'Action'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ConnectionTab(),
            TopicTab(),
            ServiceTab(),
            ActionTab(),
          ],
        ),
      ),
    );
  }
}
