import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utility for exporting logs.
class LogExport {
  /// Export logs to clipboard and show a snackbar.
  static void toClipboard(BuildContext context, List<String> logs, String source) {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有日志可导出'), duration: Duration(seconds: 2)),
      );
      return;
    }
    final header = '=== $source 日志导出 ===\n'
        '时间: ${DateTime.now().toIso8601String()}\n'
        '条数: ${logs.length}\n'
        '${'=' * 40}\n';
    final content = header + logs.join('\n');
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制 ${logs.length} 条日志到剪贴板'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Export logs to a file and show a snackbar with the path.
  static Future<void> toFile(BuildContext context, List<String> logs, String source) async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有日志可导出'), duration: Duration(seconds: 2)),
      );
      return;
    }
    final header = '=== $source 日志导出 ===\n'
        '时间: ${DateTime.now().toIso8601String()}\n'
        '条数: ${logs.length}\n'
        '${'=' * 40}\n';
    final content = header + logs.join('\n');

    try {
      final dir = Directory.systemTemp;
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final fileName = '${source}_$timestamp.log';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存到 ${file.path}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '复制路径',
              onPressed: () => Clipboard.setData(ClipboardData(text: file.path)),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  /// Show a bottom sheet with export options.
  static void showExportOptions(BuildContext context, List<String> logs, String source) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制到剪贴板'),
              onTap: () {
                Navigator.of(ctx).pop();
                toClipboard(context, logs, source);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save),
              title: const Text('保存到文件'),
              onTap: () {
                Navigator.of(ctx).pop();
                toFile(context, logs, source);
              },
            ),
          ],
        ),
      ),
    );
  }
}
