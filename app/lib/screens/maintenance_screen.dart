import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../notifications.dart';
import 'item_detail_screen.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key, required this.api});

  final Api api;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  List<MaintenanceSchedule> _upcoming = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final upcoming = await widget.api.upcomingMaintenance(days: 90);
      setState(() {
        _upcoming = upcoming;
        _loading = false;
      });
      Notifications.sync(widget.api);
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _complete(MaintenanceSchedule s) async {
    final notes = TextEditingController();
    final cost = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark "${s.name}" done'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
            TextField(
              controller: cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cost'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Done')),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await widget.api.completeSchedule(s.id, notes: notes.text.trim(), cost: num.tryParse(cost.text));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final overdue = _upcoming.where((s) => s.isOverdue).toList();
    final later = _upcoming.where((s) => !s.isOverdue).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance'), automaticallyImplyLeading: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _upcoming.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nothing due in the next 90 days.\nAdd schedules from an item\'s detail page.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          if (overdue.isNotEmpty) _section('Overdue', overdue, isOverdue: true),
                          if (later.isNotEmpty) _section('Upcoming', later),
                        ],
                      ),
                    ),
    );
  }

  Widget _section(String title, List<MaintenanceSchedule> schedules, {bool isOverdue = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isOverdue ? Theme.of(context).colorScheme.error : null,
                ),
          ),
        ),
        ...schedules.map(
          (s) => ListTile(
            leading: Icon(
              isOverdue ? Icons.warning_amber : Icons.schedule,
              color: isOverdue ? Theme.of(context).colorScheme.error : null,
            ),
            title: Text(s.name),
            subtitle: Text('${s.itemName ?? ''} · due ${s.nextDueDate}'),
            trailing: FilledButton.tonal(
              onPressed: () => _complete(s),
              child: const Text('Done'),
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ItemDetailScreen(api: widget.api, itemId: s.itemId),
                ),
              );
              _load();
            },
          ),
        ),
      ],
    );
  }
}
