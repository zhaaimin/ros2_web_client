import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rosbridge_service.dart';
import '../services/history_service.dart';
import '../widgets/history_selector.dart';

class ServiceTab extends StatefulWidget {
  const ServiceTab({super.key});

  @override
  State<ServiceTab> createState() => _ServiceTabState();
}

class _ServiceTabState extends State<ServiceTab> with AutomaticKeepAliveClientMixin {
  final _serviceController = TextEditingController(text: '/rosapi/get_param');
  final _typeController = TextEditingController(text: 'rosapi/GetParam');
  final _argsController = TextEditingController(text: '{"name": "/rosdistro"}');
  String? _response;
  bool _loading = false;

  @override
  void dispose() {
    _serviceController.dispose();
    _typeController.dispose();
    _argsController.dispose();
    super.dispose();
  }

  Future<void> _callService() async {
    final service = context.read<RosbridgeService>();
    if (!service.connected) {
      _showSnackBar('请先连接服务器');
      return;
    }

    final serviceName = _serviceController.text.trim();
    final type = _typeController.text.trim();
    final argsStr = _argsController.text.trim();

    if (serviceName.isEmpty) {
      _showSnackBar('请输入 Service 名称');
      return;
    }

    Map<String, dynamic> args = {};
    if (argsStr.isNotEmpty) {
      try {
        args = jsonDecode(argsStr) as Map<String, dynamic>;
      } catch (e) {
        _showSnackBar('JSON 格式错误: $e');
        return;
      }
    }

    setState(() {
      _loading = true;
      _response = null;
    });

    try {
      final result = await service.callService(serviceName, type: type, args: args);
      // Save to history
      if (mounted) {
        context.read<HistoryService>().addEntry(
          HistoryService.serviceCategory,
          HistoryEntry(fields: {
            'service': serviceName,
            'type': type,
            'args': argsStr,
          }),
        );
      }
      setState(() {
        _response = const JsonEncoder.withIndent('  ').convert(result);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _response = '错误: $e';
        _loading = false;
      });
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Service 调用', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: HistoryTextField(
                          controller: _serviceController,
                          category: HistoryService.serviceCategory,
                          fieldKey: 'service',
                          decoration: const InputDecoration(
                            labelText: 'Service 名称',
                            hintText: '/rosapi/get_param',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onEntrySelected: (fields) {
                            _serviceController.text = fields['service'] ?? '';
                            _typeController.text = fields['type'] ?? '';
                            if (fields.containsKey('args')) {
                              _argsController.text = fields['args']!;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: HistoryTextField(
                          controller: _typeController,
                          category: HistoryService.serviceCategory,
                          fieldKey: 'type',
                          decoration: const InputDecoration(
                            labelText: 'Service 类型 (可选)',
                            hintText: 'rosapi/GetParam',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onEntrySelected: (fields) {
                            _serviceController.text = fields['service'] ?? '';
                            _typeController.text = fields['type'] ?? '';
                            if (fields.containsKey('args')) {
                              _argsController.text = fields['args']!;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  HistoryTextField(
                    controller: _argsController,
                    category: HistoryService.serviceCategory,
                    fieldKey: 'args',
                    decoration: const InputDecoration(
                      labelText: '请求参数 (JSON)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 3,
                    onEntrySelected: (fields) {
                      _serviceController.text = fields['service'] ?? '';
                      _typeController.text = fields['type'] ?? '';
                      if (fields.containsKey('args')) {
                        _argsController.text = fields['args']!;
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _callService,
                    icon: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow),
                    label: Text(_loading ? '调用中…' : '调用 Service'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('响应结果', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 350,
            child: Card(
              color: const Color(0xFF1E1E1E),
              child: _response == null
                  ? const Center(
                      child: Text('点击"调用 Service"查看结果', style: TextStyle(color: Colors.white38)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        _response!,
                        style: TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 13,
                          color: _response!.startsWith('错误') ? Colors.redAccent : Colors.greenAccent,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
