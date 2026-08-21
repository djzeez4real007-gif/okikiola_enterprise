import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/shift.dart';
import 'audit_log_storage.dart';
import 'auth_service.dart';
import 'hive_boxes.dart';
import 'sale_storage.dart';
import 'stock_snapshot_storage.dart';
import 'expense_storage.dart';
import 'cash_movement_storage.dart';

class ShiftStorage {
  static Box get _box => Hive.box(HiveBoxes.shifts);

  /// Sales staff must have an open shift to sell.
  static Future<bool> hasOpenShiftFor(String userId) async {
    final s = await currentOpenShift(userId: userId);
    return s != null;
  }

  /// Close any shift still open after 23:59 of the day it was opened
  /// (or any previous calendar day). Uses expected cash as counted amount.
  static Future<int> autoCloseStaleShifts() async {
    final now = DateTime.now();
    final all = await getAll();
    int closed = 0;
    for (final shift in all) {
      if (shift.closed) continue;
      DateTime opened;
      try {
        opened = DateTime.parse(shift.openedAt);
      } catch (_) {
        continue;
      }
      // End of the shift's open day at 23:59:59
      final deadline = DateTime(opened.year, opened.month, opened.day, 23, 59, 59);
      if (now.isBefore(deadline)) continue;

      // Compute expected same as closeShift
      final sales = await SaleStorage.getAll();
      double cashSales = 0;
      for (final sale in sales) {
        if (sale.voided) continue;
        if (sale.soldById != shift.userId) continue;
        try {
          final t = DateTime.parse(sale.createdAt);
          if (t.isBefore(opened)) continue;
          cashSales += sale.cashPaid > 0
              ? sale.cashPaid
              : (sale.paymentMethod == 'Cash' ? sale.total : 0);
        } catch (_) {}
      }
      double cashExpenses = 0;
      try {
        final expenses = await ExpenseStorage.getAll();
        for (final e in expenses) {
          if (e.paymentMethod.toLowerCase() != 'cash') continue;
          try {
            final t = DateTime.parse(e.createdAt);
            if (t.isBefore(opened)) continue;
            cashExpenses += e.amount;
          } catch (_) {
            try {
              final t = DateTime.parse(e.date);
              if (t.year == opened.year &&
                  t.month == opened.month &&
                  t.day == opened.day) {
                cashExpenses += e.amount;
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
      double cashRemoved = 0;
      try {
        cashRemoved = await CashMovementStorage.totalOutForShift(
          userId: shift.userId,
          openedAt: shift.openedAt,
        );
      } catch (_) {}
      final expected =
          shift.openingCash + cashSales - cashExpenses - cashRemoved;

      await closeShift(
        shift: shift,
        closingCashCounted: expected,
        note:
            'AUTO-CLOSED at end of day (11:59 PM). '
            'Counted set to system expected ₦${expected.toStringAsFixed(0)}. '
            'Review if needed.',
      );
      closed++;
    }
    return closed;
  }

    static Future<List<Shift>> getAll() async {
    final list = _box.values
        .map((e) => Shift.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return list;
  }

  static Future<Shift?> currentOpenShift({String? userId}) async {
    final uid = userId ?? AuthService.currentUser?.id;
    if (uid == null) return null;
    final all = await getAll();
    for (final s in all) {
      if (!s.closed && s.userId == uid) return s;
    }
    return null;
  }

  /// Last closed shift for this user (any day / any year) — for cash carry-forward.
  static Future<Shift?> lastClosedShift({String? userId}) async {
    final uid = userId ?? AuthService.currentUser?.id;
    if (uid == null) return null;
    final all = await getAll();
    for (final s in all) {
      if (s.closed && s.userId == uid && s.closingCashCounted != null) {
        return s;
      }
    }
    return null;
  }

  /// Suggested opening float = previous day's (last closed) counted cash.
  static Future<double> suggestedOpeningCash({String? userId}) async {
    final last = await lastClosedShift(userId: userId);
    return last?.closingCashCounted ?? 0;
  }

  static Future<Shift> openShift({required double openingCash}) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw Exception('Not logged in. Sign out and sign in again.');
    }
    final existing = await currentOpenShift(userId: user.id);
    if (existing != null) {
      throw Exception('You already have an open shift. Close it first.');
    }

    final shift = Shift(
      id: const Uuid().v4(),
      userId: user.id,
      userName: user.name,
      role: user.role,
      openedAt: DateTime.now().toIso8601String(),
      openingCash: openingCash,
    );
    await _box.add(shift.toMap());
    await AuditLogStorage.log(
      action: 'shift_opened',
      module: 'shifts',
      description:
          '${user.name} opened shift with ₦${openingCash.toStringAsFixed(0)} float '
          '(${DateTime.now().toIso8601String().substring(0, 10)})',
      refId: shift.id,
    );
    return shift;
  }

  /// Expected cash = opening float + cash sales during this shift window.
  static Future<Shift> closeShift({
    required Shift shift,
    required double closingCashCounted,
    String note = '',
  }) async {
    final sales = await SaleStorage.getAll();
    final opened = DateTime.parse(shift.openedAt);
    double cashSales = 0;
    int count = 0;
    double allSales = 0;

    for (final s in sales) {
      if (s.voided) continue;
      if (s.soldById != shift.userId) continue;
      try {
        final t = DateTime.parse(s.createdAt);
        if (t.isBefore(opened)) continue;
        count++;
        allSales += s.total;
        if (s.cashPaid > 0) {
          cashSales += s.cashPaid;
        } else if (s.paymentMethod.toLowerCase() == 'cash') {
          cashSales += s.amountPaid > 0 ? s.amountPaid : s.total;
        }
      } catch (_) {}
    }

    // Cash expenses during this shift (reduces drawer)
    double cashExpenses = 0;
    try {
      final expenses = await ExpenseStorage.getAll();
      for (final e in expenses) {
        if (e.paymentMethod.toLowerCase() != 'cash') continue;
        if (e.recordedById != shift.userId && e.recordedById.isNotEmpty) {
          // still count if paid from shop drawer during shift window
        }
        try {
          final t = DateTime.parse(e.createdAt);
          if (t.isBefore(opened)) continue;
          cashExpenses += e.amount;
        } catch (_) {
          try {
            final t = DateTime.parse(e.date);
            if (t.isBefore(opened)) continue;
            // date-only: include if same day as shift open
            if (t.year == opened.year &&
                t.month == opened.month &&
                t.day == opened.day) {
              cashExpenses += e.amount;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // Owner/manager cash removed from drawer during shift
    double cashRemoved = 0;
    try {
      cashRemoved = await CashMovementStorage.totalOutForShift(
        userId: shift.userId,
        openedAt: shift.openedAt,
      );
    } catch (_) {}

    final expected =
        shift.openingCash + cashSales - cashExpenses - cashRemoved;
    final variance = closingCashCounted - expected;
    // Net cash movement for the day: counted - opening (what the drawer grew by)
    // Stored via salesTotal + variance context; closing becomes next open.

    final closed = Shift(
      id: shift.id,
      userId: shift.userId,
      userName: shift.userName,
      role: shift.role,
      openedAt: shift.openedAt,
      openingCash: shift.openingCash,
      closedAt: DateTime.now().toIso8601String(),
      closingCashCounted: closingCashCounted,
      expectedCash: expected,
      cashVariance: variance,
      salesTotal: allSales,
      salesCount: count,
      note: note,
      closed: true,
    );

    final values = _box.values.toList();
    for (var i = 0; i < values.length; i++) {
      final map = Map<String, dynamic>.from(values[i] as Map);
      if (map['id'] == shift.id) {
        await _box.putAt(i, closed.toMap());
        break;
      }
    }

    final vLabel = variance >= 0
        ? 'over ₦${variance.toStringAsFixed(0)}'
        : 'short ₦${(-variance).toStringAsFixed(0)}';
    await AuditLogStorage.log(
      action: 'shift_closed',
      module: 'shifts',
      description:
          '${shift.userName} closed shift ${DateTime.now().toIso8601String().substring(0, 10)}: '
          'open ₦${shift.openingCash.toStringAsFixed(0)}, '
          'cash sales ₦${cashSales.toStringAsFixed(0)}, '
          'cash expenses ₦${cashExpenses.toStringAsFixed(0)}, '
          'cash out ₦${cashRemoved.toStringAsFixed(0)}, '
          'expected ₦${expected.toStringAsFixed(0)}, '
          'counted ₦${closingCashCounted.toStringAsFixed(0)} ($vLabel). '
          'Carry-forward: ₦${closingCashCounted.toStringAsFixed(0)}',
      refId: shift.id,
    );
        try {
      await StockSnapshotStorage.capture(source: 'shift_close');
    } catch (_) {}

    return closed;
  }

  /// Daily net cash rows for reports (works across years).
  /// netCash = closingCounted - openingCash (drawer growth that day)
  static Future<List<Map<String, dynamic>>> dailyCashBook({
    String? userId,
    int? year,
  }) async {
    final all = await getAll();
    final closed = all.where((s) => s.closed).toList();
    final rows = <Map<String, dynamic>>[];

    for (final s in closed) {
      if (userId != null && s.userId != userId) continue;
      DateTime day;
      try {
        day = DateTime.parse(s.openedAt);
      } catch (_) {
        continue;
      }
      if (year != null && day.year != year) continue;

      final opening = s.openingCash;
      final closing = s.closingCashCounted ?? 0;
      final expected = s.expectedCash ?? 0;
      final variance = s.cashVariance ?? 0;
      final net = closing - opening;

      rows.add({
        'date': day,
        'dateKey':
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        'userName': s.userName,
        'opening': opening,
        'closing': closing,
        'expected': expected,
        'variance': variance,
        'salesTotal': s.salesTotal ?? 0,
        'salesCount': s.salesCount ?? 0,
        'netCash': net,
        'carryForward': closing,
        'shiftId': s.id,
      });
    }

    rows.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return rows;
  }
}
