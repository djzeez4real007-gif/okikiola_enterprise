import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'services/auth_service.dart';
import 'services/hive_boxes.dart';
import 'services/location_service.dart';
import 'services/shift_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await HiveBoxes.openAll();
  await AuthService.ensureDefaultUsers();
  await LocationService.ensureDefaultLocation();
  await LocationService.repairOrphanStock();
  try {
    await ShiftStorage.autoCloseStaleShifts();
  } catch (_) {}
  runApp(const OkikiolaApp());
}
