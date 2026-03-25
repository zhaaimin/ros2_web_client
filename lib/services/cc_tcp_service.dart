import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum CcConnectionState {
  disconnected,
  connecting,
  authenticating,
  connected,
}

class CcTcpService extends ChangeNotifier {
  Socket? _socket;
  CcConnectionState _state = CcConnectionState.disconnected;
  String _statusMessage = '未连接';
  final List<String> _logs = [];
  final List<String> _receivedMessages = [];

  // Auth state
  String? _apiId;
  String? _token;

  // Heartbeat
  Timer? _heartbeatTimer;
  int _heartbeatMissCount = 0;
  int _heartbeatId = 0;
  final Set<int> _pendingHeartbeatIds = {};
  static const Duration _heartbeatInterval = Duration(seconds: 10);

  // Buffer for incomplete TCP data
  String _buffer = '';

  CcConnectionState get state => _state;
  String get statusMessage => _statusMessage;
  List<String> get logs => List.unmodifiable(_logs);
  List<String> get receivedMessages => List.unmodifiable(_receivedMessages);
  bool get isConnected => _state == CcConnectionState.connected;

  Future<void> connect({
    required String host,
    required int port,
    String apiId = '',
    String token = '',
  }) async {
    if (_state != CcConnectionState.disconnected) {
      disconnect();
    }

    _apiId = apiId;
    _token = token;
    _buffer = '';
    _heartbeatMissCount = 0;
    _heartbeatId = 0;
    _pendingHeartbeatIds.clear();

    _setState(CcConnectionState.connecting);
    _addLog('正在连接 $host:$port ...');

    try {
      _socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 10));
      _addLog('TCP 连接已建立');

      _socket!.listen(
        _onData,
        onError: (error) {
          _addLog('Socket 错误: $error');
          disconnect();
        },
        onDone: () {
          _addLog('连接已关闭');
          disconnect();
        },
      );

      // Start auth flow or go directly to connected
      if (apiId.isNotEmpty && token.isNotEmpty) {
        _setState(CcConnectionState.authenticating);
        _sendHi();
      } else {
        _addLog('无认证信息，以原始 TCP 模式连接');
        _setState(CcConnectionState.connected);
      }
    } catch (e) {
      _addLog('连接失败: $e');
      _setState(CcConnectionState.disconnected);
      _statusMessage = '连接失败: $e';
      notifyListeners();
    }
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _socket?.destroy();
    _socket = null;
    _buffer = '';
    _heartbeatMissCount = 0;
    if (_state != CcConnectionState.disconnected) {
      _setState(CcConnectionState.disconnected);
      _addLog('已断开连接');
    }
  }

  void sendMessage(String message) {
    if (_state != CcConnectionState.connected || _socket == null) {
      _addLog('未连接，无法发送');
      return;
    }
    _sendRaw(message);
    _addLog('→ $message');
  }

  void sendJsonRpc(String method, {Map<String, dynamic>? params, dynamic id}) {
    final msg = <String, dynamic>{
      'jsonrpc': '2.0',
      'method': method,
    };
    if (params != null) msg['params'] = params;
    if (id != null) msg['id'] = id;
    sendMessage(jsonEncode(msg));
  }

  // --- Auth Flow ---

  void _sendHi() {
    final msg = jsonEncode({
      'api_id': _apiId,
      'auth': {'token': _token},
      'proto_version': '1.0.0',
    });
    _sendRaw(msg);
    _addLog('→ [认证] 发送 hi 请求 api_id=$_apiId');
  }

  void _handleAuthResponse(Map<String, dynamic> data) {
    final method = data['method'] as String?;
    if (method == 'cc.api.accept') {
      _addLog('← [认证成功] CC 接受连接');
      final params = data['params'] as Map<String, dynamic>?;
      if (params != null) {
        _addLog('  proto_version: ${params['proto_version']}');
      }
      _setState(CcConnectionState.connected);
      _startHeartbeat();
    } else if (method == 'cc.api.reject') {
      final reason = data['message'] as String? ?? '未知原因';
      _addLog('← [认证失败] CC 拒绝连接: $reason');
      _statusMessage = '认证被拒绝: $reason';
      disconnect();
    } else {
      _addLog('← [未知认证响应] ${jsonEncode(data)}');
    }
  }

  // --- Heartbeat ---

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatMissCount = 0;

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_state != CcConnectionState.connected) {
        _heartbeatTimer?.cancel();
        return;
      }

      _heartbeatMissCount++;
      if (_heartbeatMissCount >= 2) {
        _addLog('心跳超时 (连续$_heartbeatMissCount次无响应)，断开连接');
        disconnect();
        return;
      }

      _heartbeatId++;
      _pendingHeartbeatIds.add(_heartbeatId);
      final heartbeat = jsonEncode({
        'jsonrpc': '2.0',
        'id': _heartbeatId,
        'method': 'cc.api.hb',
      });
      _sendRaw(heartbeat);
      _addLog('→ [心跳] id=$_heartbeatId');
    });
  }

  void _onHeartbeatResponse(int id) {
    _heartbeatMissCount = 0;
    _addLog('← [心跳响应] id=$id');
  }

  // --- Data Handling ---

  void _onData(List<int> data) {
    final text = utf8.decode(data, allowMalformed: true);
    _addLog('← [收到 ${data.length} 字节] $text');
    _buffer += text;

    // Try to parse complete JSON objects from buffer
    while (_buffer.isNotEmpty) {
      _buffer = _buffer.trimLeft();
      if (_buffer.isEmpty) break;

      // Find JSON boundary
      if (_buffer.startsWith('{')) {
        final endIndex = _findJsonEnd(_buffer);
        if (endIndex == -1) break; // Incomplete JSON, wait for more data

        final jsonStr = _buffer.substring(0, endIndex + 1);
        _buffer = _buffer.substring(endIndex + 1);

        try {
          final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
          _onJsonReceived(parsed, jsonStr);
        } catch (e) {
          _addLog('JSON 解析错误: $e, 原始数据: $jsonStr');
        }
      } else {
        // Non-JSON data, find next { or consume all
        final nextBrace = _buffer.indexOf('{');
        if (nextBrace == -1) {
          _addLog('← [原始数据] $_buffer');
          _buffer = '';
        } else {
          final nonJson = _buffer.substring(0, nextBrace);
          _addLog('← [原始数据] $nonJson');
          _buffer = _buffer.substring(nextBrace);
        }
      }
    }
  }

  int _findJsonEnd(String text) {
    if (!text.startsWith('{')) return -1;
    int depth = 0;
    bool inString = false;
    bool escape = false;

    for (int i = 0; i < text.length; i++) {
      final c = text[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (c == '\\' && inString) {
        escape = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1; // Incomplete
  }

  void _onJsonReceived(Map<String, dynamic> data, String raw) {
    if (_state == CcConnectionState.authenticating) {
      _handleAuthResponse(data);
      return;
    }

    // Connected state - handle messages
    final method = data['method'] as String?;
    if (method == 'cc.api.accept') {
      _handleAuthResponse(data);
      return;
    }
    if (method == 'cc.api.reject') {
      _handleAuthResponse(data);
      return;
    }

    // Heartbeat response: {jsonrpc: "2.0", id: <number>} matching a pending heartbeat id
    if (method == null && data.containsKey('id') && data['jsonrpc'] == '2.0') {
      final id = data['id'];
      if (id is int && _pendingHeartbeatIds.contains(id)) {
        _pendingHeartbeatIds.remove(id);
        _onHeartbeatResponse(id);
        return;
      }
    }

    _handleMessage(data);
  }

  void _handleMessage(Map<String, dynamic> data) {
    final formatted = const JsonEncoder.withIndent('  ').convert(data);
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    _receivedMessages.insert(0, '[$ts]\n$formatted');
    if (_receivedMessages.length > 50) _receivedMessages.removeLast();
    _addLog('← ${jsonEncode(data)}');
    notifyListeners();
  }

  // --- Helpers ---

  void _sendRaw(String message) {
    try {
      _socket?.write(message);
    } catch (e) {
      _addLog('发送失败: $e');
    }
  }

  void _setState(CcConnectionState newState) {
    _state = newState;
    switch (newState) {
      case CcConnectionState.disconnected:
        _statusMessage = '未连接';
      case CcConnectionState.connecting:
        _statusMessage = '正在连接...';
      case CcConnectionState.authenticating:
        _statusMessage = '正在认证...';
      case CcConnectionState.connected:
        _statusMessage = '已连接 (已认证)';
    }
    notifyListeners();
  }

  void _addLog(String msg) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    _logs.insert(0, '[$ts] $msg');
    if (_logs.length > 500) _logs.removeLast();
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void clearMessages() {
    _receivedMessages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
