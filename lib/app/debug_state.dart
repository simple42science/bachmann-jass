import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo.dart';

/// Das Debug-Menue gibt es nur in Debug-Builds und in Demo-Builds.
bool get debugMenuAvailable => kDebugMode || demoEnabled;

/// Gegnerkarten offen zeigen (nur Debug).
class RevealHandsController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final revealHandsProvider = NotifierProvider<RevealHandsController, bool>(
  RevealHandsController.new,
);
