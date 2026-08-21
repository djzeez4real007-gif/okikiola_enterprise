import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/stock_in.dart';
import 'audit_log_storage.dart';
import 'auth_service.dart';
import 'hive_boxes.dart';
import 'product_storage.dart';

class StockInStorage {
  static Box get _box => Hive.box(HiveBoxes.stockIns);

  static Future<List<StockInRecord>> getAll() async {
    final list = _box.values
        .map((e) => StockInRecord.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return list;
  }

  /// Receive goods: increase stock + optional cost update + audit.
  static Future<StockInRecord> receive({
    required String supplier,
    required String reference,
    required String reason,
    required List<StockInLine> lines,
    String note = '',
    bool updateCostPrice = false,
  }) async {
    if (lines.isEmpty) throw Exception('Add at least one product');
    for (final l in lines) {
      if (l.quantity <= 0) {
        throw Exception('Quantity must be greater than 0 for ${l.productName}');
      }
    }

    final products = await ProductStorage.getAll();
    final byId = {for (final p in products) p.id: p};

    for (final line in lines) {
      final p = byId[line.productId];
      if (p == null) throw Exception('Product missing: ${line.productName}');
      final newQty = p.quantity + line.quantity;
      await ProductStorage.adjustQuantity(
        product: p,
        newQty: newQty,
        reason:
            'Stock in ($reason)${reference.isNotEmpty ? ' ref $reference' : ''}: +${line.quantity}',
      );
      if (updateCostPrice && line.unitCost > 0) {
        final idx = await ProductStorage.indexOfId(p.id);
        if (idx >= 0) {
          final refreshed = (await ProductStorage.getAll())
              .firstWhere((x) => x.id == p.id);
          final updated = refreshed.copyWith(
            costPrice: line.unitCost,
            updatedAt: DateTime.now().toIso8601String(),
          );
          await ProductStorage.update(idx, updated);
        }
      }
    }

    final user = AuthService.currentUser;
    final total = lines.fold<double>(0, (s, l) => s + l.lineCost);
    final record = StockInRecord(
      id: const Uuid().v4(),
      supplier: supplier.trim(),
      reference: reference.trim(),
      reason: reason,
      lines: lines,
      totalCost: total,
      receivedById: user?.id ?? '',
      receivedByName: user?.name ?? '',
      receivedAt: DateTime.now().toIso8601String(),
      note: note.trim(),
    );
    await _box.add(record.toMap());
    await AuditLogStorage.log(
      action: 'stock_in',
      module: 'stock_in',
      description:
          'Stock in: ${lines.length} line(s), ₦${total.toStringAsFixed(0)} '
          '($reason)${supplier.isNotEmpty ? ' from $supplier' : ''} '
          'by ${record.receivedByName}',
      refId: record.id,
    );
    return record;
  }
}
