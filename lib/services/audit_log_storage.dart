import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'auth_service.dart';
import 'hive_boxes.dart';

class AuditLogStorage {
  static Box get _box => Hive.box(HiveBoxes.audit);

  static Future<void> log({
    required String action,
    required String module,
    required String description,
    String? refId,
  }) async {
    await _box.add({
      'id': const Uuid().v4(),
      'action': action,
      'module': module,
      'description': description,
      'refId': refId ?? '',
      'userId': AuthService.currentUser?.id ?? '',
      'userName': AuthService.currentName,
      'role': AuthService.currentRole,
      'at': DateTime.now().toIso8601String(),
    });
  }

  static List<Map<String, dynamic>> all() {
    final list = _box.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    list.sort(
      (a, b) => (b['at'] ?? '').toString().compareTo((a['at'] ?? '').toString()),
    );
    return list;
  }
}
