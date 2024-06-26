import 'package:ledger_flutter/ledger_flutter.dart';

typedef PermissionRequestCallback = Future<bool> Function(AvailabilityState status);

class Ledger {
  final UsbManager _usbManager;
  final BleSearchManager _bleSearchManager;
  final BleConnectionManager _bleConnectionManager;
  final PermissionRequestCallback? onPermissionRequest;

  Ledger({
    required LedgerOptions options,
    this.onPermissionRequest,
    UsbManager? usbManager,
    BleSearchManager? bleSearchManager,
    BleConnectionManager? bleConnectionManager,
  })  : _usbManager = usbManager ?? LedgerUsbManager(),
        _bleSearchManager = bleSearchManager ??
            LedgerBleSearchManager(
              options: options,
              onPermissionRequest: onPermissionRequest,
            ),
        _bleConnectionManager = bleConnectionManager ??
            LedgerBleConnectionManager(
              options: options,
              onPermissionRequest: onPermissionRequest,
            );

  Stream<LedgerDevice> scan({
    LedgerOptions? options,
  }) =>
      _bleSearchManager.scan(options: options);

  Future<List<LedgerDevice>> listUsbDevices() => _usbManager.listDevices();

  Future<void> connect(
    LedgerDevice device, {
    LedgerOptions? options,
  }) {
    switch (device.connectionType) {
      case ConnectionType.usb:
        return _usbManager.connect(device, options: options);
      case ConnectionType.ble:
        return _bleConnectionManager.connect(device, options: options);
    }
  }

  Future<void> disconnect(LedgerDevice device) {
    switch (device.connectionType) {
      case ConnectionType.usb:
        return _usbManager.disconnect(device);
      case ConnectionType.ble:
        return _bleConnectionManager.disconnect(device);
    }
  }

  Future<void> stopScanning() => _bleSearchManager.stop();

  Future<void> close(ConnectionType connectionType) async {
    switch (connectionType) {
      case ConnectionType.usb:
        return _usbManager.dispose();
      case ConnectionType.ble:
        return _bleConnectionManager.dispose();
    }
  }

  Future<void> dispose({Function? onError}) async {
    try {
      await _usbManager.dispose();
    } catch (ex) {
      onError?.call(LedgerException(cause: ex));
    }

    await _bleConnectionManager.dispose();
  }

  Future<T> sendOperation<T>(
    LedgerDevice device,
    LedgerOperation<T> operation, {
    LedgerTransformer? transformer,
  }) {
    switch (device.connectionType) {
      case ConnectionType.usb:
        return _usbManager.sendOperation<T>(device, operation, transformer);
      case ConnectionType.ble:
        return _bleConnectionManager.sendOperation<T>(
          device,
          operation,
          transformer,
        );
    }
  }

  Future<AvailabilityState> get status => _bleConnectionManager.status;

  Stream<AvailabilityState> get statusStateChanges =>
      _bleConnectionManager.statusStateChanges;

  List<LedgerDevice> get devices => _bleConnectionManager.devices;

  Stream<BleConnectionState> get deviceStateChanges =>
      _bleConnectionManager.deviceStateChanges;
}
