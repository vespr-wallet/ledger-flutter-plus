import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';

typedef PermissionRequestCallback = Future<bool> Function(
  AvailabilityState status,
);

LedgerInterface? _ledgerBle;
LedgerInterface? _ledgerUsb;

sealed class LedgerInterface {
  static LedgerInterface ble({
    BluetoothOptions? bleOptions,
    required PermissionRequestCallback onPermissionRequest,
  }) =>
      _ledgerBle ??= _LedgerBle(
        bleOptions: bleOptions ?? BluetoothOptions(),
        onPermissionRequest: onPermissionRequest,
      );

  static LedgerInterface usb() => _ledgerUsb ??= _LedgerUSB();

  final ConnectionManager _connectionManager;

  LedgerInterface(this._connectionManager);

  Stream<LedgerDevice> scan();

  Future<void> stopScanning();

  Future<void> connect(LedgerDevice device) =>
      _connectionManager.connect(device);

  Future<void> disconnect(String deviceId) =>
      _connectionManager.disconnect(deviceId);

  Future<void> dispose({Function? onError}) async {
    switch (_connectionManager.connectionType) {
      case ConnectionType.usb:
        _ledgerUsb = null;
        break;
      case ConnectionType.ble:
        _ledgerBle = null;
        break;
    }

    try {
      await stopScanning();
    } catch (ex) {
      // no-op
    }
    try {
      await _connectionManager.dispose();
    } catch (ex) {
      onError?.call(
        DisposeException(
          connectionType: _connectionManager.connectionType,
          cause: ex,
        ),
      );
    }
  }

  Future<T> sendOperation<T>(
    LedgerDevice device,
    LedgerOperation<T> operation, {
    LedgerTransformer? transformer,
  }) =>
      _connectionManager.sendOperation<T>(
        device,
        operation,
        transformer,
      );

  Future<AvailabilityState> get status => _connectionManager.status;

  Stream<AvailabilityState> get statusStateChanges =>
      _connectionManager.statusStateChanges;

  Future<List<LedgerDevice>> get devices async => _connectionManager.devices;

  Stream<BleConnectionState> get deviceStateChanges =>
      _connectionManager.deviceStateChanges;
}

class _LedgerBle extends LedgerInterface {
  final BleSearchManager _bleSearchManager;
  final PermissionRequestCallback onPermissionRequest;

  _LedgerBle({
    required BluetoothOptions bleOptions,
    required this.onPermissionRequest,
  })  : _bleSearchManager = LedgerBleSearchManager(
          options: bleOptions,
          onPermissionRequest: onPermissionRequest,
        ),
        super(
          LedgerBleConnectionManager(
            onPermissionRequest: onPermissionRequest,
          ),
        );

  @override
  Stream<LedgerDevice> scan() => _bleSearchManager.scan();

  @override
  Future<void> stopScanning() => _bleSearchManager.stop();
}

class _LedgerUSB extends LedgerInterface {
  _LedgerUSB() : super(LedgerUsbManager());

  @override
  Stream<LedgerDevice> scan() =>
      Stream.fromFuture(devices).expand((element) => element);

  @override
  Future<void> stopScanning() async {
    // NO-OP for USB
  }
}
