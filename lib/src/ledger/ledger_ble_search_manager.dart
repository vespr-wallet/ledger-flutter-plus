import 'dart:async';

import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';

class LedgerBleSearchManager extends BleSearchManager {
  static const String serviceId = '13D63400-2C97-0004-0000-4C6564676572';
  static const String writeCharacteristicKey =
      '13D63400-2C97-0004-0002-4C6564676572';
  static const String notifyCharacteristicKey =
      '13D63400-2C97-0004-0001-4C6564676572';

  final LedgerOptions _options;
  final PermissionRequestCallback _onPermissionRequest;

  final Set<String> _scannedIds = {};
  bool _isScanning = false;
  late StreamController<LedgerDevice> _streamController;

  LedgerBleSearchManager({
    required LedgerOptions options,
    required PermissionRequestCallback onPermissionRequest,
  })  : _options = options,
        _onPermissionRequest = onPermissionRequest {
    _streamController = StreamController<LedgerDevice>.broadcast();
  }

  @override
  Stream<LedgerDevice> scan({LedgerOptions? options}) async* {
    if (_isScanning || !(await _checkPermissions())) {
      return;
    }

    _startScanning();
    _setupScanResultHandler();
    _startBleScan(options);

    try {
      await for (final device in _streamController.stream) {
        yield device;
      }
    } finally {
      // Scan completed
    }
  }

  Future<bool> _checkPermissions() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return await _onPermissionRequest(state);
  }

  void _startScanning() {
    _isScanning = true;
    _scannedIds.clear();
    _streamController.close();
    _streamController = StreamController<LedgerDevice>.broadcast();
  }

  void _setupScanResultHandler() {
    UniversalBle.onScanResult = (device) {
      if (_scannedIds.contains(device.deviceId)) {
        return;
      }

      final lDevice = LedgerDevice.ble(
        id: device.deviceId,
        name: device.name ?? '',
        rssi: device.rssi ?? 0,
      );

      _scannedIds.add(lDevice.id);
      _streamController.add(lDevice);
    };
  }

  Future<void> _startBleScan(LedgerOptions? options) async {
    await UniversalBle.startScan(
      scanFilter: ScanFilter(withServices: [serviceId]),
    );

    final duration = options?.maxScanDuration ?? _options.maxScanDuration;
    await Future.delayed(duration);
    await stop();
  }

  @override
  Future<void> stop() async {
    if (!_isScanning) {
      return;
    }

    _isScanning = false;
    await UniversalBle.stopScan();
    UniversalBle.onScanResult = null;
    _streamController.close();
  }

  @override
  Future<void> dispose() async {
    await stop();
  }

  /// Returns the current status of the BLE subsystem of the host device.
  Future<AvailabilityState> get status =>
      UniversalBle.getBluetoothAvailabilityState();
}
