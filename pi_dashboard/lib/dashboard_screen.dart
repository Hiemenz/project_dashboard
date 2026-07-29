import 'dart:async';
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'host_editor_screen.dart';
import 'host_store.dart';
import 'models.dart';
import 'pi_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _HostSummary {
  PiStats? stats;
  String? error;
  bool loading = true;
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _store = HostStore();
  List<PiHost> _hosts = [];
  final Map<String, _HostSummary> _summaries = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshAll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final hosts = await _store.load();
    setState(() => _hosts = hosts);
    await _refreshAll();
  }

  Future<void> _refreshAll() async {
    for (final host in _hosts) {
      final summary = _summaries.putIfAbsent(host.id, () => _HostSummary());
      unawaited(_refreshOne(host, summary));
    }
  }

  Future<void> _refreshOne(PiHost host, _HostSummary summary) async {
    try {
      final stats = await PiApiClient(host).fetchStats();
      if (!mounted) return;
      setState(() {
        summary.stats = stats;
        summary.error = null;
        summary.loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        summary.error = e.toString();
        summary.loading = false;
      });
    }
  }

  Future<void> _addHost() async {
    final result =
        await Navigator.of(context).push<PiHost>(
      MaterialPageRoute(builder: (_) => const HostEditorScreen()),
    );
    if (result == null) return;
    setState(() => _hosts = [..._hosts, result]);
    await _store.save(_hosts);
    await _refreshAll();
  }

  Future<void> _editHost(PiHost host) async {
    final result = await Navigator.of(context).push<PiHost>(
      MaterialPageRoute(builder: (_) => HostEditorScreen(existing: host)),
    );
    if (result == null) return;
    setState(() {
      _hosts = _hosts.map((h) => h.id == result.id ? result : h).toList();
    });
    await _store.save(_hosts);
    await _refreshAll();
  }

  Future<void> _removeHost(PiHost host) async {
    setState(() {
      _hosts = _hosts.where((h) => h.id != host.id).toList();
      _summaries.remove(host.id);
    });
    await _store.save(_hosts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raspberry Pis')),
      body: _hosts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No Pis added yet. Add one to start monitoring.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _addHost,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Pi'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView.builder(
                itemCount: _hosts.length,
                itemBuilder: (context, i) {
                  final host = _hosts[i];
                  final summary = _summaries[host.id] ?? _HostSummary();
                  return _HostTile(
                    host: host,
                    summary: summary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PiDetailScreen(host: host),
                      ),
                    ),
                    onEdit: () => _editHost(host),
                    onRemove: () => _removeHost(host),
                  );
                },
              ),
            ),
      floatingActionButton: _hosts.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: _addHost,
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _HostTile extends StatelessWidget {
  final PiHost host;
  final _HostSummary summary;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _HostTile({
    required this.host,
    required this.summary,
    required this.onTap,
    required this.onEdit,
    required this.onRemove,
  });

  Color _statusColor() {
    if (summary.error != null) return Colors.red;
    final s = summary.stats;
    if (s == null) return Colors.grey;
    if (s.cpuPercent > 85 || s.memPercent > 90) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final stats = summary.stats;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: _statusColor(),
        child: const Icon(Icons.developer_board, color: Colors.white),
      ),
      title: Text(host.name),
      subtitle: summary.error != null
          ? Text('Unreachable', style: TextStyle(color: Colors.red[300]))
          : stats == null
              ? const Text('Loading…')
              : Text(
                  'CPU ${stats.cpuPercent.toStringAsFixed(0)}% · '
                  'MEM ${stats.memPercent.toStringAsFixed(0)}%'
                  '${stats.cpuTempC != null ? ' · ${stats.cpuTempC!.toStringAsFixed(0)}°C' : ''}',
                ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') onEdit();
          if (v == 'remove') onRemove();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'remove', child: Text('Remove')),
        ],
      ),
    );
  }
}
