import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/location_picker_dialog.dart';
import 'items_screen.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key, required this.api});

  final Api api;

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  List<Location> _locations = [];
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
      final locations = await widget.api.locations();
      setState(() {
        _locations = locations;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _edit({Location? existing, int? parentId}) async {
    final name = TextEditingController(text: existing?.name);
    final description = TextEditingController(text: existing?.description);
    int? parent = existing?.parentId ?? parentId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New location' : 'Edit location'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: parent == null ? 'Top level' : _locations.pathFor(parent),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Inside',
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    suffixIcon: parent != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setDialogState(() => parent = null),
                          )
                        : const Icon(Icons.arrow_drop_down),
                  ),
                  onTap: () async {
                    final id = await showLocationPicker(
                      context: context,
                      locations: _locations,
                      initialLocationId: parent,
                      excludeLocationId: existing?.id,
                    );
                    if (id != null) {
                      setDialogState(() => parent = id == -1 ? null : id);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    final body = {
      'name': name.text.trim(),
      'parent_id': parent,
      'description': description.text.trim().isEmpty ? null : description.text.trim(),
    };
    try {
      if (existing == null) {
        await widget.api.createLocation(body);
      } else {
        await widget.api.updateLocation(existing.id, body);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  Future<void> _delete(Location location) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text(
            'Delete "${location.name}"? Items inside keep existing but lose this location; child locations move to top level.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.deleteLocation(location.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _locations.buildTree();
    return Scaffold(
      appBar: AppBar(title: const Text('Locations'), automaticallyImplyLeading: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _locations.isEmpty
                  ? const Center(child: Text('No locations yet — tap + to add "Garage", "Office"…'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final (location, depth) = rows[i];
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: EdgeInsets.only(left: 16.0 + depth * 24, right: 8),
                            leading: Icon(depth == 0 ? Icons.home_work_outlined : Icons.subdirectory_arrow_right),
                            title: Text(location.name),
                            subtitle: Text('${location.itemCount} item${location.itemCount == 1 ? '' : 's'}'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ItemsScreen(api: widget.api, fixedLocation: location),
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                switch (v) {
                                  case 'add-child':
                                    _edit(parentId: location.id);
                                  case 'edit':
                                    _edit(existing: location);
                                  case 'delete':
                                    _delete(location);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'add-child', child: Text('Add sub-location')),
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
