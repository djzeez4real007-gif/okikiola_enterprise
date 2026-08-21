import 'package:flutter/foundation.dart';

/// Bumps whenever sales / stock / expenses / shifts change so dashboards stay live.
class DataRefresh {
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static void notify() {
    tick.value = tick.value + 1;
  }
}
