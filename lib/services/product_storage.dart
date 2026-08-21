import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import 'audit_log_storage.dart';
import 'auth_service.dart';
import 'hive_boxes.dart';
import 'location_service.dart';

class ProductStorage {
  static Box get _box => Hive.box(HiveBoxes.products);

  static Future<List<Product>> getAll() async {
    final list = _box.values
        .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  static Future<void> add(Product product) async {
    await _box.add(product.toMap());
    await AuditLogStorage.log(
      action: 'product_added',
      module: 'products',
      description: 'Added product ${product.name} (${product.sku})',
      refId: product.id,
    );
  }

  static Future<void> update(int index, Product product) async {
    await _box.putAt(index, product.toMap());
    await AuditLogStorage.log(
      action: 'product_updated',
      module: 'products',
      description: 'Updated product ${product.name} (${product.sku})',
      refId: product.id,
    );
  }

  static Future<void> delete(int index, Product product) async {
    await _box.deleteAt(index);
    await AuditLogStorage.log(
      action: 'product_deleted',
      module: 'products',
      description: 'Deleted product ${product.name} (${product.sku})',
      refId: product.id,
    );
  }

  static Future<int> indexOfId(String id) async {
    final values = _box.values.toList();
    for (var i = 0; i < values.length; i++) {
      final map = Map<String, dynamic>.from(values[i] as Map);
      if (map['id']?.toString() == id) return i;
    }
    return -1;
  }

  static Future<Product> create({
    required String name,
    required String sku,
    required String category,
    required String unit,
    required double costPrice,
    required double sellingPrice,
    required double quantity,
    required double reorderLevel,
    String description = '',
  }) async {
    final now = DateTime.now().toIso8601String();
    final product = Product(
      id: const Uuid().v4(),
      name: name.trim(),
      sku: sku.trim().toUpperCase(),
      category: category.trim().isEmpty ? 'General' : category.trim(),
      unit: unit,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      quantity: quantity,
      reorderLevel: reorderLevel,
      description: description.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await add(product);
    // Multi-location: opening qty goes to current shop
    final locId = LocationService.currentId;
    if (locId != null && quantity != 0) {
      await LocationService.setStock(
        locId,
        product.id,
        quantity,
        reason: 'Opening stock on product create',
      );
    }
    return product;
  }

  /// Stock change with mandatory reason (anti-theft trail).
  static Future<void> adjustQuantity({
    required Product product,
    required double newQty,
    required String reason,
  }) async {
    final locId = LocationService.currentId;
    if (locId != null) {
      // Location-aware: set qty at current shop, then sync product total
      // newQty here is treated as NEW QTY AT CURRENT LOCATION when called from sales/stock-in
      // But existing callers pass absolute product.quantity after math on global qty.
      // Sales does: newQty = p.quantity - item.quantity (global).
      // With multi-location, sales should deduct from current location only.
      // Detect delta from current location stock when reason starts with Sale / Stock in / Void
      final delta = newQty - product.quantity; // global delta from caller
      if (delta != 0) {
        await LocationService.adjustStock(
          locId,
          product.id,
          delta,
          reason: reason,
        );
        return;
      }
      await LocationService.setStock(
        locId,
        product.id,
        newQty,
        reason: reason,
      );
      return;
    }
    final idx = await indexOfId(product.id);
    if (idx < 0) return;
    final oldQty = product.quantity;
    final updated = product.copyWith(
      quantity: newQty,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _box.putAt(idx, updated.toMap());
    await AuditLogStorage.log(
      action: 'stock_adjusted',
      module: 'products',
      description:
          '${product.name}: $oldQty → $newQty ${product.unit}. Reason: $reason. By ${AuthService.currentName}',
      refId: product.id,
    );
  }

  static Future<String> nextSku() async {
    final all = await getAll();
    final n = all.length + 1;
    return 'OKL-${n.toString().padLeft(4, '0')}';
  }
}
