import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Service for communicating with a rosbridge_websocket server.
class RosbridgeService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String _url = 'ws://localhost:9090';
  bool _connected = false;
  String _statusMessage = '未连接';
  final List<String> _logs = [];
  int _idCounter = 0;

  // Callbacks for topic subscriptions
  final Map<String, List<void Function(Map<String, dynamic>)>> _topicCallbacks = {};
  // Track subscription id -> topic for better management
  final Map<String, String> _subscriptionIds = {};
  // Status messages from rosbridge
  final List<String> _statusMessages = [];
  // Callbacks for service responses
  final Map<String, Completer<Map<String, dynamic>>> _serviceCompleters = {};
  // Callbacks for action feedback/result
  final Map<String, void Function(Map<String, dynamic>)> _actionFeedbackCallbacks = {};
  final Map<String, Completer<Map<String, dynamic>>> _actionResultCompleters = {};

  String get url => _url;
  bool get connected => _connected;
  String get statusMessage => _statusMessage;
  List<String> get logs => List.unmodifiable(_logs);

  String _nextId() => 'id_${_idCounter++}';

  void _addLog(String msg) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _logs.add('[$timestamp] $msg');
    if (_logs.length > 500) _logs.removeRange(0, _logs.length - 500);
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// Connect to rosbridge server at the given URL.
  Future<void> connect(String url) async {
    _url = url;
    disconnect();
    try {
      _statusMessage = '正在连接 $url …';
      _addLog('连接 $url');
      notifyListeners();

      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _connected = true;
      _statusMessage = '已连接 $url';
      _addLog('连接成功');
      notifyListeners();

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          _addLog('WebSocket 错误: $error');
          _setDisconnected('连接错误: $error');
        },
        onDone: () {
          _addLog('WebSocket 已关闭');
          _setDisconnected('连接已关闭');
        },
      );
    } catch (e) {
      _addLog('连接失败: $e');
      _setDisconnected('连接失败: $e');
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    if (_connected) {
      _setDisconnected('已断开');
    }
  }

  void _setDisconnected(String msg) {
    _connected = false;
    _statusMessage = msg;
    _topicCallbacks.clear();
    _subscriptionIds.clear();
    _statusMessages.clear();
    _serviceCompleters.clear();
    _actionFeedbackCallbacks.clear();
    _actionResultCompleters.clear();
    notifyListeners();
  }

  void _send(Map<String, dynamic> msg) {
    if (!_connected || _channel == null) {
      _addLog('发送失败: 未连接');
      return;
    }
    final json = jsonEncode(msg);
    _channel!.sink.add(json);
    _addLog('→ ${_truncate(json, 200)}');
  }

  void _onMessage(dynamic rawMsg) {
    final str = rawMsg.toString();
    _addLog('← ${_truncate(str, 200)}');
    try {
      final msg = jsonDecode(str) as Map<String, dynamic>;
      final op = msg['op'] as String?;

      switch (op) {
        case 'publish':
          _handleTopicMessage(msg);
          break;
        case 'service_response':
          _handleServiceResponse(msg);
          break;
        case 'action_feedback':
          _handleActionFeedback(msg);
          break;
        case 'action_result':
          _handleActionResult(msg);
          break;
        case 'status':
          _handleStatus(msg);
          break;
        default:
          _addLog('未处理的 op: $op');
          break;
      }
    } catch (e) {
      _addLog('解析消息失败: $e');
    }
  }

  // ── Topics ────────────────────────────────────────────────────────────────

  /// Subscribe to a topic.
  void subscribe(
    String topic,
    String type,
    void Function(Map<String, dynamic>) callback, {
    int throttleRate = 0,
    int queueLength = 1,
  }) {
    final id = _nextId();
    _topicCallbacks.putIfAbsent(topic, () => []).add(callback);
    _subscriptionIds[id] = topic;
    final msg = <String, dynamic>{
      'op': 'subscribe',
      'id': id,
      'topic': topic,
      'type': type,
    };
    if (throttleRate > 0) msg['throttle_rate'] = throttleRate;
    if (queueLength > 0) msg['queue_length'] = queueLength;
    _send(msg);
    _addLog('订阅 topic: $topic ($type) [id=$id]');
  }

  /// Unsubscribe from a topic.
  void unsubscribe(String topic) {
    _topicCallbacks.remove(topic);
    _send({
      'op': 'unsubscribe',
      'topic': topic,
    });
    _addLog('取消订阅 topic: $topic');
  }

  /// Publish a message to a topic.
  void publish(String topic, String type, Map<String, dynamic> msg) {
    _send({
      'op': 'publish',
      'topic': topic,
      'type': type,
      'msg': msg,
    });
  }

  void _handleTopicMessage(Map<String, dynamic> msg) {
    final topic = msg['topic'] as String?;
    if (topic != null && _topicCallbacks.containsKey(topic)) {
      final raw = msg['msg'];
      final data = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
      for (final cb in _topicCallbacks[topic]!) {
        cb(data);
      }
    } else {
      _addLog('收到未订阅的 topic 消息: $topic');
    }
  }

  void _handleStatus(Map<String, dynamic> msg) {
    final level = msg['level'] as String? ?? 'info';
    final statusMsg = msg['msg'] as String? ?? '';
    final id = msg['id'] as String?;
    final topicInfo = id != null && _subscriptionIds.containsKey(id)
        ? ' [topic: ${_subscriptionIds[id]}]'
        : '';
    _statusMessages.add('[$level]$topicInfo $statusMsg');
    _addLog('rosbridge 状态 [$level]$topicInfo: $statusMsg');
    if (_statusMessages.length > 50) _statusMessages.removeAt(0);
  }

  /// Unsubscribe from all active topics.
  void unsubscribeAll() {
    final topics = _topicCallbacks.keys.toList();
    for (final topic in topics) {
      unsubscribe(topic);
    }
    _addLog('已取消所有 topic 订阅 (${topics.length} 个)');
  }

  /// Cancel all pending action goals and clear callbacks.
  void cancelAllActions() {
    final pendingCount = _actionResultCompleters.length;
    _actionFeedbackCallbacks.clear();
    for (final completer in _actionResultCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError('页面退出，已取消');
      }
    }
    _actionResultCompleters.clear();
    if (pendingCount > 0) {
      _addLog('已取消所有待处理 action ($pendingCount 个)');
    }
  }

  /// Clean up all subscriptions and pending operations (called when leaving the page).
  void cleanupAll() {
    unsubscribeAll();
    cancelAllActions();
  }

  // ── Services ──────────────────────────────────────────────────────────────

  /// Call a ROS service.
  Future<Map<String, dynamic>> callService(
    String service, {
    String type = '',
    Map<String, dynamic> args = const {},
  }) async {
    final id = _nextId();
    final completer = Completer<Map<String, dynamic>>();
    _serviceCompleters[id] = completer;

    _send({
      'op': 'call_service',
      'id': id,
      'service': service,
      'type': type.isNotEmpty ? type : null,
      'args': args,
    });

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _serviceCompleters.remove(id);
        throw TimeoutException('Service call timeout: $service');
      },
    );
  }

  void _handleServiceResponse(Map<String, dynamic> msg) {
    final id = msg['id'] as String?;
    if (id != null && _serviceCompleters.containsKey(id)) {
      final completer = _serviceCompleters.remove(id)!;
      final result = msg['values'] as Map<String, dynamic>? ?? msg;
      final success = msg['result'] as bool? ?? true;
      if (success) {
        completer.complete(result);
      } else {
        completer.completeError('Service call failed: ${msg['values']}');
      }
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Send an action goal.
  Future<Map<String, dynamic>> sendActionGoal(
    String actionName,
    String actionType,
    Map<String, dynamic> goal, {
    void Function(Map<String, dynamic>)? onFeedback,
  }) async {
    final id = _nextId();
    final completer = Completer<Map<String, dynamic>>();
    _actionResultCompleters[id] = completer;
    if (onFeedback != null) {
      _actionFeedbackCallbacks[id] = onFeedback;
    }

    _send({
      'op': 'send_action_goal',
      'id': id,
      'action': actionName,
      'action_type': actionType,
      'args': goal,
    });

    return completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        _actionResultCompleters.remove(id);
        _actionFeedbackCallbacks.remove(id);
        throw TimeoutException('Action goal timeout: $actionName');
      },
    );
  }

  /// Cancel an action goal.
  void cancelActionGoal(String actionName) {
    _send({
      'op': 'cancel_action_goal',
      'action': actionName,
    });
    _addLog('取消 action: $actionName');
  }

  void _handleActionFeedback(Map<String, dynamic> msg) {
    final id = msg['id'] as String?;
    if (id != null && _actionFeedbackCallbacks.containsKey(id)) {
      _actionFeedbackCallbacks[id]!(msg['values'] as Map<String, dynamic>? ?? msg);
    }
  }

  void _handleActionResult(Map<String, dynamic> msg) {
    final id = msg['id'] as String?;
    if (id != null && _actionResultCompleters.containsKey(id)) {
      final completer = _actionResultCompleters.remove(id)!;
      _actionFeedbackCallbacks.remove(id);
      completer.complete(msg['values'] as Map<String, dynamic>? ?? msg);
    }
  }

  // ── Discovery (rosapi) ──────────────────────────────────────────────────
  //
  // 需要 rosapi 节点运行才能使用自动发现功能：
  //   ros2 launch rosbridge_server rosbridge_websocket_launch.xml
  // 或单独启动：
  //   ros2 run rosapi rosapi_node

  static const _discoveryTimeout = Duration(seconds: 5);
  static const _rosApiHint = '请确保 rosapi 节点已启动:\n'
      '  ros2 launch rosbridge_server rosbridge_websocket_launch.xml\n'
      '或: ros2 run rosapi rosapi_node';

  /// Get all available topics via /rosapi/topics.
  /// Throws [String] on failure with user-friendly message.
  Future<List<String>> getTopics() async {
    try {
      final result = await callService('/rosapi/topics')
          .timeout(_discoveryTimeout);
      final topics = result['topics'];
      if (topics is List) {
        return topics.cast<String>();
      }
      return [];
    } on TimeoutException {
      _addLog('获取 topic 列表超时，rosapi 可能未运行');
      throw '请求超时，$_rosApiHint';
    } catch (e) {
      _addLog('获取 topic 列表失败: $e');
      throw '获取失败: $e\n\n$_rosApiHint';
    }
  }

  /// Get all available services via /rosapi/services.
  /// Throws [String] on failure with user-friendly message.
  Future<List<String>> getServices() async {
    try {
      final result = await callService('/rosapi/services')
          .timeout(_discoveryTimeout);
      final services = result['services'];
      if (services is List) {
        return services.cast<String>();
      }
      return [];
    } on TimeoutException {
      _addLog('获取 service 列表超时，rosapi 可能未运行');
      throw '请求超时，$_rosApiHint';
    } catch (e) {
      _addLog('获取 service 列表失败: $e');
      throw '获取失败: $e\n\n$_rosApiHint';
    }
  }

  /// Get the type of a specific topic via /rosapi/topic_type.
  Future<String> getTopicType(String topic) async {
    try {
      final result = await callService('/rosapi/topic_type', args: {'topic': topic})
          .timeout(_discoveryTimeout);
      return result['type'] as String? ?? '';
    } catch (e) {
      _addLog('获取 topic 类型失败: $e');
      return '';
    }
  }

  /// Get the type of a specific service via /rosapi/service_type.
  Future<String> getServiceType(String service) async {
    try {
      final result = await callService('/rosapi/service_type', args: {'service': service})
          .timeout(_discoveryTimeout);
      return result['type'] as String? ?? '';
    } catch (e) {
      _addLog('获取 service 类型失败: $e');
      return '';
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}…';
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
