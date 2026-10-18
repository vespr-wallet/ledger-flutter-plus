import "package:flutter_test/flutter_test.dart";
import "package:ledger_flutter_plus/ledger_flutter_plus.dart";

void main() {
  test("fromBleServices finds the Bluetooth device type by service uuid, ignoring case", () {
    const genericAccess = "00001800-0000-1000-8000-00805f9b34fb";
    for (final type in LedgerDeviceType.ble) {
      expect(LedgerDeviceType.fromBleServices([genericAccess, type.serviceId.toLowerCase()]), type);
    }
    expect(LedgerDeviceType.fromBleServices(["13D63400-2C97-3004-0000-4C6564676572"]), LedgerDeviceType.flex);
    expect(LedgerDeviceType.fromBleServices([]), isNull);
    expect(LedgerDeviceType.fromBleServices([genericAccess]), isNull);
  });
}
