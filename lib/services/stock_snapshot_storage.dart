import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/stock_snapshot.dart';
import 'audit_log_storage.dart';
import 'auth_service.dart';
import 'hive_boxes.dart';
import 'product_storage.dart';

class StockSnapshotStorage {
  static Box get _box => Hive.box(HiveBoxes.stockSnapshots);

  static String dateKeyFor([DateTime? dt]) {
    final d = dt ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static Future<List<StockSnapshot>> getAll() async {
    final list = _box.values
        .map((e) =>
            StockSnapshot.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return list;
  }

  /// Snapshot for exact day, or null.
  static Future<StockSnapshot?> forDate(String dateKey) async {
    final all = await getAll();
    for (final s in all) {
      if (s.dateKey == dateKey) return s;
    }
    return null;
  }

  /// Nearest snapshot on or before [dateKey] (for month/year views).
  static Future<StockSnapshot?> asOf(String dateKey) async {
    final all = await getAll();
    StockSnapshot? best;
    for (final s in all) {
      if (s.dateKey.compareTo(dateKey) <= 0) {
        if (best == null || s.dateKey.compareTo(best.dateKey) > 0) {
          best = s;
        }
      }
    }
    return best;
  }

  /// Capture current inventory. Replaces existing snapshot for same day.
  static Future<StockSnapshot> capture({
    String source = 'manual',
    DateTime? at,
  }) async {
    final when = at ?? DateTime.now();
    final key = dateKeyFor(when);
    final products = await ProductStorage.getAll();
    final active = products.where((p) => p.active).toList();

    final lines = active
        .map(
          (p) => StockSnapshotLine(
            productId: p.id,
            productName: p.name,
            sku: p.sku,
            unit: p.unit,
            category: p.category,
            quantity: p.quantity,
            costPrice: p.costPrice,
            sellingPrice: p.sellingPrice,
            reorderLevel: p.reorderLevel,
          ),
        )
        .toList();

    final totalValue = lines.fold<double>(0, (s, l) => s + l.stockValue);
    final low = lines.where((l) => l.isLowStock).length;
    final user = AuthService.currentUser;

    final snap = StockSnapshot(
      id: const Uuid().v4(),
      dateKey: key,
      takenAt: when.toIso8601String(),
      takenById: user?.id ?? '',
      takenByName: user?.name ?? 'System',
      source: source,
      lines: lines,
      totalValue: totalValue,
      productCount: lines.length,
      lowStockCount: low,
    );

    // Replace same-day snapshot if exists
    final values = _box.values.toList();
    for (var i = 0; i < values.length; i++) {
      final map = Map<String, dynamic>.from(values[i] as Map);
      if (map['dateKey']?.toString() == key) {
        await _box.putAt(i, snap.toMap());
        await AuditLogStorage.log(
          action: 'stock_snapshot',
          module: 'inventory',
          description:
              'Stock snapshot updated for $key: ${lines.length} items, '
              'value ₦${totalValue.toStringAsFixed(0)} ($source)',
          refId: snap.id,
        );
        return snap;
      }
    }

    await _box.add(snap.toMap());
    await AuditLogStorage.log(
      action: 'stock_snapshot',
      module: 'inventory',
      description:
          'Stock snapshot for $key: ${lines.length} items, '
          'value ₦${totalValue.toStringAsFixed(0)} ($source)',
      refId: snap.id,
    );
    return snap;
  }
}
