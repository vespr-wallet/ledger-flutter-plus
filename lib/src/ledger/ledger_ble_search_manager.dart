import 'dart:async';

import 'package:ledger_flutter/ledger_flutter.dart';

class LedgerBleSearchManager extends BleSearchManager {
  /// Ledger Nano X service id
  static const serviceId = '13D63400-2C97-0004-0000-4C6564676572';
  static const writeCharacteristicKey = '13D63400-2C97-0004-0002-4C6564676572';
  static const notifyCharacteristicKey = '13D63400-2C97-0004-0001-4C6564676572';

  final LedgerOptions _options;
  final PermissionRequestCallback? onPermissionRequest;

  final _scannedIds = <String>{};
  bool _isScanning = false;
  StreamController<LedgerDevice> streamController =
      StreamController.broadcast();

  LedgerBleSearchManager({
    required LedgerOptions options,
    this.onPermissionRequest,
  }) : _options = options;

  @override
  Stream<LedgerDevice> scan({LedgerOptions? options}) async* {
    // Check for permissions
    final granted = (await onPermissionRequest?.call(await UniversalBle.getBluetoothAvailabilityState())) ?? true;
    if (!granted) {
      return;
    }

    if (_isScanning) {
      return;
    }

    // Start scanning
    _isScanning = true;
    _scannedIds.clear();
    streamController.close();
    streamController = StreamController.broadcast();

    UniversalBle.onScanResult = (device) {
      if (_scannedIds.contains(device.deviceId)) {
        return;
      }

      final lDevice = LedgerDevice(
        id: device.deviceId,
        name: device.name ?? '',
        connectionType: ConnectionType.ble,
        rssi: device.rssi ?? 0,
      );

      _scannedIds.add(lDevice.id);
      streamController.add(lDevice);
    };

    await UniversalBle.startScan(
      scanFilter: ScanFilter(
        withServices: [serviceId],
      ),
    );

    Future.delayed(options?.maxScanDuration ?? _options.maxScanDuration, () {
      stop();
    });

    yield* streamController.stream;
  }

  @override
  Future<void> stop() async {
    if (!_isScanning) {
      return;
    }

    _isScanning = false;
    await UniversalBle.stopScan();
    UniversalBle.onScanResult = null;
    streamController.close();
  }

  @override
  Future<void> dispose() async {
    await stop();
  }

  /// Returns the current status of the BLE subsystem of the host device.
  Future<AvailabilityState> get status => UniversalBle.getBluetoothAvailabilityState();
}
