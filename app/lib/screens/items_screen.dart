import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../models.dart';
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
              title: Text(widget.fixedLocation?.name ?? 'Recall'),
              automaticallyImplyLeading: !embedded,
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
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
                FilterChip(
                  label: const Text('True Recall'),
                  selected: _advancedSearch,
                  onSelected: (val) {
                    setState(() => _advancedSearch = val);
                    _load();
                  },
                  avatar: const Icon(Icons.memory, size: 16),
                ),
                const SizedBox(width: 8),
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
      return const Center(child: Text('No items yet — tap + to add one.'));
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
          return ListTile(
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
            title: Text(item.name),
            subtitle: Text(
              [
                if (locationName.isNotEmpty) locationName,
                if (item.quantity != 1) 'x${NumberFormat('#,###').format(item.quantity)}',
                if (item.warrantyActive) 'warranty',
              ].join(' · '),
            ),
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
