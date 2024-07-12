import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';

abstract class BleSearchManager {
  Stream<LedgerDevice> scan();

  Future<void> stop();

  Future<void> dispose();
}
