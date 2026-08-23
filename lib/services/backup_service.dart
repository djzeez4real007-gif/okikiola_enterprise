import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'audit_log_storage.dart';
import 'auth_service.dart';
import 'hive_boxes.dart';

/// Full offline backup of all Hive boxes as JSON.
class BackupService {
  static const version = 1;

  static final List<String> _boxNames = [
    HiveBoxes.users,
    HiveBoxes.products,
    HiveBoxes.sales,
    HiveBoxes.expenses,
    HiveBoxes.shifts,
    HiveBoxes.audit,
    HiveBoxes.settings,
    HiveBoxes.stockCounts,
    HiveBoxes.stockIns,
    HiveBoxes.stockSnapshots,
    HiveBoxes.locations,
    HiveBoxes.locationStock,
    HiveBoxes.stockTransfers,
    HiveBoxes.cashMovements,
  ];

  static Map<String, dynamic> exportMap() {
    final boxes = <String, dynamic>{};
    for (final name in _boxNames) {
      if (!Hive.isBoxOpen(name)) continue;
      final box = Hive.box(name);
      final entries = <String, dynamic>{};
      for (final key in box.keys) {
        entries['$key'] = box.get(key);
      }
      boxes[name] = entries;
    }
    return {
      'app': 'okikiola_enterprise',
      'version': version,
      'exportedAt': DateTime.now().toIso8601String(),
      'exportedBy': AuthService.currentName,
      'boxes': boxes,
    };
  }

  static Future<String> exportToFile() async {
    final data = exportMap();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final fileName = 'okikiola_backup_$stamp.json';

    if (kIsWeb) {
      // On web, share text via share_plus if possible; write temp if available
      await Share.share(json, subject: fileName);
      await AuditLogStorage.log(
        action: 'backup_exported',
        module: 'backup',
        description: 'Backup shared (web) by ${AuthService.currentName}',
      );
      return fileName;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Okikiola backup',
      text: 'Okikiola Enterprise data backup — keep this file safe.',
    );
    await AuditLogStorage.log(
      action: 'backup_exported',
      module: 'backup',
      description: 'Backup exported by ${AuthService.currentName}',
    );
    return file.path;
  }

  /// Restores from a picked JSON backup. Returns number of boxes restored.
  static Future<int> restoreFromPicker() async {
    throw Exception(
      'File import is disabled in this build. '
      'Use Export backup, then restore on a computer version later.',
    );
  }

  static Future<int> restoreFromJson(String raw) async {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    if (map['app']?.toString() != 'okikiola_enterprise') {
      throw Exception('Not an Okikiola backup file');
    }
    final boxes = map['boxes'] as Map<String, dynamic>?;
    if (boxes == null) throw Exception('Invalid backup: missing boxes');

    var count = 0;
    for (final name in _boxNames) {
      if (!boxes.containsKey(name)) continue;
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
      final box = Hive.box(name);
      await box.clear();
      final entries = Map<String, dynamic>.from(boxes[name] as Map);
      for (final e in entries.entries) {
        final key = int.tryParse(e.key) ?? e.key;
        await box.put(key, e.value);
      }
      count++;
    }

    await AuditLogStorage.log(
      action: 'backup_restored',
      module: 'backup',
      description:
          'Backup restored (${map['exportedAt']}) by ${AuthService.currentName}',
    );
    return count;
  }
}
