import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import 'audit_log_storage.dart';
import 'auth_service.dart';
import 'hive_boxes.dart';

class UserStorage {
  static Box get _box => Hive.box(HiveBoxes.users);

  static List<AppUser> all() {
    return _box.values
        .map((e) => AppUser.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static int? indexOfId(String id) {
    final values = _box.values.toList();
    for (var i = 0; i < values.length; i++) {
      final map = Map<String, dynamic>.from(values[i] as Map);
      if (map['id']?.toString() == id) return i;
    }
    return null;
  }

  static bool usernameTaken(String username, {String? exceptId}) {
    for (final u in all()) {
      if (exceptId != null && u.id == exceptId) continue;
      if (u.username == username) return true;
    }
    return false;
  }

  static Future<AppUser> create({
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      throw Exception('Username and password required');
    }
    if (usernameTaken(username.trim())) {
      throw Exception('Username already exists');
    }
    final user = AppUser(
      id: const Uuid().v4(),
      name: name.trim(),
      username: username.trim(),
      password: password,
      role: role,
      active: true,
    );
    await _box.add(user.toMap());
    await AuditLogStorage.log(
      action: 'user_created',
      module: 'users',
      description:
          'Created ${user.name} (@${user.username}, ${user.role}) by ${AuthService.currentName}',
      refId: user.id,
    );
    return user;
  }

  static Future<void> update(AppUser user) async {
    final idx = indexOfId(user.id);
    if (idx == null) throw Exception('User not found');
    if (usernameTaken(user.username, exceptId: user.id)) {
      throw Exception('Username already exists');
    }
    await _box.putAt(idx, user.toMap());
    await AuditLogStorage.log(
      action: 'user_updated',
      module: 'users',
      description:
          'Updated ${user.name} (@${user.username}) by ${AuthService.currentName}',
      refId: user.id,
    );
  }

  static Future<void> setActive(AppUser user, bool active) async {
    // Protect last active owner
    if (!active && user.role == 'owner') {
      final owners = all().where((u) => u.role == 'owner' && u.active).length;
      if (owners <= 1) {
        throw Exception('Cannot deactivate the only active owner');
      }
    }
    final updated = AppUser(
      id: user.id,
      name: user.name,
      username: user.username,
      password: user.password,
      role: user.role,
      active: active,
    );
    await update(updated);
    await AuditLogStorage.log(
      action: active ? 'user_activated' : 'user_deactivated',
      module: 'users',
      description:
          '${active ? 'Activated' : 'Deactivated'} ${user.name} by ${AuthService.currentName}',
      refId: user.id,
    );
  }

  static Future<void> changePassword(AppUser user, String newPassword) async {
    if (newPassword.isEmpty) throw Exception('Password required');
    final updated = AppUser(
      id: user.id,
      name: user.name,
      username: user.username,
      password: newPassword,
      role: user.role,
      active: user.active,
    );
    final idx = indexOfId(user.id);
    if (idx == null) throw Exception('User not found');
    await _box.putAt(idx, updated.toMap());
    await AuditLogStorage.log(
      action: 'password_changed',
      module: 'users',
      description:
          'Password changed for ${user.name} by ${AuthService.currentName}',
      refId: user.id,
    );
  }
}
