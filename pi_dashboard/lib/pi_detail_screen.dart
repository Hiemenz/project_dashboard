import 'dart:async';
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'models.dart';

class PiDetailScreen extends StatefulWidget {
  final PiHost host;
  const PiDetailScreen({super.key, required this.host});

  @override
  State<PiDetailScreen> createState() => _PiDetailScreenState();
}

class _PiDetailScreenState extends State<PiDetailScreen> {
  late final PiApiClient _client;
  Timer? _timer;
  PiStats? _stats;
  List<PiProcess> _processes = [];
  String? _error;
  bool _loading = true;
  String _sortBy = 'cpu';

  @override
  void initState() {
    super.initState();
    _client = PiApiClient(widget.host);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final stats = await _client.fetchStats();
      final procs = await _client.fetchProcesses(limit: 30, sortBy: _sortBy);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _processes = procs;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _bytes(int b) {
    const gb = 1024 * 1024 * 1024;
    return '${(b / gb).toStringAsFixed(1)} GB';
  }

  String _uptime(double seconds) {
    final d = Duration(seconds: seconds.toInt());
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(title: Text(widget.host.name)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && stats == null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not reach ${widget.host.name}:\n$_error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Last refresh failed: $_error',
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                      if (stats != null) ...[
                        _StatCard(
                          title: 'CPU',
                          value: '${stats.cpuPercent.toStringAsFixed(0)}%',
                          percent: stats.cpuPercent / 100,
                          subtitle:
                              '${stats.cpuCount} cores · load ${stats.load1m.toStringAsFixed(2)}'
                              '${stats.cpuTempC != null ? ' · ${stats.cpuTempC!.toStringAsFixed(1)}°C' : ''}',
                        ),
                        _StatCard(
                          title: 'Memory',
                          value: '${stats.memPercent.toStringAsFixed(0)}%',
                          percent: stats.memPercent / 100,
                          subtitle:
                              '${_bytes(stats.memUsed)} / ${_bytes(stats.memTotal)}',
                        ),
                        _StatCard(
                          title: 'Disk',
                          value: '${stats.diskPercent.toStringAsFixed(0)}%',
                          percent: stats.diskPercent / 100,
                          subtitle:
                              '${_bytes(stats.diskUsed)} / ${_bytes(stats.diskTotal)}',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Uptime ${_uptime(stats.uptimeSeconds)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Top processes',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          DropdownButton<String>(
                            value: _sortBy,
                            items: const [
                              DropdownMenuItem(
                                  value: 'cpu', child: Text('Sort: CPU')),
                              DropdownMenuItem(
                                  value: 'memory', child: Text('Sort: Memory')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _sortBy = v);
                              _refresh();
                            },
                          ),
                        ],
                      ),
                      ..._processes.map(
                        (p) => ListTile(
                          dense: true,
                          title: Text(p.name),
                          subtitle: Text('pid ${p.pid} · ${p.user ?? '-'} · ${p.status}'),
                          trailing: Text(
                            'CPU ${p.cpuPercent.toStringAsFixed(1)}%\n'
                            'MEM ${p.memoryPercent.toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontFeatures: [
                              FontFeature.tabularFigures(),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final double percent;
  final String subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.percent,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent.clamp(0, 1),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
