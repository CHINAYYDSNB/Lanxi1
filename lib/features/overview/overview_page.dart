// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:lanxi/services/server_service.dart';

/// System monitoring dashboard.
///
/// Shows CPU, memory, disk usage and system info.
/// Data is fetched via [ServerService.getSystemInfo].
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

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await widget.service.getSystemInfo();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      appLogger.e('Failed to fetch system info', e);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to fetch system info: $e';
        _loading = false;
      });
    }
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
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
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
            title: 'Memory',
            value: '${stats.memUsedMb} / ${stats.memTotalMb} MB',
            subtitle: '${stats.memPercent.toStringAsFixed(1)}%',
            progress: stats.memPercent / 100,
            color: _memColor(stats.memPercent),
          ),
          const SizedBox(height: 12),

          // Disk card
          _MetricCard(
            icon: Icons.disc_full,
            title: 'Disk',
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('System Info',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const Divider(),
                  _InfoRow(label: 'Hostname', value: stats.hostName),
                  if (stats.osInfo.isNotEmpty)
                    _InfoRow(label: 'OS', value: stats.osInfo),
                  _InfoRow(
                    label: 'Load Average',
                    value: stats.loadAvg.toStringAsFixed(2),
                  ),
                  _InfoRow(
                    label: 'Source',
                    value: stats.source.name.toUpperCase(),
                  ),
                  _InfoRow(
                    label: 'Updated',
                    value: _formatTime(stats.timestamp),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
              ],
            ),
            const SizedBox(height: 12),
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
                child: Text(subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                        )),
              ),
            ],
          ],
        ),
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
    return Card(
      child: ListTile(
        leading: Icon(Icons.folder, color: color),
        title: Text(disk.path),
        subtitle: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0),
            minHeight: 4,
            // ignore: deprecated_member_use
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        trailing: Text(
          '${disk.usedMb} / ${disk.totalMb} MB',
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
