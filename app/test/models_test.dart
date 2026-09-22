import 'package:flutter_test/flutter_test.dart';
import 'package:recall/models.dart';
import 'package:recall/screens/labels_screen.dart';

void main() {
  group('Item model tests', () {
    test('warrantyActive behaves correctly across dates', () {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

      final itemToday = Item(id: 1, name: 'Phone', quantity: 1, warrantyUntil: todayStr);
      expect(itemToday.warrantyActive, isTrue, reason: 'Warranty on today should be active throughout the day');

      final itemTomorrow = Item(id: 2, name: 'Phone', quantity: 1, warrantyUntil: tomorrowStr);
      expect(itemTomorrow.warrantyActive, isTrue);

      final itemYesterday = Item(id: 3, name: 'Phone', quantity: 1, warrantyUntil: yesterdayStr);
      expect(itemYesterday.warrantyActive, isFalse);

      final itemNull = Item(id: 4, name: 'Phone', quantity: 1, warrantyUntil: null);
      expect(itemNull.warrantyActive, isFalse);
    });

    test('Item.fromJson fallbacks coverPhotoId to first photo if cover_photo_id is null', () {
      final json = {
        'id': 10,
        'name': 'Camera',
        'quantity': 1,
        'cover_photo_id': null,
        'photos': [
          {'id': 101, 'item_id': 10, 'content_type': 'image/jpeg', 'created_at': '2026-01-01', 'sort_order': 0},
          {'id': 102, 'item_id': 10, 'content_type': 'image/jpeg', 'created_at': '2026-01-01', 'sort_order': 1},
        ],
      };

      final item = Item.fromJson(json);
      expect(item.coverPhotoId, equals(101));
    });

    test('Item.copyWith preserves and overrides fields correctly', () {
      final item = Item(
        id: 1,
        name: 'Hammer',
        quantity: 3,
        description: 'Heavy',
        locationId: 5,
        minQuantity: 1,
        isConsumable: true,
      );

      final updated = item.copyWith(
        quantity: 2,
        name: 'Mallet',
      );

      expect(updated.id, equals(1));
      expect(updated.name, equals('Mallet'));
      expect(updated.quantity, equals(2));
      expect(updated.description, equals('Heavy'));
      expect(updated.locationId, equals(5));
      expect(updated.minQuantity, equals(1));
      expect(updated.isConsumable, isTrue);
    });
  });

  group('Location extensions tests', () {
    test('pathFor resolves simple and nested paths', () {
      final List<Location> locations = [
        Location(id: 1, name: 'House'),
        Location(id: 2, name: 'Basement', parentId: 1),
        Location(id: 3, name: 'Toolbox', parentId: 2),
      ];

      expect(locations.pathFor(1), equals('House'));
      expect(locations.pathFor(2), equals('House > Basement'));
      expect(locations.pathFor(3), equals('House > Basement > Toolbox'));
    });

    test('pathFor handles circular references safely without infinite loop', () {
      final List<Location> circularLocations = [
        Location(id: 1, name: 'A', parentId: 2),
        Location(id: 2, name: 'B', parentId: 1),
      ];

      // Should not throw or hang
      final path = circularLocations.pathFor(1);
      expect(path, isNotEmpty);
    });

    test('pathFor handles orphaned / missing parents gracefully', () {
      final List<Location> orphaned = [
        Location(id: 1, name: 'Child', parentId: 999),
      ];

      expect(orphaned.pathFor(1), equals('Child'));
    });

    test('buildTree builds tree and handles missing parents gracefully', () {
      final List<Location> locations = [
        Location(id: 1, name: 'Root'),
        Location(id: 2, name: 'Child', parentId: 1),
        Location(id: 3, name: 'Orphan', parentId: 999),
      ];

      final tree = locations.buildTree();
      expect(tree.length, equals(3));
      expect(tree[0].$1.name, equals('Root'));
      expect(tree[0].$2, equals(0));
      expect(tree[1].$1.name, equals('Child'));
      expect(tree[1].$2, equals(1));
      expect(tree[2].$1.name, equals('Orphan'));
      expect(tree[2].$2, equals(0));
    });
  });

  group('labels colorFromHex tests', () {
    test('parses valid 6-character hex colors', () {
      final c1 = colorFromHex('#e05d38');
      expect(c1, isNotNull);
      expect(c1!.toARGB32(), equals(0xFFe05d38));

      final c2 = colorFromHex('#FFFFFF');
      expect(c2, isNotNull);
      expect(c2!.toARGB32(), equals(0xFFFFFFFF));
    });

    test('returns null for invalid hex colors or null', () {
      expect(colorFromHex(null), isNull);
      expect(colorFromHex(''), isNull);
      expect(colorFromHex('#123'), isNull);
      expect(colorFromHex('red'), isNull);
      expect(colorFromHex('#1234567'), isNull);
      expect(colorFromHex('#gggggg'), isNull);
    });
  });
}
