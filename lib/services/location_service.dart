import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/shop_location.dart';
import 'audit_log_storage.dart';
import 'auth_service.dart';
import 'hive_boxes.dart';
import 'product_storage.dart';

/// Current working location + location CRUD.
class LocationService {
  static final ValueNotifier<ShopLocation?> currentListenable =
      ValueNotifier<ShopLocation?>(null);

  static ShopLocation? get current => currentListenable.value;
  static String? get currentId => current?.id;

  static Box get _locBox => Hive.box(HiveBoxes.locations);
  static Box get _stockBox => Hive.box(HiveBoxes.locationStock);
  static Box get _settings => Hive.box(HiveBoxes.settings);

  static List<ShopLocation> all({bool activeOnly = false}) {
    final list = _locBox.values
        .map((e) => ShopLocation.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    if (activeOnly) return list.where((l) => l.active).toList();
    return list;
  }

  /// First run: create Main Shop and migrate product.qty into location stock.
  static Future<void> ensureDefaultLocation() async {
    if (_locBox.isNotEmpty) {
      await _restoreCurrent();
      return;
    }
    final main = ShopLocation(
      id: const Uuid().v4(),
      name: 'Main Shop',
      address: '',
      isDefault: true,
      createdAt: DateTime.now().toIso8601String(),
    );
    await _locBox.add(main.toMap());

    // Migrate existing product quantities to Main Shop
    final products = await ProductStorage.getAll();
    for (final p in products) {
      await _setStockRaw(main.id, p.id, p.quantity);
    }

    await _settings.put('currentLocationId', main.id);
    currentListenable.value = main;
  }

  /// If product has global qty but current location stock is 0, assign global to current location
  /// (fixes products created before multi-location or migration gaps).
  static Future<void> repairOrphanStock() async {
    final locId = currentId;
    if (locId == null) return;
    final products = await ProductStorage.getAll();
    for (final p in products) {
      final locQty = getStock(locId, p.id);
      if (locQty == 0 && p.quantity > 0) {
        // Check if qty exists on ANY location
        double elsewhere = 0;
        for (final l in all()) {
          if (l.id == locId) continue;
          elsewhere += getStock(l.id, p.id);
        }
        if (elsewhere == 0) {
          // All qty orphaned on product record — place on current location
          await _setStockRaw(locId, p.id, p.quantity);
        } else if ((elsewhere - p.quantity).abs() > 0.01) {
          // Resync product total from locations
          await _syncProductTotal(p.id);
        }
      }
    }
  }

  static Future<void> _restoreCurrent() async {
    final id = _settings.get('currentLocationId')?.toString();
    final list = all(activeOnly: true);
    ShopLocation? loc;
    if (id != null) {
      for (final l in list) {
        if (l.id == id) {
          loc = l;
          break;
        }
      }
    }
    loc ??= list.isNotEmpty ? list.first : null;
    if (loc == null) {
      // recreate main if somehow empty active
      await ensureDefaultLocation();
      return;
    }
    currentListenable.value = loc;
    await repairOrphanStock();
  }

  static Future<void> switchTo(String locationId) async {
    final list = all();
    ShopLocation? loc;
    for (final l in list) {
      if (l.id == locationId) {
        loc = l;
        break;
      }
    }
    if (loc == null) throw Exception('Location not found');
    if (!loc.active) throw Exception('Location is inactive');
    await _settings.put('currentLocationId', loc.id);
    currentListenable.value = loc;
    await AuditLogStorage.log(
      action: 'location_switched',
      module: 'locations',
      description:
          '${AuthService.currentName} switched to ${loc.name}',
      refId: loc.id,
    );
  }

  static Future<ShopLocation> create({
    required String name,
    String address = '',
    String phone = '',
  }) async {
    if (name.trim().isEmpty) throw Exception('Name required');
    final loc = ShopLocation(
      id: const Uuid().v4(),
      name: name.trim(),
      address: address.trim(),
      phone: phone.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    await _locBox.add(loc.toMap());
    // New location starts with zero stock (catalogue shared)
    await AuditLogStorage.log(
      action: 'location_created',
      module: 'locations',
      description: 'Created location ${loc.name} by ${AuthService.currentName}',
      refId: loc.id,
    );
    return loc;
  }

  static Future<void> update(ShopLocation loc) async {
    final values = _locBox.values.toList();
    for (var i = 0; i < values.length; i++) {
      final map = Map<String, dynamic>.from(values[i] as Map);
      if (map['id'] == loc.id) {
        await _locBox.putAt(i, loc.toMap());
        if (currentId == loc.id) currentListenable.value = loc;
        return;
      }
    }
  }

  // ——— Stock per location ———

  static String _stockKey(String locationId, String productId) =>
      '${locationId}__$productId';

  static double getStock(String locationId, String productId) {
    final v = _stockBox.get(_stockKey(locationId, productId));
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is Map) return (v['qty'] as num?)?.toDouble() ?? 0;
    return 0;
  }

  static double getStockCurrent(String productId) {
    final id = currentId;
    if (id == null) return 0;
    return getStock(id, productId);
  }

  static Future<void> _setStockRaw(
    String locationId,
    String productId,
    double qty,
  ) async {
    await _stockBox.put(_stockKey(locationId, productId), {
      'locationId': locationId,
      'productId': productId,
      'qty': qty,
    });
  }

  static Future<void> setStock(
    String locationId,
    String productId,
    double qty, {
    required String reason,
  }) async {
    final old = getStock(locationId, productId);
    await _setStockRaw(locationId, productId, qty < 0 ? 0 : qty);
    // Keep product.quantity as sum across locations for legacy screens
    await _syncProductTotal(productId);
    await AuditLogStorage.log(
      action: 'location_stock_set',
      module: 'locations',
      description:
          'Stock $productId @ $locationId: $old → $qty. $reason',
      refId: productId,
    );
  }

  static Future<void> adjustStock(
    String locationId,
    String productId,
    double delta, {
    required String reason,
  }) async {
    final old = getStock(locationId, productId);
    final next = old + delta;
    if (next < -0.0001) {
      throw Exception('Not enough stock at this location');
    }
    await _setStockRaw(locationId, productId, next < 0 ? 0 : next);
    await _syncProductTotal(productId);
    await AuditLogStorage.log(
      action: 'location_stock_adjust',
      module: 'locations',
      description:
          'Stock $productId @ $locationId: $old → ${next < 0 ? 0 : next} ($delta). $reason',
      refId: productId,
    );
  }

  static Future<void> _syncProductTotal(String productId) async {
    final locs = all();
    double sum = 0;
    for (final l in locs) {
      sum += getStock(l.id, productId);
    }
    final products = await ProductStorage.getAll();
    for (final p in products) {
      if (p.id != productId) continue;
      final idx = await ProductStorage.indexOfId(p.id);
      if (idx < 0) return;
      final updated = p.copyWith(
        quantity: sum,
        updatedAt: DateTime.now().toIso8601String(),
      );
      // Silent put without full audit spam
      final box = Hive.box(HiveBoxes.products);
      await box.putAt(idx, updated.toMap());
      return;
    }
  }

  /// Transfer qty from one location to another.
  static Future<void> transfer({
    required String productId,
    required String productName,
    required String fromLocationId,
    required String toLocationId,
    required double quantity,
    String note = '',
  }) async {
    if (fromLocationId == toLocationId) {
      throw Exception('Choose different locations');
    }
    if (quantity <= 0) throw Exception('Quantity must be positive');
    final available = getStock(fromLocationId, productId);
    if (available + 0.0001 < quantity) {
      throw Exception('Only $available available at source location');
    }
    await adjustStock(
      fromLocationId,
      productId,
      -quantity,
      reason: 'Transfer out to $toLocationId ($productName)',
    );
    await adjustStock(
      toLocationId,
      productId,
      quantity,
      reason: 'Transfer in from $fromLocationId ($productName)',
    );

    final transferBox = Hive.box(HiveBoxes.stockTransfers);
    await transferBox.add({
      'id': const Uuid().v4(),
      'productId': productId,
      'productName': productName,
      'fromLocationId': fromLocationId,
      'toLocationId': toLocationId,
      'quantity': quantity,
      'note': note,
      'byId': AuthService.currentUser?.id ?? '',
      'byName': AuthService.currentName,
      'at': DateTime.now().toIso8601String(),
    });

    final fromName = all().firstWhere((l) => l.id == fromLocationId).name;
    final toName = all().firstWhere((l) => l.id == toLocationId).name;
    await AuditLogStorage.log(
      action: 'stock_transfer',
      module: 'locations',
      description:
          'Transfer $quantity × $productName: $fromName → $toName by ${AuthService.currentName}',
      refId: productId,
    );
  }

  static List<Map<String, dynamic>> transferHistory() {
    final box = Hive.box(HiveBoxes.stockTransfers);
    final list = box.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    list.sort((a, b) =>
        (b['at'] ?? '').toString().compareTo((a['at'] ?? '').toString()));
    return list;
  }
}
