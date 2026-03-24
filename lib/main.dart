import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/rosbridge_service.dart';
import 'services/history_service.dart';
import 'screens/connection_tab.dart';
import 'screens/topic_tab.dart';
import 'screens/service_tab.dart';
import 'screens/action_tab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final historyService = HistoryService();
  await historyService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RosbridgeService()),
        ChangeNotifierProvider.value(value: historyService),
      ],
      child: const RosBridgeApp(),
    ),
  );
}

class RosBridgeApp extends StatelessWidget {
  const RosBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROS Bridge Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.dark,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final connected = context.select<RosbridgeService, bool>((s) => s.connected);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.router, size: 24),
              const SizedBox(width: 8),
              const Text('ROS Bridge Client'),
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
