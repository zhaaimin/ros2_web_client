import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cc_tcp_service.dart';
import 'cc_tcp_tab.dart';

class CcTcpPage extends StatelessWidget {
  const CcTcpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ccState =
        context.select<CcTcpService, CcConnectionState>((s) => s.state);
    final isConnected = ccState == CcConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.terminal, size: 24),
            const SizedBox(width: 8),
            const Text('CC TCP 客户端'),
            const SizedBox(width: 12),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? Colors.greenAccent : Colors.grey,
              ),
            ),
          ],
        ),
      ),
      body: const CcTcpTab(),
    );
  }
}
