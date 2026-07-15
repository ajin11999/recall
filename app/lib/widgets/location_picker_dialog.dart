import 'package:flutter/material.dart';
import '../models.dart';

Future<int?> showLocationPicker({
  required BuildContext context,
  required List<Location> locations,
  int? initialLocationId,
  bool allowClear = true,
  int? excludeLocationId, // Don't allow selecting this location or its children (for parent selection)
}) async {
  return showModalBottomSheet<int?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: _LocationPickerSheet(
          locations: locations,
          initialLocationId: initialLocationId,
          allowClear: allowClear,
          excludeLocationId: excludeLocationId,
        ),
      ),
    ),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({
    required this.locations,
    this.initialLocationId,
    this.allowClear = true,
    this.excludeLocationId,
  });

  final List<Location> locations;
  final int? initialLocationId;
  final bool allowClear;
  final int? excludeLocationId;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _searchController = TextEditingController();
  late List<(Location, int)> _tree;
  late List<(Location, int)> _filteredTree;

  @override
  void initState() {
    super.initState();
    Set<int> excludedIds = {};
    if (widget.excludeLocationId != null) {
      void walk(int id) {
        excludedIds.add(id);
        for (final l in widget.locations.where((loc) => loc.parentId == id)) {
          walk(l.id);
        }
      }
      walk(widget.excludeLocationId!);
    }

    _tree = widget.locations.buildTree().where((row) => !excludedIds.contains(row.$1.id)).toList();
    _filteredTree = _tree;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    final words = query.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    setState(() {
      _filteredTree = _tree.where((e) {
        final val = widget.locations.pathFor(e.$1.id).toLowerCase();
        return words.every((word) => val.contains(word));
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Select Location',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search location...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredTree.length + (widget.allowClear ? 1 : 0),
            itemBuilder: (context, i) {
              if (widget.allowClear && i == 0) {
                return ListTile(
                  leading: const Icon(Icons.clear),
                  title: const Text('No location / Top level', style: TextStyle(fontStyle: FontStyle.italic)),
                  trailing: widget.initialLocationId == null ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, -1),
                );
              }
              final idx = widget.allowClear ? i - 1 : i;
              final (location, _) = _filteredTree[idx];
              final path = widget.locations.pathFor(location.id);
              return ListTile(
                title: Text(path),
                trailing: location.id == widget.initialLocationId ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, location.id),
              );
            },
          ),
        ),
      ],
    );
  }
}
