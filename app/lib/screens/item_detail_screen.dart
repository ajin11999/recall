import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../models.dart';
import '../notifications.dart';
import 'item_edit_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.api, required this.itemId});

  final Api api;
  final int itemId;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  Item? _item;
  List<Location> _locations = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        widget.api.item(widget.itemId),
        widget.api.locations(),
      ]);
      setState(() {
        _item = results[0] as Item;
        _locations = results[1] as List<Location>;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  String? get _locationName {
    final id = _item?.locationId;
    if (id == null) return null;
    for (final l in _locations) {
      if (l.id == id) return l.name;
    }
    return null;
  }

  Future<void> _addPhoto(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      await widget.api.uploadPhoto(widget.itemId, bytes, x.mimeType ?? 'image/jpeg');
      await _load();
    } catch (e) {
      _snack(apiErrorMessage(e));
    }
  }

  Future<void> _deletePhoto(Photo photo) async {
    final ok = await _confirm('Delete this photo?');
    if (!ok) return;
    try {
      await widget.api.deletePhoto(photo.id);
      await _load();
    } catch (e) {
      _snack(apiErrorMessage(e));
    }
  }

  Future<void> _deleteItem() async {
    final ok = await _confirm('Delete "${_item!.name}" and all its photos and schedules?');
    if (!ok) return;
    try {
      await widget.api.deleteItem(widget.itemId);
      await Notifications.sync(widget.api);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(apiErrorMessage(e));
    }
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
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
    return result == true;
  }

  void _showAddPhotoBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Add Photo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo (Camera)'),
                onTap: () {
                  Navigator.pop(context);
                  _addPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _addPhoto(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addOrEditSchedule({MaintenanceSchedule? existing}) async {
    final name = TextEditingController(text: existing?.name);
    final notes = TextEditingController(text: existing?.notes);
    final interval = TextEditingController(text: existing?.intervalDays.toString() ?? '90');
    DateTime due = DateTime.tryParse(existing?.nextDueDate ?? '') ??
        DateTime.now().add(Duration(days: int.tryParse(interval.text) ?? 90));

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New maintenance schedule' : 'Edit schedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Task name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: interval,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Repeat every (days) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  title: const Text('Next due'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(due)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: due,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => due = picked);
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
      'interval_days': int.tryParse(interval.text) ?? 90,
      'next_due_date': DateFormat('yyyy-MM-dd').format(due),
      'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
    };
    try {
      if (existing == null) {
        await widget.api.createSchedule(widget.itemId, body);
      } else {
        await widget.api.updateSchedule(existing.id, body);
      }
      await _load();
      await Notifications.sync(widget.api);
    } catch (e) {
      _snack(apiErrorMessage(e));
    }
  }

  Future<void> _completeSchedule(MaintenanceSchedule s) async {
    final notes = TextEditingController();
    final cost = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark "${s.name}" done'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notes,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cost',
                border: OutlineInputBorder(),
              ),
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
      await widget.api.completeSchedule(
        s.id,
        notes: notes.text.trim(),
        cost: num.tryParse(cost.text),
      );
      await _load();
      await Notifications.sync(widget.api);
    } catch (e) {
      _snack(apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      appBar: AppBar(
        title: Text(item?.name ?? 'Item'),
        actions: [
          if (item != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => ItemEditScreen(api: widget.api, item: item)),
                );
                if (changed == true) _load();
              },
            ),
          if (item != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteItem),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : item == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _photoStrip(item),
                      const SizedBox(height: 16),
                      if (item.labels.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          children: item.labels
                              .map((l) => Chip(
                                    label: Text(l.name),
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      if (item.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(item.description!),
                      ],
                      const SizedBox(height: 16),
                      _infoCard(item),
                      const SizedBox(height: 16),
                      _maintenanceCard(item),
                      if (item.notes?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                            borderRadius: const BorderRadius.all(Radius.circular(16)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Text(item.notes!),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _photoStrip(Item item) {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...item.photos.map(
            (p) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: InteractiveViewer(
                      child: Image.network(widget.api.photoUrl(p.id), fit: BoxFit.contain),
                    ),
                  ),
                ),
                onLongPress: () => _deletePhoto(p),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.api.photoUrl(p.id),
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const SizedBox(width: 120, child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: _showAddPhotoBottomSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add Photo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(Item item) {
    final List<(IconData, String, String)> details = [
      if (_locationName != null) (Icons.place_outlined, 'Location', _locationName!),
      (Icons.layers_outlined, 'Quantity', item.quantity.toString()),
      if (item.serialNumber?.isNotEmpty == true) (Icons.tag, 'Serial number', item.serialNumber!),
      if (item.purchasePrice != null) (Icons.sell_outlined, 'Price', '\$${item.purchasePrice!.toStringAsFixed(2)}'),
      if (item.purchaseDate != null) (Icons.calendar_today_outlined, 'Purchased', item.purchaseDate!),
      if (item.purchasedFrom?.isNotEmpty == true) (Icons.storefront_outlined, 'Purchased From', item.purchasedFrom!),
      if (item.warrantyUntil != null)
        (
          Icons.verified_user_outlined,
          'Warranty',
          '${item.warrantyUntil!} ${item.warrantyActive ? '(Active)' : '(Expired)'}'
        ),
    ];

    if (details.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: details.length,
              separatorBuilder: (context, index) => Divider(
                height: 16,
                color: Theme.of(context).colorScheme.outlineVariant.withAlpha(128),
              ),
              itemBuilder: (context, idx) {
                final (icon, title, val) = details[idx];
                final isWarrantyExpired = title == 'Warranty' && !item.warrantyActive;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              val,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isWarrantyExpired ? Theme.of(context).colorScheme.error : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _maintenanceCard(Item item) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Maintenance', style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () => _addOrEditSchedule(),
                ),
              ],
            ),
            if (item.schedules.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No schedules.',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
              ),
            ...item.schedules.map(
              (s) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  s.isOverdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
                  color: s.isOverdue ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                ),
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  'Every ${s.intervalDays} days · due ${s.nextDueDate}${s.isOverdue ? ' (overdue)' : ''}',
                  style: s.isOverdue ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      tooltip: 'Mark done',
                      onPressed: () => _completeSchedule(s),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') {
                          await _addOrEditSchedule(existing: s);
                        } else if (v == 'delete') {
                          final ok = await _confirm('Delete schedule "${s.name}"?');
                          if (!ok) return;
                          try {
                            await widget.api.deleteSchedule(s.id);
                            await _load();
                            await Notifications.sync(widget.api);
                          } catch (e) {
                            _snack(apiErrorMessage(e));
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
