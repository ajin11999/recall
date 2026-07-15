import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pattern_formatter/pattern_formatter.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/location_picker_dialog.dart';

class ItemEditScreen extends StatefulWidget {
  const ItemEditScreen({super.key, required this.api, this.item, this.initialLocationId});

  final Api api;
  final Item? item;
  final int? initialLocationId;

  @override
  State<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _quantity;
  late final TextEditingController _serial;
  late final TextEditingController _price;
  late final TextEditingController _from;
  late final TextEditingController _notes;
  DateTime? _purchaseDate;
  DateTime? _warrantyUntil;
  int? _locationId;
  final Set<int> _labelIds = {};

  List<Location> _locations = [];
  List<Label> _labels = [];
  bool _busy = false;

  final List<XFile> _newPhotos = [];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name);
    _description = TextEditingController(text: item?.description);
    final nf = NumberFormat('#,###');
    _quantity = TextEditingController(text: nf.format(item?.quantity ?? 1));
    _serial = TextEditingController(text: item?.serialNumber);
    _price = TextEditingController(text: item?.purchasePrice != null ? nf.format(item!.purchasePrice) : null);
    _from = TextEditingController(text: item?.purchasedFrom);
    _notes = TextEditingController(text: item?.notes);
    _purchaseDate = item?.purchaseDate == null ? null : DateTime.tryParse(item!.purchaseDate!);
    _warrantyUntil = item?.warrantyUntil == null ? null : DateTime.tryParse(item!.warrantyUntil!);
    _locationId = item?.locationId ?? widget.initialLocationId;
    _labelIds.addAll(item?.labelIds ?? const []);
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([widget.api.locations(), widget.api.labels()]);
      setState(() {
        _locations = results[0] as List<Location>;
        _labels = results[1] as List<Label>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final fmt = DateFormat('yyyy-MM-dd');
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'quantity': int.tryParse(_quantity.text.replaceAll(',', '')) ?? 1,
      'location_id': _locationId,
      'serial_number': _serial.text.trim().isEmpty ? null : _serial.text.trim(),
      'purchase_price': num.tryParse(_price.text.replaceAll(',', '')),
      'purchase_date': _purchaseDate == null ? null : fmt.format(_purchaseDate!),
      'purchased_from': _from.text.trim().isEmpty ? null : _from.text.trim(),
      'warranty_until': _warrantyUntil == null ? null : fmt.format(_warrantyUntil!),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'label_ids': _labelIds.toList(),
    };
    try {
      if (widget.item == null) {
        final item = await widget.api.createItem(body);
        for (final photo in _newPhotos) {
          try {
            await widget.api.uploadPhoto(
              item.id,
              await photo.readAsBytes(),
              photo.mimeType ?? 'image/jpeg',
            );
          } catch (e) {
            debugPrint('Failed to upload photo: $e');
          }
        }
      } else {
        await widget.api.updateItem(widget.item!.id, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
        setState(() => _busy = false);
      }
    }
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
    final controller = TextEditingController(
      text: value == null ? '' : DateFormat('yyyy-MM-dd').format(value),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            readOnly: true,
            decoration: InputDecoration(
              hintText: 'Select date',
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              prefixIcon: const Icon(Icons.calendar_today),
              suffixIcon: value != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => onChanged(null),
                    )
                  : null,
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(1990),
                lastDate: DateTime(2100),
              );
              if (picked != null) onChanged(picked);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
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
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (picked != null) {
                    setState(() => _newPhotos.add(picked));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
                  if (picked.isNotEmpty) {
                    setState(() => _newPhotos.addAll(picked));
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'New item' : 'Edit item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.item == null) ...[
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._newPhotos.map((p) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(p.path), width: 100, height: 100, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Material(
                                  color: Colors.black45,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => setState(() => _newPhotos.remove(p)),
                                    child: const Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(Icons.close, color: Colors.white, size: 7),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    InkWell(
                      onTap: _showAddPhotoBottomSheet,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.add_a_photo_outlined, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildField(
              'Name *',
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  hintText: 'Enter name',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
            ),
            const SizedBox(height: 12),
            _buildField(
              'Description',
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  hintText: 'Enter description',
                ),
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    'Quantity',
                    TextFormField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: const InputDecoration(
                        hintText: '1',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    'Serial number',
                    TextFormField(
                      controller: _serial,
                      decoration: const InputDecoration(
                        hintText: 'Serial',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildField(
              'Location',
              TextFormField(
                readOnly: true,
                controller: TextEditingController(
                  text: _locationId == null ? 'No location' : _locations.pathFor(_locationId),
                ),
                decoration: InputDecoration(
                  hintText: 'Select location',
                  suffixIcon: _locationId != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _locationId = null),
                        )
                      : const Icon(Icons.arrow_drop_down),
                ),
                onTap: () async {
                  final id = await showLocationPicker(
                    context: context,
                    locations: _locations,
                    initialLocationId: _locationId,
                  );
                  if (id != null) {
                    setState(() => _locationId = id == -1 ? null : id);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_labels.isNotEmpty) ...[
              Text(
                'Labels',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _labels
                    .map(
                      (l) => FilterChip(
                        label: Text(l.name),
                        selected: _labelIds.contains(l.id),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _labelIds.add(l.id);
                          } else {
                            _labelIds.remove(l.id);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Purchase & warranty',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    'Price',
                    TextFormField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: const InputDecoration(
                        hintText: '0.00',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    'Purchased from',
                    TextFormField(
                      controller: _from,
                      decoration: const InputDecoration(
                        hintText: 'Store name',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _dateField('Purchase date', _purchaseDate, (v) => setState(() => _purchaseDate = v)),
            _dateField('Warranty until', _warrantyUntil, (v) => setState(() => _warrantyUntil = v)),
            const SizedBox(height: 6),
            _buildField(
              'Notes',
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(
                  hintText: 'Additional notes',
                ),
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(widget.item == null ? 'Create item' : 'Save changes'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


