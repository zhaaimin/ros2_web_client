import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ros_bridge_client/main.dart';
import 'package:ros_bridge_client/services/rosbridge_service.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => RosbridgeService(),
        child: const RosBridgeApp(),
      ),
    );
    expect(find.text('ROS Bridge Client'), findsOneWidget);
  });
}
