import 'package:ledger_flutter/ledger_flutter.dart';

abstract class BleConnectionManager {
  Future<void> connect(LedgerDevice device, {LedgerOptions? options});

  Future<void> disconnect(LedgerDevice device);

  Future<T> sendOperation<T>(
    LedgerDevice device,
    LedgerOperation<T> operation,
    LedgerTransformer? transformer,
  );

  Future<void> dispose();

  /// Returns the current status of the BLE subsystem of the host device.
  Future<AvailabilityState> get status;

  /// A stream providing the host device BLE subsystem status updates.
  Stream<AvailabilityState> get statusStateChanges;

  /// A stream providing connection updates for all the connected BLE devices.
  Stream<BleConnectionState> get deviceStateChanges;

  /// Get a list of connected [LedgerDevice]s.
  List<LedgerDevice> get devices;
}
