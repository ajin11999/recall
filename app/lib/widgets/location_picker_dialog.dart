import 'package:flutter/material.dart';
import '../models.dart';

Future<int?> showLocationPicker({
  required BuildContext context,
  required List<Location> locations,
  int? initialLocationId,
  bool allowClear = true,
  int? excludeLocationId, // Don't allow selecting this location or its children (for parent selection)
}) async {
  return showDialog<int?>(
    context: context,
    builder: (context) => _LocationPickerDialog(
      locations: locations,
      initialLocationId: initialLocationId,
      allowClear: allowClear,
      excludeLocationId: excludeLocationId,
    ),
  );
}

class _LocationPickerDialog extends StatelessWidget {
  const _LocationPickerDialog({
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
  Widget build(BuildContext context) {
    Set<int> excludedIds = {};
    if (excludeLocationId != null) {
      void walk(int id) {
        excludedIds.add(id);
        for (final l in locations.where((loc) => loc.parentId == id)) {
          walk(l.id);
        }
      }
      walk(excludeLocationId!);
    }

    final tree = locations.buildTree().where((row) => !excludedIds.contains(row.$1.id)).toList();

    return AlertDialog(
      title: const Text('Select Location'),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: tree.length + (allowClear ? 1 : 0),
          itemBuilder: (context, i) {
            if (allowClear && i == 0) {
              return ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('No location / Top level', style: TextStyle(fontStyle: FontStyle.italic)),
                selected: initialLocationId == null,
                onTap: () => Navigator.pop(context, -1), // use -1 to indicate cleared
              );
            }
            final idx = allowClear ? i - 1 : i;
            final (location, depth) = tree[idx];
            return ListTile(
              contentPadding: EdgeInsets.only(left: 24.0 + depth * 24, right: 24),
              leading: Icon(depth == 0 ? Icons.home_work_outlined : Icons.subdirectory_arrow_right),
              title: Text(location.name),
              selected: location.id == initialLocationId,
              onTap: () => Navigator.pop(context, location.id),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
