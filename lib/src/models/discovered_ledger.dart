import "dart:async";

import "../../ledger_flutter_plus.dart";

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
    unawaited(subscription?.cancel());
  }
}
