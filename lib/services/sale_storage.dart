import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/sale.dart';
import 'audit_log_storage.dart';
import 'auth_service.dart';
import 'hive_boxes.dart';
import 'product_storage.dart';
import 'data_refresh.dart';
import 'location_service.dart';
import 'shift_storage.dart';

class SaleStorage {
  static Box get _box => Hive.box(HiveBoxes.sales);

  static Future<List<Sale>> getAll() async {
    final list = _box.values
        .map((e) => Sale.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<String> nextReceiptNo() async {
    final n = _box.length + 1;
    return 'RCP${n.toString().padLeft(6, '0')}';
  }

  /// Complete a sale: deduct stock + save sale + audit.
  static Future<Sale> completeSale({
    required List<SaleItem> items,
    required double amountPaid,
    required String paymentMethod,
    double cashPaid = 0,
    double transferPaid = 0,
    double posPaid = 0,
    double cartDiscount = 0,
    String note = '',
  }) async {
    if (items.isEmpty) {
      throw Exception('Cart is empty');
    }

    final role = AuthService.currentRole;
    if (role == 'sales') {
      await ShiftStorage.autoCloseStaleShifts();
      final uid = AuthService.currentUser?.id ?? '';
      final open = await ShiftStorage.currentOpenShift(userId: uid);
      if (open == null) {
        throw Exception(
          'Open a shift before recording sales (Shifts menu).',
        );
      }
    }

    // Validate stock
    final products = await ProductStorage.getAll();
    final byId = {for (final p in products) p.id: p};
    final locId = LocationService.currentId;
    for (final item in items) {
      final p = byId[item.productId];
      if (p == null) {
        throw Exception('Product missing: ${item.productName}');
      }
      final available = locId != null
          ? LocationService.getStock(locId, item.productId)
          : p.quantity;
      if (available < item.quantity) {
        final shop = LocationService.current?.name ?? 'stock';
        throw Exception(
          'Not enough stock for ${item.productName} at $shop '
          '(have $available, need ${item.quantity})',
        );
      }
    }

    final subtotal =
        items.fold<double>(0, (s, i) => s + (i.unitPrice * i.quantity));
    final lineDiscounts = items.fold<double>(0, (s, i) => s + i.discount);
    final discountTotal = lineDiscounts + cartDiscount;
    final total = subtotal - discountTotal;
    if (total < 0) throw Exception('Invalid total');

    final user = AuthService.currentUser;
    final sale = Sale(
      id: const Uuid().v4(),
      receiptNo: await nextReceiptNo(),
      items: items,
      subtotal: subtotal,
      discountTotal: discountTotal,
      total: total,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      cashPaid: cashPaid,
      transferPaid: transferPaid,
      posPaid: posPaid,
      soldById: user?.id ?? '',
      soldByName: user?.name ?? '',
      soldByRole: user?.role ?? '',
      createdAt: DateTime.now().toIso8601String(),
      note: note,
      locationId: LocationService.currentId ?? '',
      locationName: LocationService.current?.name ?? '',
    );

    // Deduct stock
    for (final item in items) {
      final p = byId[item.productId]!;
      final newQty = p.quantity - item.quantity;
      await ProductStorage.adjustQuantity(
        product: p,
        newQty: newQty < 0 ? 0 : newQty,
        reason: 'Sale ${sale.receiptNo}',
      );
    }

    await _box.add(sale.toMap());
    DataRefresh.notify();
    await AuditLogStorage.log(
      action: 'sale_completed',
      module: 'sales',
      description:
          '${sale.receiptNo}: ₦${sale.total.toStringAsFixed(0)} via ${sale.paymentMethod} by ${sale.soldByName}',
      refId: sale.id,
    );
    return sale;
  }

  static Future<void> voidSale(Sale sale) async {
    final values = _box.values.toList();
    for (var i = 0; i < values.length; i++) {
      final map = Map<String, dynamic>.from(values[i] as Map);
      if (map['id'] == sale.id) {
        map['voided'] = true;
        await _box.putAt(i, map);
        // Restock
        final products = await ProductStorage.getAll();
        final byId = {for (final p in products) p.id: p};
        for (final item in sale.items) {
          final p = byId[item.productId];
          if (p == null) continue;
          await ProductStorage.adjustQuantity(
            product: p,
            newQty: p.quantity + item.quantity,
            reason: 'Void ${sale.receiptNo}',
          );
        }
        await AuditLogStorage.log(
          action: 'sale_voided',
          module: 'sales',
          description: 'Voided ${sale.receiptNo} by ${AuthService.currentName}',
          refId: sale.id,
        );
        return;
      }
    }
  }

  static Future<double> todayTotal() async {
    final all = await getAll();
    final now = DateTime.now();
    double t = 0;
    for (final s in all) {
      if (s.voided) continue;
      try {
        final d = DateTime.parse(s.createdAt);
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          t += s.total;
        }
      } catch (_) {}
    }
    return t;
  }
}
