import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'audit_log_storage.dart';
import 'auth_service.dart';
import 'hive_boxes.dart';

/// Cash in/out of the drawer outside of sales (e.g. owner pickup).
class CashMovementStorage {
  static Box get _box => Hive.box(HiveBoxes.cashMovements);

  static Future<void> addOut({
    required double amount,
    required String reason,
    String note = '',
  }) async {
    if (amount <= 0) throw Exception('Amount must be positive');
    final user = AuthService.currentUser;
    await _box.add({
      'id': const Uuid().v4(),
      'type': 'out',
      'amount': amount,
      'reason': reason,
      'note': note,
      'userId': user?.id ?? '',
      'userName': user?.name ?? '',
      'role': user?.role ?? '',
      'at': DateTime.now().toIso8601String(),
    });
    await AuditLogStorage.log(
      action: 'cash_out',
      module: 'cash',
      description:
          '${user?.name} removed ₦${amount.toStringAsFixed(0)} from drawer ($reason)',
    );
  }

  static Future<double> totalOutForShift({
    required String userId,
    required String openedAt,
  }) async {
    DateTime opened;
    try {
      opened = DateTime.parse(openedAt);
    } catch (_) {
      return 0;
    }
    double t = 0;
    for (final raw in _box.values) {
      final m = Map<String, dynamic>.from(raw as Map);
      if (m['type']?.toString() != 'out') continue;
      try {
        final at = DateTime.parse(m['at'].toString());
        if (at.isBefore(opened)) continue;
        t += (m['amount'] as num?)?.toDouble() ?? 0;
      } catch (_) {}
    }
    return t;
  }

  static List<Map<String, dynamic>> all() {
    final list = _box.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    list.sort((a, b) =>
        (b['at'] ?? '').toString().compareTo((a['at'] ?? '').toString()));
    return list;
  }
}
