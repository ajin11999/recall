class Label {
  Label({required this.id, required this.name, this.color, this.itemCount = 0});

  final int id;
  final String name;
  final String? color;
  final int itemCount;

  factory Label.fromJson(Map<String, dynamic> j) => Label(
        id: j['id'] as int,
        name: j['name'] as String,
        color: j['color'] as String?,
        itemCount: (j['item_count'] as int?) ?? 0,
      );
}

class Location {
  Location({
    required this.id,
    required this.name,
    this.parentId,
    this.description,
    this.itemCount = 0,
  });

  final int id;
  final String name;
  final int? parentId;
  final String? description;
  final int itemCount;

  factory Location.fromJson(Map<String, dynamic> j) => Location(
        id: j['id'] as int,
        name: j['name'] as String,
        parentId: j['parent_id'] as int?,
        description: j['description'] as String?,
        itemCount: (j['item_count'] as int?) ?? 0,
      );
}

class Photo {
  Photo({required this.id, required this.itemId});

  final int id;
  final int itemId;

  factory Photo.fromJson(Map<String, dynamic> j) =>
      Photo(id: j['id'] as int, itemId: j['item_id'] as int);
}

class MaintenanceSchedule {
  MaintenanceSchedule({
    required this.id,
    required this.itemId,
    required this.name,
    this.notes,
    required this.intervalDays,
    required this.nextDueDate,
    this.itemName,
  });

  final int id;
  final int itemId;
  final String name;
  final String? notes;
  final int intervalDays;
  final String nextDueDate; // YYYY-MM-DD
  final String? itemName;

  bool get isOverdue {
    final due = DateTime.tryParse(nextDueDate);
    if (due == null) return false;
    final now = DateTime.now();
    return due.isBefore(DateTime(now.year, now.month, now.day));
  }

  factory MaintenanceSchedule.fromJson(Map<String, dynamic> j) => MaintenanceSchedule(
        id: j['id'] as int,
        itemId: j['item_id'] as int,
        name: j['name'] as String,
        notes: j['notes'] as String?,
        intervalDays: j['interval_days'] as int,
        nextDueDate: j['next_due_date'] as String,
        itemName: j['item_name'] as String?,
      );
}

class MaintenanceLog {
  MaintenanceLog({required this.id, required this.completedAt, this.notes, this.cost});

  final int id;
  final String completedAt;
  final String? notes;
  final num? cost;

  factory MaintenanceLog.fromJson(Map<String, dynamic> j) => MaintenanceLog(
        id: j['id'] as int,
        completedAt: j['completed_at'] as String,
        notes: j['notes'] as String?,
        cost: j['cost'] as num?,
      );
}

class Item {
  Item({
    required this.id,
    required this.name,
    this.description,
    required this.quantity,
    this.locationId,
    this.serialNumber,
    this.purchasePrice,
    this.purchaseDate,
    this.purchasedFrom,
    this.warrantyUntil,
    this.notes,
    this.coverPhotoId,
    this.labelIds = const [],
    this.labels = const [],
    this.photos = const [],
    this.schedules = const [],
    this.isArchived = false,
    this.isConsumable = false,
    this.minQuantity = 0,
    this.isWishlist = false,
  });

  final int id;
  final String name;
  final String? description;
  final int quantity;
  final int? locationId;
  final String? serialNumber;
  final num? purchasePrice;
  final String? purchaseDate;
  final String? purchasedFrom;
  final String? warrantyUntil;
  final String? notes;
  final int? coverPhotoId;
  final List<int> labelIds;
  final List<Label> labels;
  final List<Photo> photos;
  final List<MaintenanceSchedule> schedules;
  final bool isArchived;
  final bool isConsumable;
  final int minQuantity;
  final bool isWishlist;

  bool get warrantyActive {
    final until = warrantyUntil == null ? null : DateTime.tryParse(warrantyUntil!);
    if (until == null) return false;
    final now = DateTime.now();
    return !until.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool get isLowStock => isConsumable && !isWishlist && quantity <= minQuantity;
  bool get isOutOfStock => isConsumable && !isWishlist && quantity == 0;

  static bool _parseBool(dynamic val) {
    if (val is bool) return val;
    if (val is int) return val == 1;
    if (val is String) return val == '1' || val.toLowerCase() == 'true';
    return false;
  }

  Item copyWith({
    int? id,
    String? name,
    String? description,
    int? quantity,
    int? locationId,
    String? serialNumber,
    num? purchasePrice,
    String? purchaseDate,
    String? purchasedFrom,
    String? warrantyUntil,
    String? notes,
    int? coverPhotoId,
    List<int>? labelIds,
    List<Label>? labels,
    List<Photo>? photos,
    List<MaintenanceSchedule>? schedules,
    bool? isArchived,
    bool? isConsumable,
    int? minQuantity,
    bool? isWishlist,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      locationId: locationId ?? this.locationId,
      serialNumber: serialNumber ?? this.serialNumber,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasedFrom: purchasedFrom ?? this.purchasedFrom,
      warrantyUntil: warrantyUntil ?? this.warrantyUntil,
      notes: notes ?? this.notes,
      coverPhotoId: coverPhotoId ?? this.coverPhotoId,
      labelIds: labelIds ?? this.labelIds,
      labels: labels ?? this.labels,
      photos: photos ?? this.photos,
      schedules: schedules ?? this.schedules,
      isArchived: isArchived ?? this.isArchived,
      isConsumable: isConsumable ?? this.isConsumable,
      minQuantity: minQuantity ?? this.minQuantity,
      isWishlist: isWishlist ?? this.isWishlist,
    );
  }

  factory Item.fromJson(Map<String, dynamic> j) {
    final labels = (j['labels'] as List?)
            ?.map((e) => Label.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <Label>[];
    return Item(
      id: j['id'] as int,
      name: j['name'] as String,
      description: j['description'] as String?,
      quantity: (j['quantity'] as int?) ?? 1,
      locationId: j['location_id'] as int?,
      serialNumber: j['serial_number'] as String?,
      purchasePrice: j['purchase_price'] as num?,
      purchaseDate: j['purchase_date'] as String?,
      purchasedFrom: j['purchased_from'] as String?,
      warrantyUntil: j['warranty_until'] as String?,
      notes: j['notes'] as String?,
      coverPhotoId: (j['cover_photo_id'] as int?) ??
          ((j['photos'] as List?)?.firstOrNull?['id'] as int?),
      labelIds: (j['label_ids'] as List?)?.cast<int>() ??
          labels.map((l) => l.id).toList(),
      labels: labels,
      photos: (j['photos'] as List?)
              ?.map((e) => Photo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      schedules: (j['maintenance_schedules'] as List?)
              ?.map((e) => MaintenanceSchedule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isArchived: _parseBool(j['is_archived']),
      isConsumable: _parseBool(j['is_consumable']),
      minQuantity: (j['min_quantity'] as num?)?.toInt() ?? 0,
      isWishlist: _parseBool(j['is_wishlist']),
    );
  }
}

class ItemPage {
  ItemPage({required this.items, required this.total});

  final List<Item> items;
  final int total;

  factory ItemPage.fromJson(Map<String, dynamic> j) => ItemPage(
        items: (j['items'] as List)
            .map((e) => Item.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: j['total'] as int,
      );
}

extension LocationListX on List<Location> {
  String pathFor(int? id) {
    if (id == null) return '';
    final map = {for (final l in this) l.id: l};
    var curr = map[id];
    if (curr == null) return '';
    final path = <String>[];
    final seen = <int>{};
    while (curr != null && seen.add(curr.id)) {
      path.add(curr.name);
      curr = map[curr.parentId];
    }
    return path.reversed.join(' > ');
  }

  List<(Location, int)> buildTree() {
    final allIds = {for (final l in this) l.id};
    final byParent = <int?, List<Location>>{};
    for (final l in this) {
      final pid = (l.parentId != null && allIds.contains(l.parentId)) ? l.parentId : null;
      byParent.putIfAbsent(pid, () => []).add(l);
    }
    final out = <(Location, int)>[];
    void walk(int? parentId, int depth, Set<int> seen) {
      for (final l in byParent[parentId] ?? const <Location>[]) {
        if (!seen.add(l.id)) continue;
        out.add((l, depth));
        walk(l.id, depth + 1, seen);
      }
    }
    walk(null, 0, <int>{});
    return out;
  }
}
