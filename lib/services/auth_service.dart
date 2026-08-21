import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import 'audit_log_storage.dart';
import 'hive_boxes.dart';

class AuthService {
  static final ValueNotifier<AppUser?> authListenable =
      ValueNotifier<AppUser?>(null);

  static AppUser? get currentUser => authListenable.value;
  static bool get isLoggedIn => currentUser != null;
  static String get currentRole => currentUser?.role ?? '';
  static String get currentName => currentUser?.name ?? '';

  static Box get _box => Hive.box(HiveBoxes.users);

  static Future<void> ensureDefaultUsers() async {
    if (_box.isNotEmpty) return;
    const uuid = Uuid();
    final owner = AppUser(
      id: uuid.v4(),
      name: 'Okikiola Owner',
      username: 'owner',
      password: 'owner123',
      role: 'owner',
    );
    final salesBoy = AppUser(
      id: uuid.v4(),
      name: 'Sales Staff',
      username: 'sales',
      password: 'sales123',
      role: 'sales',
    );
    await _box.add(owner.toMap());
    await _box.add(salesBoy.toMap());
  }

  /// Returns user on success, null on failure. Does not set session yet.
  static Future<AppUser?> authenticate(String username, String password) async {
    for (final raw in _box.values) {
      final map = Map<String, dynamic>.from(raw as Map);
      final user = AppUser.fromMap(map);
      if (!user.active) continue;
      if (user.username == username && user.password == password) {
        return user;
      }
    }
    return null;
  }

  static void setSession(AppUser user) {
    authListenable.value = user;
    // Fire and forget audit
    AuditLogStorage.log(
      action: 'login',
      module: 'auth',
      description: '${user.name} (${user.role}) signed in',
      refId: user.id,
    );
  }

  static Future<String?> login(String username, String password) async {
    final user = await authenticate(username, password);
    if (user == null) return 'Invalid username or password';
    setSession(user);
    return null;
  }

  static void logout() {
    final user = currentUser;
    if (user != null) {
      AuditLogStorage.log(
        action: 'logout',
        module: 'auth',
        description: '${user.name} (${user.role}) signed out',
        refId: user.id,
      );
    }
    authListenable.value = null;
  }

  static List<AppUser> allUsers() {
    return _box.values
        .map((e) => AppUser.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
