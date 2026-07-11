import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../models.dart';

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

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name);
    _description = TextEditingController(text: item?.description);
    _quantity = TextEditingController(text: (item?.quantity ?? 1).toString());
    _serial = TextEditingController(text: item?.serialNumber);
    _price = TextEditingController(text: item?.purchasePrice?.toString());
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
      'quantity': int.tryParse(_quantity.text) ?? 1,
      'location_id': _locationId,
      'serial_number': _serial.text.trim().isEmpty ? null : _serial.text.trim(),
      'purchase_price': num.tryParse(_price.text),
      'purchase_date': _purchaseDate == null ? null : fmt.format(_purchaseDate!),
      'purchased_from': _from.text.trim().isEmpty ? null : _from.text.trim(),
      'warranty_until': _warrantyUntil == null ? null : fmt.format(_warrantyUntil!),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'label_ids': _labelIds.toList(),
    };
    try {
      if (widget.item == null) {
        await widget.api.createItem(body);
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
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
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
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _serial,
                    decoration: const InputDecoration(
                      labelText: 'Serial number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _locationId,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('No location')),
                ..._locations.map((l) => DropdownMenuItem<int?>(value: l.id, child: Text(l.name))),
              ],
              onChanged: (v) => setState(() => _locationId = v),
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
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _from,
                    decoration: const InputDecoration(
                      labelText: 'Purchased from',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _dateField('Purchase date', _purchaseDate, (v) => setState(() => _purchaseDate = v)),
            _dateField('Warranty until', _warrantyUntil, (v) => setState(() => _warrantyUntil = v)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              maxLines: 3,
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
