import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus_dart.dart';

abstract class ConnectionManager {
  Future<void> connect(LedgerDevice device);

  Future<void> disconnect(String deviceId);

  Future<T> sendRawOperation<T>(
    LedgerDevice device,
    LedgerRawOperation<T> operation,
    LedgerTransformer? transformer,
  );

  Future<void> dispose();

  ConnectionType get connectionType;

  /// Returns the current status of the BLE subsystem of the host device.
  Future<AvailabilityState> get status;

  /// A stream providing the host device BLE subsystem status updates.
  Stream<AvailabilityState> get statusStateChanges;

  /// A stream providing connection updates for all the connected BLE devices.
  Stream<BleConnectionState> deviceStateChanges(String deviceId);

  /// Get a list of connected [LedgerDevice]s.
  Future<List<LedgerDevice>> get devices;
}
