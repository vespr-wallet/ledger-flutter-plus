import 'dart:async';

import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
import 'package:universal_ble/universal_ble.dart';

class DiscoveredLedger {
  final LedgerDevice device;
  final StreamSubscription? subscription;
  final List<BleService> services;

  DiscoveredLedger({
    required this.device,
    required this.subscription,
    required this.services,
  });

  Future<void> disconnect() async {
    subscription?.cancel();
  }
}
