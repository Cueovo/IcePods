import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:qqmusic_ipod/core/utils/device_display_metrics.dart';

/// Temporary on-device viewer for native scene/app lifecycle lines.
/// Used to determine whether Now Playing taps ever activate the process.
class WakeDiagScreen extends StatefulWidget {
  const WakeDiagScreen({super.key, this.initialLines = const []});

  final List<String> initialLines;

  @override
  State<WakeDiagScreen> createState() => _WakeDiagScreenState();
}

class _WakeDiagScreenState extends State<WakeDiagScreen> {
  late List<String> _lines = List<String>.from(widget.initialLines);
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (_lines.isEmpty) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final lines = await DeviceDisplayMetrics.readWakeDiag();
    if (!mounted) {
      return;
    }
    setState(() {
      _lines = lines;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    await DeviceDisplayMetrics.clearWakeDiag();
    await DeviceDisplayMetrics.markWakeDiag('clearedByUser');
    await _reload();
  }

  Future<void> _mark() async {
    await DeviceDisplayMetrics.markWakeDiag('manualMark');
    await _reload();
  }

  Future<void> _copy() async {
    final text = _lines.isEmpty ? '(empty)' : _lines.join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制日志')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Wake DIAG', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '标记',
            onPressed: _loading ? null : _mark,
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            tooltip: '复制',
            onPressed: _lines.isEmpty ? null : _copy,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: _loading ? null : _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '测法：点 DIAG 清空  播歌  回桌面  点锁屏/控制中心/灵动岛 Now Playing  '
              '图标进 App  再开 DIAG。\n'
              '若点 Now Playing 时没有 willEnterForeground/didBecomeActive，'
              '说明系统根本没激活我们。',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          Expanded(
            child: _lines.isEmpty
                ? const Center(
                    child: Text(
                      '暂无日志',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: _lines.length,
                    itemBuilder: (context, index) {
                      final line = _lines[index];
                      final highlight = line.contains('willEnterForeground') ||
                          line.contains('didBecomeActive') ||
                          line.contains('openURL') ||
                          line.contains('continueUserActivity') ||
                          line.contains('willConnect');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SelectableText(
                          line,
                          style: TextStyle(
                            color: highlight
                                ? const Color(0xFFFFEB3B)
                                : Colors.white,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}