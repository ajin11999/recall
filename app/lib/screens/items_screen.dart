import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/quantity_adjustment_dialog.dart';
import 'item_detail_screen.dart';
import 'item_edit_screen.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key, required this.api, this.fixedLocation});

  final Api api;

  /// When set, the screen is pushed as "items in this location" and hides the location filter.
  final Location? fixedLocation;

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Item> _items = [];
  List<Location> _locations = [];
  List<Label> _labels = [];
  int? _locationId;
  int? _labelId;
  bool _advancedSearch = false;
  bool _showArchived = false;
  bool _showWishlist = false;
  bool _showConsumablesOnly = false;
  bool _showLowStockOnly = false;
  bool _selectionMode = false;
  final Set<int> _selectedItemIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locationId = widget.fixedLocation?.id;
    _load(withFilters: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool withFilters = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.items(
        q: _search.text.trim(),
        locationId: _locationId,
        labelId: _labelId,
        advanced: _advancedSearch,
        includeArchived: _showArchived,
        isWishlist: _showWishlist ? true : false,
        isConsumable: _showConsumablesOnly ? true : null,
        lowStock: _showLowStockOnly,
      );
      if (withFilters) {
        final results = await Future.wait([widget.api.locations(), widget.api.labels()]);
        _locations = results[0] as List<Location>;
        _labels = results[1] as List<Label>;
      }
      setState(() {
        _items = page.items;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _moveSelected() async {
    final newLocationId = await _pickLocationForMove();
    if (newLocationId == -1) return; // Cancelled
    
    setState(() => _loading = true);
    try {
      await widget.api.bulkMoveItems(_selectedItemIds.toList(), newLocationId == 0 ? null : newLocationId);
      setState(() {
        _selectionMode = false;
        _selectedItemIds.clear();
      });
      await _load(withFilters: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
        setState(() => _loading = false);
      }
    }
  }

  Future<int> _pickLocationForMove() async {
    final entries = _locations.map((l) => MapEntry(l.id, _locations.pathFor(l.id))).toList();
    entries.insert(0, const MapEntry(0, 'None / No Location'));

    final result = await showModalBottomSheet<List<int?>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: _FilterModal<int>(
            label: 'Location to move to',
            entries: entries,
            currentValue: null,
          ),
        ),
      ),
    );
    if (result != null && result.isNotEmpty) {
      return result.first ?? 0;
    }
    return -1; // Cancelled
  }

  String _locationName(int? id) {
    return _locations.pathFor(id);
  }

  Future<void> _quickConsume(Item item) async {
    try {
      final updated = await widget.api.consumeItem(item.id);
      if (updated.quantity == 0 && mounted) {
        final addToWishlist = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Out of Stock!'),
            content: Text('"${item.name}" is now out of stock. Add to your Wishlist?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add to Wishlist')),
            ],
          ),
        );
        if (addToWishlist == true) {
          await widget.api.updateItem(item.id, {'is_wishlist': true});
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added "${item.name}" to Wishlist')));
        }
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _quickRestock(Item item) async {
    try {
      await widget.api.restockItem(item.id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _quickMarkBought(Item item) async {
    try {
      await widget.api.markItemBought(item.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked "${item.name}" as bought!')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final embedded = widget.fixedLocation == null;
    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectionMode = false;
                    _selectedItemIds.clear();
                  });
                },
              ),
              title: Text('${_selectedItemIds.length} selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.drive_file_move_outline),
                  tooltip: 'Move Selected',
                  onPressed: _selectedItemIds.isEmpty ? null : _moveSelected,
                ),
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Select All',
                  onPressed: () {
                    setState(() {
                      if (_selectedItemIds.length == _items.length) {
                        _selectedItemIds.clear();
                      } else {
                        _selectedItemIds.addAll(_items.map((e) => e.id));
                      }
                    });
                  },
                ),
              ],
            )
          : AppBar(
              title: Text(_showWishlist ? 'Wishlist' : (widget.fixedLocation?.name ?? 'Recall')),
              automaticallyImplyLeading: !embedded,
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SearchBar(
                    controller: _search,
                    onChanged: _onSearchChanged,
                    hintText: 'Search name, description, serial…',
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (_search.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            _load();
                          },
                        ),
                    ],
                    elevation: WidgetStateProperty.all(0.0),
                    backgroundColor: WidgetStateProperty.all(
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                    ),
                    shape: WidgetStateProperty.all(
                      const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'True Recall',
                  isSelected: _advancedSearch,
                  onPressed: () {
                    setState(() => _advancedSearch = !_advancedSearch);
                    _load();
                  },
                  icon: const Icon(Icons.memory_outlined),
                  selectedIcon: const Icon(Icons.memory),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                FilterChip(
                  label: const Text('Wishlist'),
                  selected: _showWishlist,
                  onSelected: (val) {
                    setState(() {
                      _showWishlist = val;
                    });
                    _load();
                  },
                  avatar: const Icon(Icons.bookmark_outline, size: 16),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Consumables'),
                  selected: _showConsumablesOnly,
                  onSelected: (val) {
                    setState(() {
                      _showConsumablesOnly = val;
                      if (!val) {
                        _showLowStockOnly = false;
                      }
                    });
                    _load();
                  },
                  avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Low Stock'),
                  selected: _showLowStockOnly,
                  onSelected: (val) {
                    setState(() {
                      _showLowStockOnly = val;
                      if (val) {
                        _showConsumablesOnly = true;
                      }
                    });
                    _load();
                  },
                  avatar: const Icon(Icons.warning_amber_outlined, size: 16),
                ),
                const SizedBox(width: 8),
                if (embedded)
                  _filterChip<int>(
                    label: 'Location',
                    value: _locationId,
                    display: _locations.pathFor(_locationId),
                    entries: _locations.map((l) => MapEntry(l.id, _locations.pathFor(l.id))).toList(),
                    onChanged: (v) {
                      setState(() => _locationId = v);
                      _load();
                    },
                  ),
                if (embedded) const SizedBox(width: 8),
                _filterChip<int>(
                  label: 'Label',
                  value: _labelId,
                  display: _labels
                      .where((l) => l.id == _labelId)
                      .map((l) => l.name)
                      .join(),
                  entries: _labels.map((l) => MapEntry(l.id, l.name)).toList(),
                  onChanged: (v) {
                    setState(() => _labelId = v);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Archived'),
                  selected: _showArchived,
                  onSelected: (val) {
                    setState(() => _showArchived = val);
                    _load();
                  },
                  avatar: const Icon(Icons.archive_outlined, size: 16),
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ItemEditScreen(
                api: widget.api,
                initialLocationId: widget.fixedLocation?.id,
              ),
            ),
          );
          if (created == true) _load(withFilters: true);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _filterChip<T>({
    required String label,
    required T? value,
    required String display,
    required List<MapEntry<T, String>> entries,
    required ValueChanged<T?> onChanged,
  }) {
    return FilterChip(
      selected: value != null,
      label: Text(value == null ? label : '$label: $display'),
      onSelected: (_) async {
        final result = await showModalBottomSheet<List<T?>>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _FilterModal<T>(
                label: label,
                entries: entries,
                currentValue: value,
              ),
            ),
          ),
        );
        if (result != null) {
          onChanged(result.first);
        }
      },
      onDeleted: value == null ? null : () => onChanged(null),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => _load(withFilters: true), child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      String message = 'No items found — tap + to add one.';
      if (_showWishlist && _showConsumablesOnly) {
        message = 'No consumable items on your Wishlist.';
      } else if (_showWishlist) {
        message = 'Wishlist is empty — tap + to add a wishlist item.';
      } else if (_showConsumablesOnly) {
        message = _showLowStockOnly ? 'No low stock consumable items.' : 'No consumable items found.';
      }
      return Center(
        child: Text(message),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(withFilters: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final item = _items[i];
          final locationName = _locationName(item.locationId);
          final isSelected = _selectedItemIds.contains(item.id);

          String subtitleText = [
            if (locationName.isNotEmpty) locationName,
            if (!item.isConsumable && item.quantity != 1) 'x${NumberFormat('#,###').format(item.quantity)}',
            if (item.warrantyActive) 'warranty',
          ].join(' · ');

          Widget? trailingWidget;
          if (!_selectionMode) {
            if (item.isWishlist) {
              trailingWidget = IconButton(
                icon: const Icon(Icons.shopping_bag_outlined, color: Colors.green),
                tooltip: 'Mark as Bought',
                onPressed: () => _quickMarkBought(item),
              );
            } else if (item.isConsumable) {
              trailingWidget = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    tooltip: 'Consume 1',
                    onPressed: () => _quickConsume(item),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final updated = await showQuantityAdjustmentSheet(
                        context: context,
                        api: widget.api,
                        item: item,
                      );
                      if (updated != null) _load();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        '${item.quantity}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: item.isOutOfStock
                              ? Colors.red
                              : (item.isLowStock ? Colors.orange : null),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: 'Restock 1',
                    onPressed: () => _quickRestock(item),
                  ),
                ],
              );
            }
          }

          final tile = ListTile(
            selected: isSelected,
            selectedColor: Theme.of(context).colorScheme.onSecondaryContainer,
            selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
            leading: _selectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedItemIds.add(item.id);
                        } else {
                          _selectedItemIds.remove(item.id);
                          if (_selectedItemIds.isEmpty) _selectionMode = false;
                        }
                      });
                    },
                  )
                : _thumbnail(item),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      decoration: item.isOutOfStock ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (item.isWishlist) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Wishlist',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple),
                    ),
                  ),
                ] else if (item.isOutOfStock) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Out of Stock',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                ] else if (item.isLowStock) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Low Stock',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(subtitleText.isEmpty ? (item.isWishlist ? 'No location assigned' : '') : subtitleText),
            trailing: trailingWidget,
            onLongPress: _selectionMode
                ? null
                : () {
                    setState(() {
                      _selectionMode = true;
                      _selectedItemIds.add(item.id);
                    });
                  },
            onTap: _selectionMode
                ? () {
                    setState(() {
                      if (isSelected) {
                        _selectedItemIds.remove(item.id);
                        if (_selectedItemIds.isEmpty) _selectionMode = false;
                      } else {
                        _selectedItemIds.add(item.id);
                      }
                    });
                  }
                : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(api: widget.api, itemId: item.id),
                      ),
                    );
                    _load(withFilters: true);
                  },
          );

          if (item.isConsumable && !item.isWishlist && !_selectionMode) {
            return Dismissible(
              key: ValueKey('item_${item.id}_${item.quantity}'),
              direction: DismissDirection.horizontal,
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  await _quickRestock(item);
                } else if (direction == DismissDirection.endToStart) {
                  await _quickConsume(item);
                }
                return false;
              },
              background: Container(
                color: Colors.green.shade700,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                child: const Row(
                  children: [
                    Icon(Icons.add_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Restock +1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              secondaryBackground: Container(
                color: Colors.orange.shade800,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Consume -1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.remove_circle, color: Colors.white),
                  ],
                ),
              ),
              child: tile,
            );
          }

          return tile;
        },
      ),
    );
  }

  Widget _thumbnail(Item item) {
    final hasPhoto = item.coverPhotoId != null;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: hasPhoto ? Colors.transparent : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? CachedNetworkImage(
              imageUrl: widget.api.photoUrl(item.coverPhotoId!),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const Icon(Icons.image_not_supported),
            )
          : Center(
              child: Text(
                item.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
    );
  }
}

class _FilterModal<T> extends StatefulWidget {
  final String label;
  final List<MapEntry<T, String>> entries;
  final T? currentValue;

  const _FilterModal({
    required this.label,
    required this.entries,
    this.currentValue,
  });

  @override
  State<_FilterModal<T>> createState() => _FilterModalState<T>();
}

class _FilterModalState<T> extends State<_FilterModal<T>> {
  final _searchController = TextEditingController();
  late List<MapEntry<T, String>> _filteredEntries;

  @override
  void initState() {
    super.initState();
    _filteredEntries = widget.entries;
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
      _filteredEntries = widget.entries.where((e) {
        final val = e.value.toLowerCase();
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
                  'Select ${widget.label}',
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
              hintText: 'Search ${widget.label}...',
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
          child: ListView(
            children: [
              ListTile(
                title: Text('All', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                onTap: () => Navigator.pop(context, <T?>[null]),
                trailing: widget.currentValue == null ? const Icon(Icons.check) : null,
              ),
              ..._filteredEntries.map((e) => ListTile(
                title: Text(e.value),
                onTap: () => Navigator.pop(context, <T?>[e.key]),
                trailing: widget.currentValue == e.key ? const Icon(Icons.check) : null,
              )),
            ],
          ),
        ),
      ],
    );
  }
}
