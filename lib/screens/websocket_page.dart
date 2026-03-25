import 'package:flutter/material.dart';
import 'websocket_tab.dart';

class WebSocketPage extends StatelessWidget {
  const WebSocketPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.electrical_services, size: 24),
            SizedBox(width: 8),
            Text('WebSocket 测试'),
          ],
        ),
      ),
      body: const WebSocketTab(),
    );
  }
}
