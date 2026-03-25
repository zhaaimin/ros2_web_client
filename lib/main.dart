import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/rosbridge_service.dart';
import 'services/history_service.dart';
import 'services/cc_tcp_service.dart';
import 'screens/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final historyService = HistoryService();
  await historyService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RosbridgeService()),
        ChangeNotifierProvider(create: (_) => CcTcpService()),
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
      title: 'Walker助手',
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
