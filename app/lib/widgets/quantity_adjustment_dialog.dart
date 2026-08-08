import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../models.dart';

/// Opens an effortless quantity adjustment sheet for a consumable item.
Future<Item?> showQuantityAdjustmentSheet({
  required BuildContext context,
  required Api api,
  required Item item,
}) async {
  return showModalBottomSheet<Item?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _QuantityAdjustmentSheet(api: api, item: item),
    ),
  );
}

class _QuantityAdjustmentSheet extends StatefulWidget {
  const _QuantityAdjustmentSheet({
    required this.api,
    required this.item,
  });

  final Api api;
  final Item item;

  @override
  State<_QuantityAdjustmentSheet> createState() => _QuantityAdjustmentSheetState();
}

class _QuantityAdjustmentSheetState extends State<_QuantityAdjustmentSheet> {
  late int _currentQuantity;
  late final TextEditingController _customController;
  bool _busy = false;
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    _currentQuantity = widget.item.quantity;
    _customController = TextEditingController(text: '$_currentQuantity');
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _updateQuantity(int newQuantity) async {
    if (newQuantity < 0) newQuantity = 0;
    if (newQuantity == _currentQuantity) return;

    setState(() {
      _currentQuantity = newQuantity;
      _customController.text = '$newQuantity';
      _busy = true;
    });

    try {
      final updated = await widget.api.updateItem(widget.item.id, {
        'quantity': newQuantity,
      });
      if (mounted) {
        setState(() {
          _currentQuantity = updated.quantity;
          _busy = false;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _adjustBy(int delta) async {
    final target = _currentQuantity + delta;
    await _updateQuantity(target < 0 ? 0 : target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOut = _currentQuantity == 0;
    final isLow = widget.item.isConsumable &&
        !widget.item.isWishlist &&
        _currentQuantity > 0 &&
        _currentQuantity <= widget.item.minQuantity;

    final statusColor = isOut
        ? Colors.red
        : (isLow ? Colors.orange : colorScheme.primary);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOut
                      ? Icons.error_outline
                      : (isLow ? Icons.warning_amber_outlined : Icons.inventory_2_outlined),
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOut
                          ? 'Out of Stock'
                          : (isLow
                              ? 'Low Stock (Threshold: ${widget.item.minQuantity})'
                              : 'In Stock'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Main Big Stepper Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Big Decrement Button
                IconButton.filledTonal(
                  iconSize: 32,
                  padding: const EdgeInsets.all(12),
                  icon: const Icon(Icons.remove),
                  tooltip: 'Decrease 1',
                  onPressed: _currentQuantity > 0 ? () => _adjustBy(-1) : null,
                ),

                // Large Quantity Display
                GestureDetector(
                  onTap: () {
                    setState(() => _showCustomInput = !_showCustomInput);
                  },
                  child: Column(
                    children: [
                      Text(
                        '$_currentQuantity',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        'Tap to type amount',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),

                // Big Increment Button
                IconButton.filled(
                  iconSize: 32,
                  padding: const EdgeInsets.all(12),
                  icon: const Icon(Icons.add),
                  tooltip: 'Increase 1',
                  onPressed: () => _adjustBy(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Optional Custom Number Input Field
          if (_showCustomInput) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Set Exact Quantity',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final val = int.tryParse(_customController.text);
                    if (val != null) {
                      _updateQuantity(val);
                      setState(() => _showCustomInput = false);
                    }
                  },
                  child: const Text('Set'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Quick Delta Preset Buttons
          Text(
            'Quick Adjustments',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _presetChip('-10', () => _adjustBy(-10), isDanger: true),
              _presetChip('-5', () => _adjustBy(-5), isDanger: true),
              _presetChip('-1', () => _adjustBy(-1), isDanger: true),
              _presetChip('+1', () => _adjustBy(1)),
              _presetChip('+5', () => _adjustBy(5)),
              _presetChip('+10', () => _adjustBy(10)),
            ],
          ),
          const SizedBox(height: 16),

          // Shortcut Actions Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.remove_shopping_cart_outlined, size: 18),
                  label: const Text('Mark Out of Stock (0)'),
                  onPressed: _currentQuantity > 0 ? () => _updateQuantity(0) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context, Item(
                  id: widget.item.id,
                  name: widget.item.name,
                  description: widget.item.description,
                  quantity: _currentQuantity,
                  locationId: widget.item.locationId,
                  serialNumber: widget.item.serialNumber,
                  purchasePrice: widget.item.purchasePrice,
                  purchaseDate: widget.item.purchaseDate,
                  purchasedFrom: widget.item.purchasedFrom,
                  warrantyUntil: widget.item.warrantyUntil,
                  notes: widget.item.notes,
                  coverPhotoId: widget.item.coverPhotoId,
                  labelIds: widget.item.labelIds,
                  labels: widget.item.labels,
                  photos: widget.item.photos,
                  schedules: widget.item.schedules,
                  isArchived: widget.item.isArchived,
                  isConsumable: widget.item.isConsumable,
                  minQuantity: widget.item.minQuantity,
                  isWishlist: widget.item.isWishlist,
                ));
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, VoidCallback onTap, {bool isDanger = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDanger ? Colors.red : colorScheme.primary;

    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: onTap,
    );
  }
}
