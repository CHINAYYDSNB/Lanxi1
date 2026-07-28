// ignore_for_file: require_trailing_commas

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:lanxi/services/server_service.dart';
import 'package:lanxi/widgets/app_card.dart';

/// System monitoring dashboard.
///
/// Shows CPU, memory, disk usage and system info, updated live via
/// [ServerService.watchHostStats] (SSH pushes; panel polls behind the scene,
/// so the UI never polls the API itself).
class OverviewPage extends StatefulWidget {
  final ServerService service;

  const OverviewPage({super.key, required this.service});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  SystemStats? _stats;
  String? _error;
  bool _loading = true;
  StreamSubscription<SystemStats>? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    _loading = true;
    _error = null;
    if (mounted) setState(() {});
    _sub = widget.service.watchHostStats().listen(
      (stats) {
        if (!mounted) return;
        setState(() {
          _stats = stats;
          _error = null;
          _loading = false;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        // If we already have a snapshot, keep showing it; otherwise surface
        // the error so the user can retry the live stream.
        if (_stats == null) {
          setState(() {
            _error = '获取系统信息失败：$e';
            _loading = false;
          });
        } else {
          appLogger.w('Overview stats stream error (keeping last): $e');
        }
      },
    );
  }

  /// Manual pull-to-refresh: force one immediate fetch (the live stream keeps
  /// updating on its own).
  Future<void> _refresh() async {
    try {
      final stats = await widget.service.getSystemInfo();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _error = null;
      });
    } catch (e) {
      appLogger.w('Manual overview refresh failed: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _subscribe,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final stats = _stats!;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // CPU card
          _MetricCard(
            icon: Icons.memory,
            title: 'CPU',
            value: '${stats.cpuPercent.toStringAsFixed(1)}%',
            progress: stats.cpuPercent / 100,
            color: _cpuColor(stats.cpuPercent),
          ),
          const SizedBox(height: 12),

          // Memory card
          _MetricCard(
            icon: Icons.storage,
            title: '内存',
            value: '${stats.memUsedMb} / ${stats.memTotalMb} MB',
            subtitle: '${stats.memPercent.toStringAsFixed(1)}%',
            progress: stats.memPercent / 100,
            color: _memColor(stats.memPercent),
          ),
          const SizedBox(height: 12),

          // Disk card
          _MetricCard(
            icon: Icons.disc_full,
            title: '磁盘',
            value: '${stats.diskUsedMb} / ${stats.diskTotalMb} MB',
            subtitle: '${stats.diskPercent.toStringAsFixed(1)}%',
            progress: stats.diskPercent / 100,
            color: _diskColor(stats.diskPercent),
          ),
          const SizedBox(height: 12),

          // Disk partitions
          ...stats.disks.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DiskTile(disk: d),
            ),
          ),

          // System info card
          AppCard(
            icon: Icons.info_outline,
            title: '系统信息',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: '主机名', value: stats.hostName),
                if (stats.osInfo.isNotEmpty)
                  _InfoRow(label: '系统', value: stats.osInfo),
                _InfoRow(
                  label: '负载',
                  value: stats.loadAvg.toStringAsFixed(2),
                ),
                _InfoRow(
                  label: '数据来源',
                  value: stats.source.name.toUpperCase(),
                ),
                _InfoRow(
                  label: '更新时间',
                  value: _formatTime(stats.timestamp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}秒前';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    return '${diff.inHours}小时前';
  }

  Color _cpuColor(double p) => p > 80
      ? Colors.red
      : p > 50
          ? Colors.orange
          : Colors.green;
  Color _memColor(double p) => p > 80
      ? Colors.red
      : p > 60
          ? Colors.orange
          : Colors.green;
  Color _diskColor(double p) => p > 90
      ? Colors.red
      : p > 70
          ? Colors.orange
          : Colors.green;
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final double progress;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      icon: icon,
      title: title,
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              // ignore: deprecated_member_use
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiskTile extends StatelessWidget {
  final DiskInfo disk;

  const _DiskTile({required this.disk});

  @override
  Widget build(BuildContext context) {
    final pct = disk.percent;
    final color = pct > 90
        ? Colors.red
        : pct > 70
            ? Colors.orange
            : Colors.blue;
    return AppCard(
      icon: Icons.folder,
      title: disk.path,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 4,
              // ignore: deprecated_member_use
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${disk.usedMb} / ${disk.totalMb} MB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  )),
        ],
      ),
    );
  }
}
