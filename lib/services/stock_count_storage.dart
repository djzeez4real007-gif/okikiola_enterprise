import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/stock_count.dart';
import 'audit_log_storage.dart';
import 'auth_service.dart';
import 'hive_boxes.dart';
import 'product_storage.dart';
import 'stock_snapshot_storage.dart';
import 'location_service.dart';

class StockCountStorage {
  static Box get _box => Hive.box(HiveBoxes.stockCounts);

  static Future<List<StockCountSession>> getAll() async {
    final list = _box.values
        .map((e) =>
            StockCountSession.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  static Future<StockCountSession?> openDraft() async {
    final all = await getAll();
    for (final s in all) {
      if (s.status == 'draft') return s;
    }
    return null;
  }

  static Future<StockCountSession> startNew() async {
    final existing = await openDraft();
    if (existing != null) {
      throw Exception('Finish or discard the open stock count first');
    }
    final products = await ProductStorage.getAll();
    final active = products.where((p) => p.active).toList();
    if (active.isEmpty) {
      throw Exception('No products to count');
    }
    final user = AuthService.currentUser;
    final locId = LocationService.currentId;
    final session = StockCountSession(
      id: const Uuid().v4(),
      status: 'draft',
      startedAt: DateTime.now().toIso8601String(),
      startedById: user?.id ?? '',
      startedByName: user?.name ?? '',
      lines: active
          .map((p) {
            final qty = locId != null
                ? LocationService.getStock(locId, p.id)
                : p.quantity;
            return StockCountLine(
              productId: p.id,
              productName: p.name,
              sku: p.sku,
              unit: p.unit,
              systemQty: qty,
              countedQty: qty,
              costPrice: p.costPrice,
            );
          })
          .toList(),
    );
    await _box.add(session.toMap());
    await AuditLogStorage.log(
      action: 'stock_count_started',
      module: 'stock_count',
      description:
          'Stock count started by ${session.startedByName} (${session.lines.length} items)',
      refId: session.id,
    );
    return session;
  }

  static Future<void> saveDraft(StockCountSession session) async {
    final values = _box.values.toList();
    for (var i = 0; i < values.length; i++) {
      final map = Map<String, dynamic>.from(values[i] as Map);
      if (map['id'] == session.id) {
        await _box.putAt(i, session.toMap());
        return;
      }
    }
  }

  /// Complete count. If [applyAdjustments] true, set product qty to counted.
  static Future<StockCountSession> complete({
    required StockCountSession session,
    required bool applyAdjustments,
    String note = '',
  }) async {
    var lines = session.lines;
    final completed = StockCountSession(
      id: session.id,
      status: 'completed',
      startedAt: session.startedAt,
      completedAt: DateTime.now().toIso8601String(),
      startedById: session.startedById,
      startedByName: session.startedByName,
      lines: lines,
      note: note,
      appliedToStock: applyAdjustments,
    );

    if (applyAdjustments) {
      final products = await ProductStorage.getAll();
      final byId = {for (final p in products) p.id: p};
      final locId = LocationService.currentId;
      for (final line in lines) {
        if (!line.hasVariance) continue;
        final p = byId[line.productId];
        if (p == null) continue;
        if (locId != null) {
          await LocationService.setStock(
            locId,
            line.productId,
            line.countedQty,
            reason:
                'Stock count ${completed.id.substring(0, 8)}: system ${line.systemQty} → counted ${line.countedQty}',
          );
        } else {
          await ProductStorage.adjustQuantity(
            product: p,
            newQty: line.countedQty,
            reason:
                'Stock count ${completed.id.substring(0, 8)}: system ${line.systemQty} → counted ${line.countedQty}',
          );
        }
      }
    }

    final values = _box.values.toList();
    for (var i = 0; i < values.length; i++) {
      final map = Map<String, dynamic>.from(values[i] as Map);
      if (map['id'] == session.id) {
        await _box.putAt(i, completed.toMap());
        break;
      }
    }

    await AuditLogStorage.log(
      action: 'stock_count_completed',
      module: 'stock_count',
      description:
          'Stock count done by ${AuthService.currentName}: '
          '${completed.varianceLines} variance(s), '
          'shrink ₦${completed.totalShrinkValue.toStringAsFixed(0)}, '
          'over ₦${completed.totalOverValue.toStringAsFixed(0)}'
          '${applyAdjustments ? ' · stock updated' : ' · stock not changed'}',
      refId: session.id,
    );
        try {
      await StockSnapshotStorage.capture(source: 'stock_count');
    } catch (_) {}

    return completed;
  }

  static Future<void> discardDraft(StockCountSession session) async {
    if (session.status != 'draft') return;
    final values = _box.values.toList();
    for (var i = 0; i < values.length; i++) {
      final map = Map<String, dynamic>.from(values[i] as Map);
      if (map['id'] == session.id) {
        await _box.deleteAt(i);
        await AuditLogStorage.log(
          action: 'stock_count_discarded',
          module: 'stock_count',
          description: 'Draft stock count discarded by ${AuthService.currentName}',
          refId: session.id,
        );
        return;
      }
    }
  }
}
