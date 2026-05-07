import "../models/ledger_device.dart";

abstract class BleSearchManager {
  Stream<LedgerDevice> scan();

  Future<void> stop();

  Future<void> dispose();
}
