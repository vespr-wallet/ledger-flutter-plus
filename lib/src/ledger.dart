import 'package:ledger_flutter_plus/ledger_flutter.dart';

typedef PermissionRequestCallback = Future<bool> Function(
  AvailabilityState status,
);

LedgerInterface? _ledgerBle;
LedgerInterface? _ledgerUsb;

class Ledger {
  static LedgerInterface ble({
    LedgerOptions? bleOptions,
    required PermissionRequestCallback onPermissionRequest,
  }) =>
      _ledgerBle ??= _LedgerBle(
        options: bleOptions ?? LedgerOptions(),
        onPermissionRequest: onPermissionRequest,
        onDispose: () => _ledgerBle = null,
      );

  static LedgerInterface usb() => _ledgerUsb ??= _LedgerUSB(
        onDispose: () => _ledgerUsb = null,
      );
}

abstract interface class LedgerInterface {
  final ConnectionManager _connectionManager;

  LedgerInterface(this._connectionManager);

  Stream<LedgerDevice> scan({LedgerOptions? options});

  Future<void> stopScanning();

  Future<void> connect(
    LedgerDevice device, {
    LedgerOptions? options,
  }) =>
      _connectionManager.connect(device, options: options);

  Future<void> disconnect(LedgerDevice device) =>
      _connectionManager.disconnect(device);

  Future<void> dispose({Function? onError}) async {
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
    required LedgerOptions options,
    required void Function() onDispose,
    required this.onPermissionRequest,
  })  : _bleSearchManager = LedgerBleSearchManager(
          options: options,
          onPermissionRequest: onPermissionRequest,
        ),
        super(
          LedgerBleConnectionManager(
            options,
            onPermissionRequest: onPermissionRequest,
            onDispose: onDispose,
          ),
        );

  @override
  Stream<LedgerDevice> scan({LedgerOptions? options}) =>
      _bleSearchManager.scan(options: options);

  @override
  Future<void> stopScanning() => _bleSearchManager.stop();
}

class _LedgerUSB extends LedgerInterface {
  _LedgerUSB({
    required void Function() onDispose,
  }) : super(LedgerUsbManager(onDispose: onDispose));

  @override
  Stream<LedgerDevice> scan({LedgerOptions? options}) =>
      Stream.fromFuture(devices).expand((element) => element);

  @override
  Future<void> stopScanning() async {
    // NO-OP for USB
  }
}
